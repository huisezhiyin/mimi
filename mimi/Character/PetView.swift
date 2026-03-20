import AppKit

final class PetView: NSView {
    private struct EyeStyle {
        let leftEyeRect: NSRect
        let rightEyeRect: NSRect
        let pupilSize: NSSize
        let maxOffsetX: CGFloat
        let maxOffsetY: CGFloat
        let pupilColor: NSColor
        let lidOverlayHeight: CGFloat
        let sparkleAlpha: CGFloat
    }

    private enum MouthStyle {
        case focused
        case curiousClosed
        case curiousOpen
        case softSmile
        case resting
    }

    var permissionGranted = false {
        didSet {
            needsDisplay = true
        }
    }

    var trackingStatusText = "目标：待验证" {
        didSet {
            needsDisplay = true
        }
    }

    var mappedTargetPoint: CGPoint? {
        didSet {
            needsDisplay = true
        }
    }

    var stateStatusText = "状态：Focus" {
        didSet {
            needsDisplay = true
        }
    }

    var attentionMode: AttentionMode = .typing {
        didSet {
            needsDisplay = true
        }
    }

    var generationPhase: GenerationPhase = .inactive {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        drawTail()
        drawFace()
        drawSpeechBubble()
        drawEyes()
        drawStatusBadge()
        drawTrackingBadge()
        drawStateBadge()
        drawAttentionBadge()
        drawMappedTarget()
    }

    private func drawTail() {
        let tail = NSBezierPath()
        tail.lineWidth = hasActiveGenerationPerformance ? 20 : 18
        let tailColor = hasActiveGenerationPerformance
            ? NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.41, alpha: 0.98)
            : NSColor(calibratedRed: 0.86, green: 0.64, blue: 0.38, alpha: 0.95)
        tailColor.setStroke()
        tail.move(to: NSPoint(x: 146, y: 136))
        let endPoint = hasActiveGenerationPerformance ? NSPoint(x: 202, y: 42) : NSPoint(x: 200, y: 60)
        let controlPoint1 = hasActiveGenerationPerformance ? NSPoint(x: 186, y: 118) : NSPoint(x: 184, y: 128)
        let controlPoint2 = hasActiveGenerationPerformance ? NSPoint(x: 218, y: 82) : NSPoint(x: 214, y: 102)
        tail.curve(to: endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
        tail.stroke()
    }

    private func drawFace() {
        let earTipY: CGFloat = hasActiveGenerationPerformance ? 8 : 16
        let leftEarPeakX: CGFloat = generationPhase == .streaming ? 102 : 96
        let rightEarPeakX: CGFloat = generationPhase == .streaming ? 166 : 172

        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: 68, y: 78))
        leftEar.line(to: NSPoint(x: leftEarPeakX, y: earTipY))
        leftEar.line(to: NSPoint(x: 116, y: 88))
        leftEar.close()

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: 152, y: 88))
        rightEar.line(to: NSPoint(x: rightEarPeakX, y: earTipY))
        rightEar.line(to: NSPoint(x: 104, y: 78))
        rightEar.close()

        let faceRect = NSRect(x: 42, y: 62, width: 136, height: 128)
        let face = NSBezierPath(roundedRect: faceRect, xRadius: 64, yRadius: 64)

        let furColor = NSColor(calibratedRed: 0.88, green: 0.68, blue: 0.42, alpha: 0.95)
        furColor.setFill()
        leftEar.fill()
        rightEar.fill()
        face.fill()

        NSColor(calibratedRed: 0.95, green: 0.84, blue: 0.64, alpha: 0.95).setFill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 106, width: 76, height: 58)).fill()
    }

    private func drawSpeechBubble() {
        guard let bubbleText else {
            return
        }

        let bubbleRect = NSRect(x: 126, y: 18, width: 70, height: 28)
        let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: 14, yRadius: 14)
        NSColor.white.withAlphaComponent(0.92).setFill()
        bubble.fill()

        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 142, y: 43))
        tail.line(to: NSPoint(x: 132, y: 58))
        tail.line(to: NSPoint(x: 151, y: 48))
        tail.close()
        NSColor.white.withAlphaComponent(0.92).setFill()
        tail.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.20, alpha: 0.92),
            .paragraphStyle: style
        ]
        bubbleText.draw(in: bubbleRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawEyes() {
        let eyeColor = NSColor.white.withAlphaComponent(0.95)
        let style = eyeStyle()
        let leftEye = NSBezierPath(ovalIn: style.leftEyeRect)
        let rightEye = NSBezierPath(ovalIn: style.rightEyeRect)
        eyeColor.setFill()
        leftEye.fill()
        rightEye.fill()

        let leftPupilOrigin = pupilOrigin(in: style.leftEyeRect, pupilSize: style.pupilSize, style: style)
        let rightPupilOrigin = pupilOrigin(in: style.rightEyeRect, pupilSize: style.pupilSize, style: style)

        style.pupilColor.setFill()
        NSBezierPath(ovalIn: NSRect(origin: leftPupilOrigin, size: style.pupilSize)).fill()
        NSBezierPath(ovalIn: NSRect(origin: rightPupilOrigin, size: style.pupilSize)).fill()

        drawEyeLids(for: style.leftEyeRect, overlayHeight: style.lidOverlayHeight)
        drawEyeLids(for: style.rightEyeRect, overlayHeight: style.lidOverlayHeight)
        drawEyeSparkles(at: leftPupilOrigin, pupilSize: style.pupilSize, alpha: style.sparkleAlpha)
        drawEyeSparkles(at: rightPupilOrigin, pupilSize: style.pupilSize, alpha: style.sparkleAlpha)
        drawExpressionAccent()
        drawMouth()

        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 110, y: 124))
        nose.line(to: NSPoint(x: 98, y: 118))
        nose.line(to: NSPoint(x: 122, y: 118))
        nose.close()
        NSColor.systemPink.withAlphaComponent(0.85).setFill()
        nose.fill()
    }

    private func drawEyeLids(for eyeRect: NSRect, overlayHeight: CGFloat) {
        guard overlayHeight > 0 else {
            return
        }

        let lidRect = NSRect(
            x: eyeRect.minX,
            y: eyeRect.minY,
            width: eyeRect.width,
            height: min(eyeRect.height * 0.72, overlayHeight)
        )
        NSColor(calibratedRed: 0.88, green: 0.68, blue: 0.42, alpha: 0.92).setFill()
        NSBezierPath(roundedRect: lidRect, xRadius: lidRect.height / 2, yRadius: lidRect.height / 2).fill()
    }

    private func drawEyeSparkles(at pupilOrigin: CGPoint, pupilSize: NSSize, alpha: CGFloat) {
        guard alpha > 0 else {
            return
        }

        let sparkleRect = NSRect(
            x: pupilOrigin.x + pupilSize.width * 0.2,
            y: pupilOrigin.y + pupilSize.height * 0.18,
            width: 3,
            height: 3
        )
        NSColor.white.withAlphaComponent(alpha).setFill()
        NSBezierPath(ovalIn: sparkleRect).fill()
    }

    private func drawExpressionAccent() {
        let strokeColor = NSColor.black.withAlphaComponent(0.22)
        strokeColor.setStroke()

        switch attentionMode {
        case .typing:
            let leftBrow = NSBezierPath()
            leftBrow.lineWidth = 2
            leftBrow.move(to: NSPoint(x: 74, y: 96))
            leftBrow.line(to: NSPoint(x: 100, y: 90))
            leftBrow.stroke()

            let rightBrow = NSBezierPath()
            rightBrow.lineWidth = 2
            rightBrow.move(to: NSPoint(x: 120, y: 90))
            rightBrow.line(to: NSPoint(x: 146, y: 96))
            rightBrow.stroke()
        case .waitingForResponse:
            guard hasActiveGenerationPerformance else {
                return
            }

            let focusMark = NSBezierPath()
            focusMark.lineWidth = 2
            focusMark.move(to: NSPoint(x: 108, y: 82))
            focusMark.line(to: NSPoint(x: 108, y: 72))
            focusMark.move(to: NSPoint(x: 118, y: 78))
            focusMark.line(to: NSPoint(x: 124, y: 70))
            focusMark.stroke()
        case .idle:
            return
        }
    }

    private func drawMouth() {
        switch mouthStyle {
        case .focused:
            let mouth = NSBezierPath()
            mouth.lineWidth = 2
            mouth.move(to: NSPoint(x: 102, y: 134))
            mouth.line(to: NSPoint(x: 118, y: 134))
            NSColor.black.withAlphaComponent(0.35).setStroke()
            mouth.stroke()
        case .curiousClosed:
            let mouth = NSBezierPath()
            mouth.lineWidth = 2
            mouth.move(to: NSPoint(x: 104, y: 134))
            mouth.curve(to: NSPoint(x: 118, y: 134), controlPoint1: NSPoint(x: 108, y: 140), controlPoint2: NSPoint(x: 114, y: 140))
            NSColor.black.withAlphaComponent(0.32).setStroke()
            mouth.stroke()
        case .curiousOpen:
            let mouthRect = NSRect(x: 104, y: 131, width: 14, height: 12)
            NSColor(calibratedRed: 0.39, green: 0.18, blue: 0.17, alpha: 0.75).setFill()
            NSBezierPath(ovalIn: mouthRect).fill()
        case .softSmile:
            let mouth = NSBezierPath()
            mouth.lineWidth = 2
            mouth.move(to: NSPoint(x: 102, y: 132))
            mouth.curve(to: NSPoint(x: 120, y: 132), controlPoint1: NSPoint(x: 107, y: 139), controlPoint2: NSPoint(x: 115, y: 139))
            NSColor.black.withAlphaComponent(0.28).setStroke()
            mouth.stroke()
        case .resting:
            let mouth = NSBezierPath()
            mouth.lineWidth = 1.5
            mouth.move(to: NSPoint(x: 104, y: 135))
            mouth.line(to: NSPoint(x: 118, y: 135))
            NSColor.black.withAlphaComponent(0.20).setStroke()
            mouth.stroke()
        }
    }

    private func drawStatusBadge() {
        let badgeRect = NSRect(x: 34, y: 178, width: 152, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.68).setFill()
        badge.fill()

        let text = permissionGranted ? "窗口与菜单栏已就绪" : "等待辅助功能权限"
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        let textRect = badgeRect.insetBy(dx: 8, dy: 6)
        text.draw(in: textRect, withAttributes: attributes)
    }

    private func drawTrackingBadge() {
        let badgeRect = NSRect(x: 20, y: 12, width: 180, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.58).setFill()
        badge.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        trackingStatusText.draw(in: badgeRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawStateBadge() {
        let badgeRect = NSRect(x: 20, y: 44, width: 120, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.58).setFill()
        badge.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        stateStatusText.draw(in: badgeRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawAttentionBadge() {
        let badgeRect = NSRect(x: 20, y: 76, width: 156, height: 28)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 14, yRadius: 14)

        let fillColor: NSColor
        switch attentionMode {
        case .typing:
            fillColor = NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.16, alpha: 0.72)
        case .waitingForResponse:
            fillColor = NSColor(calibratedRed: 0.12, green: 0.22, blue: 0.26, alpha: 0.72)
        case .idle:
            fillColor = NSColor(calibratedWhite: 0.12, alpha: 0.56)
        }

        fillColor.setFill()
        badge.fill()

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style
        ]

        attentionMode.badgeText.draw(in: badgeRect.insetBy(dx: 8, dy: 7), withAttributes: attributes)
    }

    private func drawMappedTarget() {
        guard let mappedTargetPoint else {
            return
        }

        let ringRect = NSRect(
            x: mappedTargetPoint.x - 8,
            y: mappedTargetPoint.y - 8,
            width: 16,
            height: 16
        )
        let ring = NSBezierPath(ovalIn: ringRect)
        ring.lineWidth = 2
        NSColor.systemTeal.withAlphaComponent(0.95).setStroke()
        ring.stroke()

        let centerRect = NSRect(
            x: mappedTargetPoint.x - 2,
            y: mappedTargetPoint.y - 2,
            width: 4,
            height: 4
        )
        NSColor.systemTeal.withAlphaComponent(0.95).setFill()
        NSBezierPath(ovalIn: centerRect).fill()
    }

    private func eyeStyle() -> EyeStyle {
        let activePupilColor = permissionGranted ? NSColor.black.withAlphaComponent(0.85) : NSColor.systemOrange.withAlphaComponent(0.9)

        switch attentionMode {
        case .typing:
            return EyeStyle(
                leftEyeRect: NSRect(x: 74, y: 98, width: 30, height: 19),
                rightEyeRect: NSRect(x: 116, y: 98, width: 30, height: 19),
                pupilSize: NSSize(width: 8, height: 15),
                maxOffsetX: 7,
                maxOffsetY: 4.4,
                pupilColor: activePupilColor,
                lidOverlayHeight: 3,
                sparkleAlpha: 0.04
            )
        case .waitingForResponse:
            return EyeStyle(
                leftEyeRect: NSRect(x: 73, y: 95, width: 31, height: generationPhase == .streaming ? 26 : 24),
                rightEyeRect: NSRect(x: 116, y: 95, width: 31, height: generationPhase == .streaming ? 26 : 24),
                pupilSize: hasActiveGenerationPerformance ? NSSize(width: 10, height: 15) : NSSize(width: 9, height: 14),
                maxOffsetX: hasActiveGenerationPerformance ? 4.2 : 5.5,
                maxOffsetY: hasActiveGenerationPerformance ? 3.4 : 4,
                pupilColor: hasActiveGenerationPerformance ? activePupilColor.withAlphaComponent(0.9) : activePupilColor.withAlphaComponent(0.82),
                lidOverlayHeight: hasActiveGenerationPerformance ? 2.5 : 4,
                sparkleAlpha: generationPhase == .streaming ? 0.40 : 0.26
            )
        case .idle:
            return EyeStyle(
                leftEyeRect: NSRect(x: 74, y: 102, width: 30, height: 12),
                rightEyeRect: NSRect(x: 116, y: 102, width: 30, height: 12),
                pupilSize: NSSize(width: 7, height: 7),
                maxOffsetX: 1,
                maxOffsetY: 1,
                pupilColor: activePupilColor.withAlphaComponent(0.5),
                lidOverlayHeight: 6,
                sparkleAlpha: 0
            )
        }
    }

    private func pupilOrigin(in eyeRect: NSRect, pupilSize: NSSize, style: EyeStyle) -> CGPoint {
        let neutralOrigin = CGPoint(
            x: eyeRect.midX - pupilSize.width / 2,
            y: eyeRect.midY - pupilSize.height / 2 + (attentionMode == .idle ? 1.5 : 0)
        )

        guard attentionMode != .idle, let mappedTargetPoint else {
            return neutralOrigin
        }

        let eyeCenter = CGPoint(x: eyeRect.midX, y: eyeRect.midY)
        let dx = mappedTargetPoint.x - eyeCenter.x
        let dy = mappedTargetPoint.y - eyeCenter.y
        let distance = hypot(dx, dy)

        guard distance > 0.001 else {
            return neutralOrigin
        }

        let normalizedX = dx / distance
        let normalizedY = dy / distance

        let offset = CGPoint(
            x: normalizedX * style.maxOffsetX,
            y: normalizedY * style.maxOffsetY
        )

        return CGPoint(
            x: neutralOrigin.x + offset.x,
            y: neutralOrigin.y + offset.y
        )
    }

    private var hasActiveGenerationPerformance: Bool {
        switch generationPhase {
        case .preparing, .streaming, .settling:
            return attentionMode == .waitingForResponse
        case .inactive:
            return false
        }
    }

    private var bubbleText: String? {
        guard hasActiveGenerationPerformance else {
            return nil
        }

        switch generationPhase {
        case .preparing:
            return "在看"
        case .streaming:
            return "唔..."
        case .settling:
            return "嗯？"
        case .inactive:
            return nil
        }
    }

    private var mouthStyle: MouthStyle {
        switch attentionMode {
        case .typing:
            return .focused
        case .waitingForResponse:
            switch generationPhase {
            case .streaming:
                return .curiousOpen
            case .settling:
                return .softSmile
            case .preparing:
                return .curiousClosed
            case .inactive:
                return .curiousClosed
            }
        case .idle:
            return .resting
        }
    }
}
