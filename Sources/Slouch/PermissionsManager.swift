import AppKit
import ApplicationServices

enum PermissionsManager {
    /// Whether the app may post synthetic input (Accessibility permission).
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system Accessibility dialog if not yet trusted.
    static func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
