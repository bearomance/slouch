import SwiftUI

@main
struct SlouchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: menuBarIcon(enabled: model.isEnabled, connected: model.isConnected))
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
    }
}

/// Composite icon: gamecontroller symbol plus a green dot when the controller
/// is connected. Drawn by hand because a colored dot requires a non-template
/// image; the symbol uses labelColor so it still adapts to menu-bar appearance.
@MainActor
func menuBarIcon(enabled: Bool, connected: Bool) -> NSImage {
    let size = NSSize(width: 27, height: 16)
    let image = NSImage(size: size, flipped: false) { _ in
        let name = "gamecontroller.fill"
        // Opaque colors only: anything translucent picks up the wallpaper
        // tint of the menu bar and stops reading as black/gray.
        let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let ink: NSColor = isDark ? .white : .black
        let dimmed = NSColor(white: isDark ? 0.65 : 0.45, alpha: 1)
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            .applying(.init(paletteColors: [enabled ? ink : dimmed]))
        if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: "Slouch")?
            .withSymbolConfiguration(config) {
            let symbolRect = NSRect(x: 0, y: (size.height - symbol.size.height) / 2,
                                    width: symbol.size.width, height: symbol.size.height)
            symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
        }
        if connected {
            NSColor.systemGreen.setFill()
            NSBezierPath(ovalIn: NSRect(x: size.width - 5.5, y: size.height - 6,
                                        width: 5.5, height: 5.5)).fill()
        }
        return true
    }
    image.isTemplate = false
    return image
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
        if model.isReconnecting && !model.isConnected {
            Text("Controller: reconnecting…")
        } else {
            Text(model.isConnected ? "Controller: connected" : "Controller: not found")
        }
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
