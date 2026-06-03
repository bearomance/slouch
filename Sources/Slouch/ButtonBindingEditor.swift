import SwiftUI
import AppKit
import SlouchCore

func modifierFlags(from flags: NSEvent.ModifierFlags) -> ModifierFlags {
    var m: ModifierFlags = []
    if flags.contains(.command) { m.insert(.command) }
    if flags.contains(.shift) { m.insert(.shift) }
    if flags.contains(.option) { m.insert(.option) }
    if flags.contains(.control) { m.insert(.control) }
    return m
}

private enum ActionCategory: String, CaseIterable, Identifiable {
    case off = "Off"
    case mouse = "Mouse"
    case keyboard = "Keyboard"
    case function = "Function"
    var id: String { rawValue }
}

private enum FunctionKind: String, CaseIterable, Identifiable {
    case sleep = "Sleep"
    var id: String { rawValue }
}

private func category(of action: OutputAction?) -> ActionCategory {
    switch action {
    case .mouseClick: return .mouse
    case .keystroke: return .keyboard
    case .sleep: return .function
    case .some(.none), nil: return .off
    }
}

struct ButtonsTab: View {
    @ObservedObject var model: AppModel
    private let buttons: [ButtonID] = [
        .a, .b, .x, .y, .lb, .rb, .lt, .rt, .l3, .r3, .menu, .options,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
    ]

    var body: some View {
        Form {
            Section("Buttons") {
                ForEach(buttons, id: \.self) { button in
                    ButtonBindingRow(button: button, action: binding(for: button))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for button: ButtonID) -> Binding<OutputAction?> {
        Binding(
            get: { model.config.mapping.buttons[button] },
            set: { model.config.mapping.buttons[button] = $0 }
        )
    }
}

struct ButtonBindingRow: View {
    let button: ButtonID
    @Binding var action: OutputAction?

    var body: some View {
        LabeledContent(label(button)) {
            HStack(spacing: 8) {
                Picker("", selection: categoryBinding) {
                    ForEach(ActionCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .frame(width: 120)

                detail
                    .frame(width: 300, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch category(of: action) {
        case .off:
            Color.clear.frame(height: 1)
        case .mouse:
            Picker("", selection: mouseBinding) {
                Text("Left click").tag(MouseButton.left)
                Text("Right click").tag(MouseButton.right)
                Text("Middle click").tag(MouseButton.middle)
            }
            .labelsHidden()
            .frame(width: 160)
        case .keyboard:
            HStack(spacing: 6) {
                KeyComboField(stroke: keystrokeBinding)
                    .frame(width: 170)
                KeyRecorderButton(stroke: keystrokeBinding)
            }
        case .function:
            Picker("", selection: functionBinding) {
                ForEach(FunctionKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 160)
        }
    }

    private var categoryBinding: Binding<ActionCategory> {
        Binding(
            get: { category(of: action) },
            set: { newCategory in
                guard newCategory != category(of: action) else { return }
                switch newCategory {
                case .off: action = OutputAction.none
                case .mouse: action = .mouseClick(.left)
                case .keyboard: action = .keystroke(KeyStroke(keyCode: 49)) // default Space
                case .function: action = .sleep
                }
            }
        )
    }

    private var mouseBinding: Binding<MouseButton> {
        Binding(
            get: { if case .mouseClick(let b)? = action { return b }; return .left },
            set: { action = .mouseClick($0) }
        )
    }

    private var keystrokeBinding: Binding<KeyStroke> {
        Binding(
            get: { if case .keystroke(let k)? = action { return k }; return KeyStroke(keyCode: 49) },
            set: { action = .keystroke($0) }
        )
    }

    private var functionBinding: Binding<FunctionKind> {
        Binding(
            get: { .sleep },
            set: { _ in action = .sleep }
        )
    }

    private func label(_ b: ButtonID) -> String {
        switch b {
        case .dpadUp: return "D-pad ↑"
        case .dpadDown: return "D-pad ↓"
        case .dpadLeft: return "D-pad ←"
        case .dpadRight: return "D-pad →"
        default: return b.rawValue.uppercased()
        }
    }
}

/// Manual key-combo entry: type e.g. "cmd+shift+space" or "F6" and press ⏎.
/// Invalid input reverts to the current binding.
struct KeyComboField: View {
    @Binding var stroke: KeyStroke
    @State private var text = ""

    var body: some View {
        TextField("", text: $text, prompt: Text("cmd+shift+space"))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .onAppear { text = stroke.displayString }
            .onChange(of: stroke) { _, newStroke in text = newStroke.displayString }
            .onSubmit {
                if let parsed = KeyStroke.parse(text) { stroke = parsed }
                text = stroke.displayString
            }
    }
}

struct KeyRecorderButton: View {
    @Binding var stroke: KeyStroke
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? "Press key…" : "Record") {
            recording ? cancel() : start()
        }
        .onDisappear { cancel() }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc cancels recording without binding
                cancel()
                return nil
            }
            stroke = KeyStroke(keyCode: event.keyCode,
                               modifiers: modifierFlags(from: event.modifierFlags))
            cancel()
            return nil // swallow the key so it doesn't reach other UI
        }
    }

    private func cancel() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
