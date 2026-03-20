import AppKit

final class MouseTrackingService {
    private var globalMonitor: Any?
    private var lastObservedPoint: CGPoint?

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }

    func start() {
        guard globalMonitor == nil else {
            return
        }

        lastObservedPoint = NSEvent.mouseLocation
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.lastObservedPoint = event.locationInWindow
        }
    }

    func currentSnapshot() -> MousePointerSnapshot {
        if let lastObservedPoint {
            return MousePointerSnapshot(point: lastObservedPoint, isFromGlobalMonitor: true)
        }

        return MousePointerSnapshot(point: NSEvent.mouseLocation, isFromGlobalMonitor: false)
    }
}
