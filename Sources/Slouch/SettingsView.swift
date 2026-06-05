import SwiftUI
import UniformTypeIdentifiers
import SlouchCore

/// Esc closes the window. A zero-size button carrying .cancelAction is more
/// reliable than onExitCommand, which needs the root view to be focusable.
struct CloseOnEscape: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.background {
            Button("") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func closesOnEscape() -> some View { modifier(CloseOnEscape()) }
}

/// Accessory apps aren't activated when a settings window opens, so it
/// would otherwise appear (or stay) behind the frontmost app.
/// SwiftUI assigns NSWindow identifiers derived from the scene id, so
/// match by substring rather than equality.
func bringToFront(id: String) {
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.async {
        guard let window = NSApp.windows
            .first(where: { $0.identifier?.rawValue.contains(id) == true }) else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

struct GeneralTab: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Startup") {
                SettingsRow(color: .green, symbol: "power", title: "Launch at login") {
                    Toggle("", isOn: $model.launchAtLogin).labelsHidden()
                }
                SettingsRow(color: .orange, symbol: "bolt.fill", title: "Enable on launch") {
                    Toggle("", isOn: $model.config.settings.enableOnLaunch).labelsHidden()
                }
                SettingsRow(color: .blue, symbol: "arrow.down.circle",
                            title: "Check for updates", subtitle: "Once a day, from GitHub releases") {
                    Toggle("", isOn: $model.config.settings.checkForUpdates).labelsHidden()
                }
            }
            Section("Sensitivity") {
                SettingsRow(color: .blue, symbol: "cursorarrow",
                            title: "Cursor speed", subtitle: "400 – 3000 px/s · Recommended 1400") {
                    SliderInputRow(value: $model.config.settings.cursorSpeed,
                                   range: 400...3000, step: 100,
                                   format: .number.precision(.fractionLength(0)).grouping(.never))
                }
                SettingsRow(color: .indigo, symbol: "arrow.up.and.down",
                            title: "Scroll speed", subtitle: "5 – 80 lines/s · Recommended 30") {
                    SliderInputRow(value: $model.config.settings.scrollSpeed,
                                   range: 5...80, step: 5,
                                   format: .number.precision(.fractionLength(0)))
                }
                SettingsRow(color: .graphite, symbol: "target",
                            title: "Dead zone", subtitle: "0 – 50% · Recommended 5%") {
                    SliderInputRow(value: $model.config.settings.deadZone,
                                   range: 0...0.5, step: 0.01,
                                   format: .percent.precision(.fractionLength(0)))
                }
            }
            Section("Sticks") {
                SettingsRow(color: .teal, symbol: "l.joystick",
                            title: "Left stick", subtitle: roleSubtitle(model.config.mapping.leftStick)) {
                    StickRolePicker(role: $model.config.mapping.leftStick)
                }
                SettingsRow(color: .purple, symbol: "r.joystick",
                            title: "Right stick", subtitle: roleSubtitle(model.config.mapping.rightStick)) {
                    StickRolePicker(role: $model.config.mapping.rightStick)
                }
                SettingsRow(color: .pink, symbol: "arrow.up.arrow.down",
                            title: "Invert scroll direction", subtitle: "Match trackpad \"natural\" scrolling") {
                    Toggle("", isOn: $model.config.settings.invertScroll).labelsHidden()
                }
            }
            Section {
                SettingsRow(color: .gray, symbol: "arrow.counterclockwise",
                            title: "Backup", subtitle: "Export or import all settings") {
                    HStack(spacing: 8) {
                        Button("Import") { importConfig() }
                        Button("Export") { exportConfig() }
                    }
                }
            } header: {
                Text("Configuration")
            } footer: {
                Text("Save the full configuration to a file, or restore a previous one.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .contentShape(Rectangle())
        // Clicking empty form area doesn't resign first responder on macOS;
        // do it by hand so text fields lose their focus ring.
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Slouch-config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try MappingStore.encode(model.config).write(to: url, options: .atomic)
        } catch {
            showAlert("Export failed", error.localizedDescription)
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            model.config = try MappingStore.decode(try Data(contentsOf: url))
        } catch {
            showAlert("Import failed", "Not a valid Slouch configuration file. Your current configuration is unchanged.")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

func roleSubtitle(_ role: StickRole) -> String {
    switch role {
    case .mouseMove: return "Drives the cursor"
    case .scroll: return "Vertical & horizontal"
    case .none: return "Off"
    }
}

struct StickRolePicker: View {
    @Binding var role: StickRole

    var body: some View {
        Picker("", selection: $role) {
            Text("Move mouse").tag(StickRole.mouseMove)
            Text("Scroll").tag(StickRole.scroll)
            Text("Off").tag(StickRole.none)
        }
        .labelsHidden()
        .fixedSize()
    }
}

