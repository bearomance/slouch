import SwiftUI

@main
struct SlouchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Slouch", systemImage: model.isEnabled ? "gamecontroller.fill" : "gamecontroller") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Toggle("Enabled", isOn: $model.isEnabled)
        Divider()
        Text(model.isConnected ? "Controller: connected" : "Controller: not found")
        if !model.isTrusted {
            Text("⚠︎ Accessibility permission needed")
            Button("Open Accessibility Settings…") {
                PermissionsManager.openAccessibilitySettings()
            }
        }
        Divider()
        SettingsLink { Text("Settings…") }
        Button("Quit Slouch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
