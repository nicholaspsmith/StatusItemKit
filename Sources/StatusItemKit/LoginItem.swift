import AppKit
import ServiceManagement

/// Start-at-Login via SMAppService.mainApp (registration is bundle-ID based and
/// requires the app to live in /Applications or ~/Applications).
public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister, surfacing failure to the caller. Alert-free, so
    /// it is also usable from a headless one-shot invocation.
    ///
    /// Setting the state it is already in is a no-op rather than an error.
    public static func setEnabled(_ enabled: Bool) throws {
        let svc = SMAppService.mainApp
        guard (svc.status == .enabled) != enabled else { return }
        if enabled {
            try svc.register()
        } else {
            try svc.unregister()
        }
    }

    /// Toggle registration. On failure (most often: app not in /Applications),
    /// shows a warning alert.
    public static func toggle() {
        do {
            try setEnabled(!isEnabled)
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
