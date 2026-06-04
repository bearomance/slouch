import SwiftUI
import UniformTypeIdentifiers
import SlouchCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            ButtonsTab(model: model)
                .tabItem { Label("Buttons", systemImage: "gamecontroller") }
        }
        .frame(width: 680, height: 600)
        .onAppear { bringToFront() }
    }

}

/// Accessory apps aren't activated when the Settings window opens, so it
/// would otherwise appear (or stay) behind the frontmost app.
func bringToFront() {
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.async {
        NSApp.windows
            .first { $0.identifier?.rawValue.contains("Settings") == true }?
            .makeKeyAndOrderFront(nil)
    }
}

struct GeneralTab: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
                Toggle("Enable on launch", isOn: $model.config.settings.enableOnLaunch)
            }
            Section("Sensitivity") {
                NumberSettingRow(
                    title: "Cursor speed",
                    caption: "400 – 3000 px/s · Recommended 1400",
                    value: $model.config.settings.cursorSpeed,
                    range: 400...3000,
                    step: 100,
                    format: .number.precision(.fractionLength(0)))
                NumberSettingRow(
                    title: "Scroll speed",
                    caption: "5 – 80 lines/s · Recommended 30",
                    value: $model.config.settings.scrollSpeed,
                    range: 5...80,
                    step: 5,
                    format: .number.precision(.fractionLength(0)))
                NumberSettingRow(
                    title: "Dead zone",
                    caption: "0% – 50% · Recommended 5%",
                    value: $model.config.settings.deadZone,
                    range: 0...0.5,
                    step: 0.01,
                    format: .percent.precision(.fractionLength(0)))
            }
            Section("Sticks") {
                Picker("Right stick", selection: $model.config.mapping.rightStick) {
                    Text("Move mouse").tag(StickRole.mouseMove)
                    Text("Scroll").tag(StickRole.scroll)
                    Text("Off").tag(StickRole.none)
                }
                Picker("Left stick", selection: $model.config.mapping.leftStick) {
                    Text("Move mouse").tag(StickRole.mouseMove)
                    Text("Scroll").tag(StickRole.scroll)
                    Text("Off").tag(StickRole.none)
                }
            }
            Section("Configuration") {
                LabeledContent {
                    HStack {
                        Button("Import") { importConfig() }
                        Button("Export") { exportConfig() }
                    }
                } label: {
                    Text("Backup")
                    Text("Save the full configuration to a file, or restore one")
                }
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

struct NumberSettingRow<F: ParseableFormatStyle>: View
where F.FormatInput == Double, F.FormatOutput == String {
    let title: String
    let caption: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: F

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField("", text: $text)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($focused)
                    .onSubmit { commit() }
                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        } label: {
            Text(title)
            Text(caption)
        }
        .onAppear { text = format.format(value) }
        .onChange(of: value) { _, newValue in text = format.format(newValue) }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    /// Validation happens only on ⏎ or focus loss — never mid-typing.
    private func commit() {
        if let parsed = try? format.parseStrategy.parse(text) {
            value = min(max(parsed, range.lowerBound), range.upperBound)
        }
        text = format.format(value)
    }
}
