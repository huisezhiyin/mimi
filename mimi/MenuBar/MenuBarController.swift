import AppKit

final class MenuBarController: NSObject {
    var onRefreshStatus: (() -> Void)?
    var onRequestPermission: (() -> Void)?
    var onRequestScreenCapturePermission: (() -> Void)?
    var onOpenAccessibilitySettings: (() -> Void)?
    var onOpenScreenCaptureSettings: (() -> Void)?
    var onProbeTextCursor: (() -> Void)?
    var onProbeTrackingTarget: (() -> Void)?
    var onProbeLocalCoordinate: (() -> Void)?
    var onProbeCompanionState: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let accessibilityPermissionStatusItem = NSMenuItem(title: "辅助功能权限：检测中", action: nil, keyEquivalent: "")
    private let screenCapturePermissionStatusItem = NSMenuItem(title: "屏幕录制权限：检测中", action: nil, keyEquivalent: "")

    override init() {
        super.init()

        statusItem.button?.title = "mimi"
        accessibilityPermissionStatusItem.isEnabled = false
        screenCapturePermissionStatusItem.isEnabled = false

        menu.addItem(accessibilityPermissionStatusItem)
        menu.addItem(screenCapturePermissionStatusItem)
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "刷新权限状态", action: #selector(handleRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let requestPermissionItem = NSMenuItem(title: "请求辅助功能权限", action: #selector(handleRequestPermission), keyEquivalent: "p")
        requestPermissionItem.target = self
        menu.addItem(requestPermissionItem)

        let requestScreenCapturePermissionItem = NSMenuItem(title: "请求屏幕录制权限", action: #selector(handleRequestScreenCapturePermission), keyEquivalent: "")
        requestScreenCapturePermissionItem.target = self
        menu.addItem(requestScreenCapturePermissionItem)

        let probeCursorItem = NSMenuItem(title: "读取当前文本光标", action: #selector(handleProbeTextCursor), keyEquivalent: "t")
        probeCursorItem.target = self
        menu.addItem(probeCursorItem)

        let probeTargetItem = NSMenuItem(title: "读取当前跟随目标", action: #selector(handleProbeTrackingTarget), keyEquivalent: "g")
        probeTargetItem.target = self
        menu.addItem(probeTargetItem)

        let probeLocalCoordinateItem = NSMenuItem(title: "读取当前本地坐标", action: #selector(handleProbeLocalCoordinate), keyEquivalent: "l")
        probeLocalCoordinateItem.target = self
        menu.addItem(probeLocalCoordinateItem)

        let probeStateItem = NSMenuItem(title: "读取当前状态", action: #selector(handleProbeCompanionState), keyEquivalent: "s")
        probeStateItem.target = self
        menu.addItem(probeStateItem)

        let openSettingsItem = NSMenuItem(title: "打开辅助功能设置", action: #selector(handleOpenSettings), keyEquivalent: ",")
        openSettingsItem.target = self
        menu.addItem(openSettingsItem)

        let openScreenCaptureSettingsItem = NSMenuItem(title: "打开屏幕录制设置", action: #selector(handleOpenScreenCaptureSettings), keyEquivalent: "")
        openScreenCaptureSettingsItem.target = self
        menu.addItem(openScreenCaptureSettingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出 mimi", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func update(accessibilityGranted: Bool, screenCaptureGranted: Bool) {
        accessibilityPermissionStatusItem.title = accessibilityGranted ? "辅助功能权限：已授权" : "辅助功能权限：未授权"
        screenCapturePermissionStatusItem.title = screenCaptureGranted ? "屏幕录制权限：已授权" : "屏幕录制权限：未授权"
        statusItem.button?.title = accessibilityGranted ? "mimi" : "mimi!"
    }

    @objc
    private func handleRefresh() {
        onRefreshStatus?()
    }

    @objc
    private func handleRequestPermission() {
        onRequestPermission?()
    }

    @objc
    private func handleRequestScreenCapturePermission() {
        onRequestScreenCapturePermission?()
    }

    @objc
    private func handleProbeTextCursor() {
        onProbeTextCursor?()
    }

    @objc
    private func handleProbeTrackingTarget() {
        onProbeTrackingTarget?()
    }

    @objc
    private func handleProbeLocalCoordinate() {
        onProbeLocalCoordinate?()
    }

    @objc
    private func handleProbeCompanionState() {
        onProbeCompanionState?()
    }

    @objc
    private func handleOpenSettings() {
        onOpenAccessibilitySettings?()
    }

    @objc
    private func handleOpenScreenCaptureSettings() {
        onOpenScreenCaptureSettings?()
    }

    @objc
    private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
