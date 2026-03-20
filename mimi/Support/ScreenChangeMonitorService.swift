import AppKit
import CoreGraphics

struct ScreenChangeObservation {
    let watchRect: CGRect
    let dominantPoint: CGPoint?
    let changeRatio: CGFloat
    let permissionGranted: Bool

    var isDynamic: Bool {
        permissionGranted && dominantPoint != nil && changeRatio >= 0.08
    }

    var debugSummary: String {
        let watchLine = String(
            format: "观察区域：x=%.1f, y=%.1f, width=%.1f, height=%.1f",
            watchRect.origin.x,
            watchRect.origin.y,
            watchRect.size.width,
            watchRect.size.height
        )
        let ratioLine = String(format: "变化比例：%.3f", changeRatio)
        let permissionLine = permissionGranted ? "屏幕录制权限：已授权" : "屏幕录制权限：未授权"
        let pointLine: String
        if let dominantPoint {
            pointLine = String(format: "变化热点：x=%.1f, y=%.1f", dominantPoint.x, dominantPoint.y)
        } else {
            pointLine = "变化热点：无"
        }

        return [permissionLine, watchLine, ratioLine, pointLine].joined(separator: "\n")
    }
}

final class ScreenChangeMonitorService {
    private struct ScreenLumaSample {
        let watchRect: CGRect
        let width: Int
        let height: Int
        let luminance: [CGFloat]
    }

    private let gridWidth = 24
    private let gridHeight = 16
    private let cellChangeThreshold: CGFloat = 14
    private var previousSample: ScreenLumaSample?

    func reset() {
        previousSample = nil
    }

    func observe(around anchorRect: CGRect) -> ScreenChangeObservation {
        guard CGPreflightScreenCaptureAccess() else {
            reset()
            return ScreenChangeObservation(
                watchRect: expandedWatchRect(around: anchorRect),
                dominantPoint: nil,
                changeRatio: 0,
                permissionGranted: false
            )
        }

        let watchRect = expandedWatchRect(around: anchorRect)
        guard let currentSample = captureSample(in: watchRect) else {
            reset()
            return ScreenChangeObservation(
                watchRect: watchRect,
                dominantPoint: nil,
                changeRatio: 0,
                permissionGranted: true
            )
        }

        defer {
            previousSample = currentSample
        }

        guard let previousSample else {
            return ScreenChangeObservation(
                watchRect: watchRect,
                dominantPoint: nil,
                changeRatio: 0,
                permissionGranted: true
            )
        }

        let comparableSamples = previousSample.width == currentSample.width &&
            previousSample.height == currentSample.height &&
            abs(previousSample.watchRect.origin.x - currentSample.watchRect.origin.x) < 0.5 &&
            abs(previousSample.watchRect.origin.y - currentSample.watchRect.origin.y) < 0.5 &&
            abs(previousSample.watchRect.size.width - currentSample.watchRect.size.width) < 0.5 &&
            abs(previousSample.watchRect.size.height - currentSample.watchRect.size.height) < 0.5

        guard comparableSamples else {
            return ScreenChangeObservation(
                watchRect: watchRect,
                dominantPoint: nil,
                changeRatio: 0,
                permissionGranted: true
            )
        }

        var changedCellCount = 0
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        var totalWeight: CGFloat = 0

        for index in 0..<currentSample.luminance.count {
            let delta = abs(currentSample.luminance[index] - previousSample.luminance[index])
            guard delta >= cellChangeThreshold else {
                continue
            }

            changedCellCount += 1

            let column = index % gridWidth
            let row = index / gridWidth
            let normalizedX = (CGFloat(column) + 0.5) / CGFloat(gridWidth)
            let normalizedYFromTop = (CGFloat(row) + 0.5) / CGFloat(gridHeight)
            let point = CGPoint(
                x: watchRect.minX + watchRect.width * normalizedX,
                y: watchRect.maxY - watchRect.height * normalizedYFromTop
            )

            weightedX += point.x * delta
            weightedY += point.y * delta
            totalWeight += delta
        }

        let changeRatio = CGFloat(changedCellCount) / CGFloat(max(1, currentSample.luminance.count))
        let dominantPoint: CGPoint?
        if totalWeight > 0 {
            dominantPoint = CGPoint(x: weightedX / totalWeight, y: weightedY / totalWeight)
        } else {
            dominantPoint = nil
        }

        return ScreenChangeObservation(
            watchRect: watchRect,
            dominantPoint: dominantPoint,
            changeRatio: changeRatio,
            permissionGranted: true
        )
    }

    private func expandedWatchRect(around anchorRect: CGRect) -> CGRect {
        let focusPoint = CGPoint(x: anchorRect.midX, y: anchorRect.midY)
        return CGRect(
            x: focusPoint.x - 220,
            y: focusPoint.y - 140,
            width: 440,
            height: 320
        ).integral
    }

    private func captureSample(in watchRect: CGRect) -> ScreenLumaSample? {
        let desktopBounds = NSScreen.screens.reduce(CGRect.null) { partialResult, screen in
            partialResult.union(screen.frame)
        }

        guard desktopBounds.isNull == false else {
            return nil
        }

        let clippedRect = watchRect.intersection(desktopBounds).integral
        guard clippedRect.isNull == false, clippedRect.width >= 4, clippedRect.height >= 4 else {
            return nil
        }

        let quartzRect = CGRect(
            x: clippedRect.origin.x,
            y: desktopBounds.maxY - clippedRect.maxY,
            width: clippedRect.width,
            height: clippedRect.height
        ).integral

        guard let image = CGWindowListCreateImage(quartzRect, .optionOnScreenOnly, kCGNullWindowID, []) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: image)
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        guard width > 0, height > 0 else {
            return nil
        }

        var luminance: [CGFloat] = []
        luminance.reserveCapacity(gridWidth * gridHeight)

        for row in 0..<gridHeight {
            for column in 0..<gridWidth {
                let pixelX = min(width - 1, Int((CGFloat(column) + 0.5) * CGFloat(width) / CGFloat(gridWidth)))
                let pixelY = min(height - 1, Int((CGFloat(row) + 0.5) * CGFloat(height) / CGFloat(gridHeight)))

                guard let color = bitmap.colorAt(x: pixelX, y: pixelY)?.usingColorSpace(.deviceRGB) else {
                    luminance.append(0)
                    continue
                }

                let red = color.redComponent * 255
                let green = color.greenComponent * 255
                let blue = color.blueComponent * 255
                let value = 0.299 * red + 0.587 * green + 0.114 * blue
                luminance.append(value)
            }
        }

        return ScreenLumaSample(
            watchRect: clippedRect,
            width: gridWidth,
            height: gridHeight,
            luminance: luminance
        )
    }
}
