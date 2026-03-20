import AppKit
import CoreGraphics

final class ScreenCapturePermissionService {
    func isScreenCaptureTrusted(prompt: Bool) -> Bool {
        if prompt {
            return CGRequestScreenCaptureAccess()
        }

        return CGPreflightScreenCaptureAccess()
    }

    func openScreenCaptureSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
