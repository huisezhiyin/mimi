import AppKit

struct ActivitySnapshot {
    let now: Date
    let lastActivityAt: Date
    let lastKeyboardActivityAt: Date?
    let lastMouseActivityAt: Date?
    let lastMouseMovementDistance: CGFloat

    var idleDuration: TimeInterval {
        now.timeIntervalSince(lastActivityAt)
    }
}

final class ActivityMonitorService {
    private var keyboardMonitor: Any?
    private var mouseMonitor: Any?
    private var lastActivityAt = Date()
    private var lastKeyboardActivityAt: Date?
    private var lastMouseActivityAt: Date?
    private var lastMousePoint = NSEvent.mouseLocation
    private var lastMouseMovementDistance: CGFloat = 0

    deinit {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
    }

    func start() {
        if keyboardMonitor == nil {
            keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
                self?.recordKeyboardActivity()
            }
        }

        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            ) { [weak self] event in
                self?.recordMouseActivity(at: event.locationInWindow)
            }
        }
    }

    func currentSnapshot(now: Date = Date()) -> ActivitySnapshot {
        ActivitySnapshot(
            now: now,
            lastActivityAt: lastActivityAt,
            lastKeyboardActivityAt: lastKeyboardActivityAt,
            lastMouseActivityAt: lastMouseActivityAt,
            lastMouseMovementDistance: lastMouseMovementDistance
        )
    }

    private func recordKeyboardActivity() {
        let now = Date()
        lastActivityAt = now
        lastKeyboardActivityAt = now
    }

    private func recordMouseActivity(at point: CGPoint) {
        let now = Date()
        lastMouseMovementDistance = hypot(point.x - lastMousePoint.x, point.y - lastMousePoint.y)
        lastMousePoint = point
        lastActivityAt = now
        lastMouseActivityAt = now
    }
}
