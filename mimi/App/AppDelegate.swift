import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionService = AccessibilityPermissionService()
    private let screenCapturePermissionService = ScreenCapturePermissionService()
    private let cursorService = AccessibilityCursorService()
    private let mouseTrackingService = MouseTrackingService()
    private let activityMonitorService = ActivityMonitorService()
    private let companionStateMachine = CompanionStateMachine()
    private let screenChangeMonitorService = ScreenChangeMonitorService()
    private let traceCodexProvider = TraceCodexProvider()
    private lazy var generationSessionCoordinator = GenerationSessionCoordinator(providers: [traceCodexProvider])
    private var menuBarController: MenuBarController?
    private var petWindowController: PetWindowController?
    private var hasShownPermissionAlert = false
    private var stateRefreshTimer: Timer?
    private var trackingRefreshTimer: Timer?
    private var lastAttentionMode: AttentionMode = .typing
    private var lastTextCursorSnapshot: TextCursorSnapshot?
    private var lastTextCursorAt: Date?
    private var lastTypingCursorSnapshot: TextCursorSnapshot?
    private var lastTypingCursorAt: Date?
    private var lastScreenObservation: ScreenChangeObservation?
    private var lastScreenObservationAt: Date?
    private var lastDynamicScreenObservation: ScreenChangeObservation?
    private var lastDynamicScreenObservationAt: Date?
    private let logger = Logger(subsystem: "mimi", category: "app")
    private var lastLoggedGenerationSummary: String?

    private let typingCursorHoldDuration: TimeInterval = 1.4
    private let waitingCursorRetentionDuration: TimeInterval = 16
    private let waitingScreenObservationInterval: TimeInterval = 0.25
    private let dynamicScreenLookHoldDuration: TimeInterval = 1.2
    private let typingAttentionThreshold: TimeInterval = 1.8
    private let terminalGenerationLookAheadHeight: CGFloat = 116
    private let terminalGenerationLookAheadWidth: CGFloat = 360

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuBarController = MenuBarController()
        let petWindowController = PetWindowController()

        menuBarController.onRefreshStatus = { [weak self] in
            self?.refreshPermissionStatus(promptIfNeeded: false)
        }
        menuBarController.onRequestPermission = { [weak self] in
            self?.refreshPermissionStatus(promptIfNeeded: true)
        }
        menuBarController.onRequestScreenCapturePermission = { [weak self] in
            self?.refreshScreenCapturePermissionStatus(promptIfNeeded: true)
        }
        menuBarController.onProbeTextCursor = { [weak self] in
            self?.probeFocusedTextCursor()
        }
        menuBarController.onProbeTrackingTarget = { [weak self] in
            self?.probeCurrentTrackingTarget()
        }
        menuBarController.onProbeLocalCoordinate = { [weak self] in
            self?.probeCurrentLocalCoordinate()
        }
        menuBarController.onProbeCompanionState = { [weak self] in
            self?.probeCompanionState()
        }
        menuBarController.onOpenAccessibilitySettings = { [weak self] in
            self?.permissionService.openAccessibilitySettings()
            self?.refreshPermissionStatus(promptIfNeeded: false)
        }
        menuBarController.onOpenScreenCaptureSettings = { [weak self] in
            self?.screenCapturePermissionService.openScreenCaptureSettings()
            self?.refreshScreenCapturePermissionStatus(promptIfNeeded: false)
        }

        self.menuBarController = menuBarController
        self.petWindowController = petWindowController

        mouseTrackingService.start()
        activityMonitorService.start()
        generationSessionCoordinator.start()
        petWindowController.showWindow(nil)
        petWindowController.window?.orderFrontRegardless()
        petWindowController.setTrackingStatus("目标：鼠标待命")
        petWindowController.setMappedTargetPoint(nil)
        petWindowController.setCompanionState(CompanionState.focus.badgeText)
        petWindowController.setAttentionMode(.typing)
        startStateRefreshTimer()
        startTrackingRefreshTimer()
        refreshPermissionStatus(promptIfNeeded: false)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermissionStatus(promptIfNeeded: false)
        refreshCompanionState()
        refreshTrackingVisuals()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stateRefreshTimer?.invalidate()
        trackingRefreshTimer?.invalidate()
        generationSessionCoordinator.stop()
    }

    private func refreshPermissionStatus(promptIfNeeded: Bool) {
        let accessibilityGranted = permissionService.isAccessibilityTrusted(prompt: promptIfNeeded)
        let screenCaptureGranted = screenCapturePermissionService.isScreenCaptureTrusted(prompt: false)
        menuBarController?.update(accessibilityGranted: accessibilityGranted, screenCaptureGranted: screenCaptureGranted)
        petWindowController?.setPermissionGranted(accessibilityGranted)

        if !accessibilityGranted && !hasShownPermissionAlert {
            hasShownPermissionAlert = true
            presentPermissionAlert()
        }
    }

    private func refreshScreenCapturePermissionStatus(promptIfNeeded: Bool) {
        let accessibilityGranted = permissionService.isAccessibilityTrusted(prompt: false)
        let screenCaptureGranted = screenCapturePermissionService.isScreenCaptureTrusted(prompt: promptIfNeeded)
        menuBarController?.update(accessibilityGranted: accessibilityGranted, screenCaptureGranted: screenCaptureGranted)
    }

    private func startStateRefreshTimer() {
        stateRefreshTimer?.invalidate()
        stateRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshCompanionState()
        }
        if let stateRefreshTimer {
            RunLoop.main.add(stateRefreshTimer, forMode: .common)
        }
    }

    private func startTrackingRefreshTimer() {
        trackingRefreshTimer?.invalidate()
        trackingRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            self?.refreshTrackingVisuals()
        }
        if let trackingRefreshTimer {
            RunLoop.main.add(trackingRefreshTimer, forMode: .common)
        }
    }

    private func refreshCompanionState() {
        let evaluation = companionStateMachine.evaluate(snapshot: activityMonitorService.currentSnapshot())
        petWindowController?.setCompanionState(evaluation.state.badgeText)
    }

    private func refreshTrackingVisuals() {
        let now = Date()
        let activitySnapshot = activityMonitorService.currentSnapshot(now: now)
        let stateEvaluation = companionStateMachine.evaluate(snapshot: activitySnapshot)
        let generationSnapshot = resolveGenerationSnapshot(now: now)
        logGenerationSnapshot(generationSnapshot)
        let attentionMode = resolveAttentionMode(
            now: now,
            activitySnapshot: activitySnapshot,
            stateEvaluation: stateEvaluation,
            generationSnapshot: generationSnapshot
        )

        if attentionMode != lastAttentionMode {
            logger.debug("attention mode \(self.lastAttentionMode.badgeText, privacy: .public) -> \(attentionMode.badgeText, privacy: .public)")
            if attentionMode != .waitingForResponse {
                resetScreenChangeObservation()
            }
            lastAttentionMode = attentionMode
        }

        let trackingTarget = resolveTrackingTarget(
            now: now,
            activitySnapshot: activitySnapshot,
            stateEvaluation: stateEvaluation,
            attentionMode: attentionMode,
            generationSnapshot: generationSnapshot
        )

        petWindowController?.setAttentionMode(attentionMode)
        petWindowController?.setGenerationPhase(generationSnapshot?.phase ?? .inactive)

        switch trackingTarget {
        case .cursor:
            petWindowController?.setTrackingStatus("目标：监督输入")
        case .cursorHold:
            petWindowController?.setTrackingStatus("目标：盯住最近输入")
        case .generation(let snapshot, _):
            petWindowController?.setTrackingStatus(snapshot.activeSessionCount > 1 ? "目标：Codex 主会话生成" : "目标：Codex 正在生成")
        case .screenChange:
            petWindowController?.setTrackingStatus("目标：好奇看生成")
        case .mouse:
            petWindowController?.setTrackingStatus("目标：鼠标 fallback")
        case .unavailable:
            petWindowController?.setTrackingStatus("目标：休息中")
        }

        guard let globalPoint = trackingTarget.globalPoint,
              let localTrackingPoint = petWindowController?.mapGlobalPointToPetView(globalPoint) else {
            petWindowController?.setMappedTargetPoint(nil)
            return
        }

        petWindowController?.setMappedTargetPoint(localTrackingPoint.viewPoint)
    }

    private func logGenerationSnapshot(_ generationSnapshot: GenerationSignalSnapshot?) {
        let summary: String
        if let generationSnapshot {
            summary = [
                generationSnapshot.source,
                generationSnapshot.phase.debugLabel,
                generationSnapshot.sessionId,
                generationSnapshot.workDir ?? "-"
            ].joined(separator: " | ")
        } else {
            summary = "none"
        }

        guard summary != lastLoggedGenerationSummary else {
            return
        }

        lastLoggedGenerationSummary = summary
        logger.debug("generation snapshot \(summary, privacy: .public)")
    }

    private func resolveAttentionMode(
        now: Date,
        activitySnapshot: ActivitySnapshot,
        stateEvaluation: CompanionStateEvaluation,
        generationSnapshot: GenerationSignalSnapshot?
    ) -> AttentionMode {
        if stateEvaluation.state == .idle {
            return .idle
        }

        if let generationSnapshot, generationSnapshot.phase != .inactive {
            return .waitingForResponse
        }

        if let lastKeyboardActivityAt = activitySnapshot.lastKeyboardActivityAt,
           now.timeIntervalSince(lastKeyboardActivityAt) <= typingAttentionThreshold {
            return .typing
        }

        if stateEvaluation.state == .wait,
           let lastTypingCursorAt,
           now.timeIntervalSince(lastTypingCursorAt) <= waitingCursorRetentionDuration {
            return .waitingForResponse
        }

        return .typing
    }

    private func resolveTrackingTarget(
        now: Date,
        activitySnapshot: ActivitySnapshot,
        stateEvaluation: CompanionStateEvaluation,
        attentionMode: AttentionMode,
        generationSnapshot: GenerationSignalSnapshot?
    ) -> TrackingTarget {
        let cursorProbe = cursorService.captureFocusedTextCursor()
        let cursorFailure: TextCursorProbeError?

        switch cursorProbe {
        case .success(let snapshot):
            rememberTextCursor(snapshot, at: now, activitySnapshot: activitySnapshot)
            cursorFailure = nil
        case .failure(let error):
            cursorFailure = error
        }

        switch attentionMode {
        case .typing:
            switch cursorProbe {
            case .success(let snapshot):
                return .cursor(snapshot)
            case .failure(let error):
                if let heldCursor = recentCursor(at: now, maxAge: typingCursorHoldDuration) {
                    let age = now.timeIntervalSince(lastTextCursorAt ?? now)
                    return .cursorHold(heldCursor, age: age)
                }

                return .mouse(mouseTrackingService.currentSnapshot(), fallbackReason: error)
            }

        case .waitingForResponse:
            if let generationSnapshot,
               let generationTrackingTarget = resolveGenerationTrackingTarget(
                generationSnapshot: generationSnapshot,
                now: now
               ) {
                return generationTrackingTarget
            }

            if let waitingCursor = recentTypingCursor(at: now, maxAge: waitingCursorRetentionDuration) ?? recentCursor(at: now, maxAge: waitingCursorRetentionDuration) {
                if let screenTarget = resolveWaitingScreenTarget(now: now, anchorRect: waitingCursor.rect) {
                    return screenTarget
                }

                let age = now.timeIntervalSince(lastTypingCursorAt ?? lastTextCursorAt ?? now)
                return .cursorHold(waitingCursor, age: age)
            }

            if case .success(let snapshot) = cursorProbe {
                return .cursor(snapshot)
            }

            return .mouse(mouseTrackingService.currentSnapshot(), fallbackReason: cursorFailure)

        case .idle:
            if stateEvaluation.state == .idle {
                return .unavailable(reason: "Idle 状态降低主动跟随")
            }

            return .mouse(mouseTrackingService.currentSnapshot(), fallbackReason: cursorFailure)
        }
    }

    private func rememberTextCursor(_ snapshot: TextCursorSnapshot, at now: Date, activitySnapshot: ActivitySnapshot) {
        lastTextCursorSnapshot = snapshot
        lastTextCursorAt = now

        if let lastKeyboardActivityAt = activitySnapshot.lastKeyboardActivityAt,
           now.timeIntervalSince(lastKeyboardActivityAt) <= typingAttentionThreshold {
            lastTypingCursorSnapshot = snapshot
            lastTypingCursorAt = now
        }
    }

    private func recentCursor(at now: Date, maxAge: TimeInterval) -> TextCursorSnapshot? {
        guard let lastTextCursorSnapshot, let lastTextCursorAt else {
            return nil
        }

        guard now.timeIntervalSince(lastTextCursorAt) <= maxAge else {
            return nil
        }

        return lastTextCursorSnapshot
    }

    private func recentTypingCursor(at now: Date, maxAge: TimeInterval) -> TextCursorSnapshot? {
        guard let lastTypingCursorSnapshot, let lastTypingCursorAt else {
            return nil
        }

        guard now.timeIntervalSince(lastTypingCursorAt) <= maxAge else {
            return nil
        }

        return lastTypingCursorSnapshot
    }

    private func resolveGenerationSnapshot(now: Date) -> GenerationSignalSnapshot? {
        let frontmostAppName = NSWorkspace.shared.frontmostApplication?.localizedName
        return generationSessionCoordinator.currentSnapshot(now: now, frontmostAppName: frontmostAppName)
    }

    private func resolveGenerationTrackingTarget(
        generationSnapshot: GenerationSignalSnapshot,
        now: Date
    ) -> TrackingTarget? {
        if let outputAnchorRect = generationSnapshot.outputAnchorRect {
            return .generation(generationSnapshot, anchorRect: outputAnchorRect)
        }

        if let terminalCursor = recentTerminalCursor(at: now, maxAge: waitingCursorRetentionDuration) {
            return .generation(generationSnapshot, anchorRect: derivedGenerationAnchorRect(from: terminalCursor.rect))
        }

        if let fallbackCursor = recentCursor(at: now, maxAge: waitingCursorRetentionDuration) {
            return .generation(generationSnapshot, anchorRect: fallbackCursor.rect)
        }

        return nil
    }

    private func recentTerminalCursor(at now: Date, maxAge: TimeInterval) -> TextCursorSnapshot? {
        guard let terminalCursor = recentTypingCursor(at: now, maxAge: maxAge) ?? recentCursor(at: now, maxAge: maxAge) else {
            return nil
        }

        guard isTerminalLikeApplication(terminalCursor.appName) else {
            return nil
        }

        return terminalCursor
    }

    private func isTerminalLikeApplication(_ appName: String?) -> Bool {
        guard let appName else {
            return false
        }

        let normalized = appName.lowercased()
        let keywords = ["codex", "terminal", "iterm", "warp", "ghostty", "kitty", "wezterm", "alacritty"]
        return keywords.contains(where: { normalized.contains($0) })
    }

    private func derivedGenerationAnchorRect(from cursorRect: CGRect) -> CGRect {
        let width = max(terminalGenerationLookAheadWidth, cursorRect.width + 240)
        let height = terminalGenerationLookAheadHeight
        return CGRect(
            x: cursorRect.midX - width / 2,
            y: cursorRect.maxY + 20,
            width: width,
            height: height
        )
    }

    private func resolveWaitingScreenTarget(now: Date, anchorRect: CGRect) -> TrackingTarget? {
        let observation = screenObservation(at: now, anchorRect: anchorRect)
        if observation.isDynamic {
            lastDynamicScreenObservation = observation
            lastDynamicScreenObservationAt = now
            return .screenChange(observation)
        }

        if let lastDynamicScreenObservation,
           let lastDynamicScreenObservationAt,
           now.timeIntervalSince(lastDynamicScreenObservationAt) <= dynamicScreenLookHoldDuration {
            return .screenChange(lastDynamicScreenObservation)
        }

        return nil
    }

    private func screenObservation(at now: Date, anchorRect: CGRect) -> ScreenChangeObservation {
        if let lastScreenObservation,
           let lastScreenObservationAt,
           now.timeIntervalSince(lastScreenObservationAt) <= waitingScreenObservationInterval {
            return lastScreenObservation
        }

        let observation = screenChangeMonitorService.observe(around: anchorRect)
        lastScreenObservation = observation
        lastScreenObservationAt = now
        return observation
    }

    private func resetScreenChangeObservation() {
        screenChangeMonitorService.reset()
        lastScreenObservation = nil
        lastScreenObservationAt = nil
        lastDynamicScreenObservation = nil
        lastDynamicScreenObservationAt = nil
    }

    private func presentPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = "mimi 需要辅助功能权限来读取文本光标位置。未授权时，当前版本只能完成窗口展示和后续的鼠标跟随降级链路。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            permissionService.openAccessibilitySettings()
        }
    }

    private func probeFocusedTextCursor() {
        refreshPermissionStatus(promptIfNeeded: false)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")

        switch cursorService.captureFocusedTextCursor() {
        case .success(let snapshot):
            petWindowController?.setTrackingStatus("目标：文本光标")
            alert.messageText = "文本光标获取成功"
            alert.informativeText = snapshot.debugSummary
        case .failure(let error):
            petWindowController?.setTrackingStatus("目标：文本光标失败")
            alert.messageText = error.messageText
            alert.informativeText = error.recoverySuggestion
        }

        alert.runModal()
    }

    private func probeCurrentTrackingTarget() {
        refreshPermissionStatus(promptIfNeeded: false)
        refreshTrackingVisuals()
        NSApp.activate(ignoringOtherApps: true)

        let now = Date()
        let activitySnapshot = activityMonitorService.currentSnapshot(now: now)
        let stateEvaluation = companionStateMachine.evaluate(snapshot: activitySnapshot)
        let generationSnapshot = resolveGenerationSnapshot(now: now)
        let attentionMode = resolveAttentionMode(
            now: now,
            activitySnapshot: activitySnapshot,
            stateEvaluation: stateEvaluation,
            generationSnapshot: generationSnapshot
        )
        let trackingTarget = resolveTrackingTarget(
            now: now,
            activitySnapshot: activitySnapshot,
            stateEvaluation: stateEvaluation,
            attentionMode: attentionMode,
            generationSnapshot: generationSnapshot
        )

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.messageText = "当前跟随目标"
        alert.informativeText = "\(attentionMode.badgeText)\n\n\(trackingTarget.debugSummary)"
        alert.runModal()
    }

    private func probeCurrentLocalCoordinate() {
        refreshPermissionStatus(promptIfNeeded: false)
        refreshCompanionState()
        refreshTrackingVisuals()
        NSApp.activate(ignoringOtherApps: true)

        let now = Date()
        let activitySnapshot = activityMonitorService.currentSnapshot(now: now)
        let stateEvaluation = companionStateMachine.evaluate(snapshot: activitySnapshot)
        let generationSnapshot = resolveGenerationSnapshot(now: now)
        let attentionMode = resolveAttentionMode(
            now: now,
            activitySnapshot: activitySnapshot,
            stateEvaluation: stateEvaluation,
            generationSnapshot: generationSnapshot
        )
        let trackingTarget = resolveTrackingTarget(
            now: now,
            activitySnapshot: activitySnapshot,
            stateEvaluation: stateEvaluation,
            attentionMode: attentionMode,
            generationSnapshot: generationSnapshot
        )

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")

        guard let globalPoint = trackingTarget.globalPoint else {
            petWindowController?.setMappedTargetPoint(nil)
            alert.messageText = "本地坐标映射失败"
            alert.informativeText = "当前没有可用的全局目标点。"
            alert.runModal()
            return
        }

        guard let localTrackingPoint = petWindowController?.mapGlobalPointToPetView(globalPoint) else {
            petWindowController?.setMappedTargetPoint(nil)
            alert.messageText = "本地坐标映射失败"
            alert.informativeText = "宠物窗口尚未就绪，无法完成坐标转换。"
            alert.runModal()
            return
        }

        petWindowController?.setMappedTargetPoint(localTrackingPoint.viewPoint)
        alert.messageText = "当前本地坐标"
        alert.informativeText = "\(attentionMode.badgeText)\n\n\(trackingTarget.debugSummary)\n\n\(localTrackingPoint.debugSummary)"
        alert.runModal()
    }

    private func probeCompanionState() {
        refreshPermissionStatus(promptIfNeeded: false)
        refreshCompanionState()
        NSApp.activate(ignoringOtherApps: true)

        let evaluation = companionStateMachine.evaluate(snapshot: activityMonitorService.currentSnapshot())

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.messageText = "当前状态"
        alert.informativeText = evaluation.debugSummary
        alert.runModal()
    }
}
