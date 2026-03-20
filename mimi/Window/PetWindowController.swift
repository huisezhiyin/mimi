import AppKit

final class PetWindowController: NSWindowController {
    private let petView = PetView(frame: NSRect(origin: .zero, size: NSSize(width: 220, height: 220)))
    private let coordinateMapper = WindowCoordinateMapper()

    init() {
        let window = PetWindow(frame: Self.defaultFrame())
        super.init(window: window)

        window.contentView = petView
        window.orderFrontRegardless()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPermissionGranted(_ granted: Bool) {
        petView.permissionGranted = granted
    }

    func setTrackingStatus(_ text: String) {
        petView.trackingStatusText = text
    }

    func mapGlobalPointToPetView(_ globalPoint: CGPoint) -> LocalTrackingPoint? {
        guard let window else {
            return nil
        }

        return coordinateMapper.mapGlobalPoint(globalPoint, in: window, targetView: petView)
    }

    func setMappedTargetPoint(_ point: CGPoint?) {
        petView.mappedTargetPoint = point
    }

    func setCompanionState(_ text: String) {
        petView.stateStatusText = text
    }

    func setAttentionMode(_ mode: AttentionMode) {
        petView.attentionMode = mode
    }

    func setGenerationPhase(_ phase: GenerationPhase) {
        petView.generationPhase = phase
    }

    private static func defaultFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 40, y: 40, width: 220, height: 220)
        }

        let visibleFrame = screen.visibleFrame
        return NSRect(
            x: visibleFrame.maxX - 260,
            y: visibleFrame.minY + 80,
            width: 220,
            height: 220
        )
    }
}
