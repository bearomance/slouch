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

private enum ActionKind: String, CaseIterable, Identifiable {
    case none = "Off"
    case leftClick = "Left click"
    case rightClick = "Right click"
    case middleClick = "Middle click"
    case key = "Key…"
    case sleep = "Sleep"
    var id: String { rawValue }
}

private func kind(of action: OutputAction?) -> ActionKind {
    switch action {
    case .mouseClick(.left): return .leftClick
    case .mouseClick(.right): return .rightClick
    case .mouseClick(.middle): return .middleClick
    case .keystroke: return .key
    case .sleep: return .sleep
    case .some(.none), nil: return .none
    }
}

private func makeAction(for kind: ActionKind, existing: OutputAction?) -> OutputAction {
    switch kind {
    case .none: return .none
    case .leftClick: return .mouseClick(.left)
    case .rightClick: return .mouseClick(.right)
    case .middleClick: return .mouseClick(.middle)
    case .sleep: return .sleep
    case .key:
        if case .keystroke(let k)? = existing { return .keystroke(k) }
        return .keystroke(KeyStroke(keyCode: 49)) // default Space
    }
}

struct ButtonsSection: View {
    @ObservedObject var model: AppModel
    private let buttons: [ButtonID] = [
        .a, .b, .x, .y, .lb, .rb, .lt, .rt, .l3, .r3, .menu, .options,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
    ]

    var body: some View {
        Section("Buttons") {
            ForEach(buttons, id: \.self) { button in
                ButtonBindingRow(button: button, action: binding(for: button))
            }
        }
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
        HStack {
            Text(label(button)).frame(width: 90, alignment: .leading)
            Picker("", selection: kindBinding) {
                ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            if case .keystroke? = action {
                KeyRecorderButton(stroke: keystrokeBinding)
            }
        }
    }

    private var kindBinding: Binding<ActionKind> {
        Binding(
            get: { kind(of: action) },
            set: { action = makeAction(for: $0, existing: action) }
        )
    }

    private var keystrokeBinding: Binding<KeyStroke> {
        Binding(
            get: { if case .keystroke(let k)? = action { return k }; return KeyStroke(keyCode: 49) },
            set: { action = .keystroke($0) }
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

struct KeyRecorderButton: View {
    @Binding var stroke: KeyStroke
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? "Press a key…" : stroke.displayString) {
            recording ? cancel() : start()
        }
        .frame(minWidth: 100)
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
