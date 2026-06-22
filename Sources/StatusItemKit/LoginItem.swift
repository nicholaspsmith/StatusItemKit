import AppKit
import ServiceManagement

/// Start-at-Login via SMAppService.mainApp (registration is bundle-ID based and
/// requires the app to live in /Applications or ~/Applications).
public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Toggle registration. On failure (most often: app not in /Applications),
    /// shows a warning alert.
    public static func toggle() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't toggle Start at Login"
            alert.informativeText = """
            \(error.localizedDescription)

            macOS requires the app to live in /Applications or ~/Applications for this to work. Move the app there and try again.
            """
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
