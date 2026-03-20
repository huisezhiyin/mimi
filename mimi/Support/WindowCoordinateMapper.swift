import AppKit

struct LocalTrackingPoint {
    let globalPoint: CGPoint
    let windowPoint: CGPoint
    let viewPoint: CGPoint
    let isInsideViewBounds: Bool

    var debugSummary: String {
        String(
            format: """
            全局坐标：x=%.1f, y=%.1f
            窗口坐标：x=%.1f, y=%.1f
            视图坐标：x=%.1f, y=%.1f
            是否落在宠物视图内：%@
            """,
            globalPoint.x,
            globalPoint.y,
            windowPoint.x,
            windowPoint.y,
            viewPoint.x,
            viewPoint.y,
            isInsideViewBounds ? "是" : "否"
        )
    }
}

final class WindowCoordinateMapper {
    func mapGlobalPoint(_ globalPoint: CGPoint, in window: NSWindow, targetView: NSView) -> LocalTrackingPoint? {
        let screenRect = NSRect(origin: globalPoint, size: .zero)
        let windowRect = window.convertFromScreen(screenRect)
        let windowPoint = windowRect.origin
        let viewPoint = targetView.convert(windowPoint, from: nil)
        let isInsideViewBounds = targetView.bounds.contains(viewPoint)

        return LocalTrackingPoint(
            globalPoint: globalPoint,
            windowPoint: windowPoint,
            viewPoint: viewPoint,
            isInsideViewBounds: isInsideViewBounds
        )
    }
}
