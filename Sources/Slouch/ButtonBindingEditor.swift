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
    case openURL = "Open URL"
    case keyboardViewer = "Keyboard Viewer"
    case precision = "Precision Cursor"
    var id: String { rawValue }
}

private func category(of action: OutputAction?) -> ActionCategory {
    switch action {
    case .mouseClick: return .mouse
    case .keystroke: return .keyboard
    case .openURL, .sleep, .keyboardViewer, .precision: return .function
    case .some(.none), nil: return .off
    }
}

struct ButtonsTab: View {
    @ObservedObject var model: AppModel
    private let groups: [(title: String, buttons: [ButtonID])] = [
        ("Face buttons", [.a, .b, .x, .y]),
        ("Shoulders & triggers", [.lb, .rb, .lt, .rt]),
        ("Stick clicks", [.l3, .r3]),
        ("System", [.menu, .options]),
        ("D-pad", [.dpadUp, .dpadDown, .dpadLeft, .dpadRight]),
    ]

    var body: some View {
        Form {
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.buttons, id: \.self) { button in
                        ButtonBindingRow(button: button, action: binding(for: button))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .contentShape(Rectangle())
        // Clicking empty form area doesn't resign first responder on macOS;
        // do it by hand so text fields lose their focus ring.
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
    }

    private func binding(for button: ButtonID) -> Binding<OutputAction?> {
        Binding(
            get: { model.config.mapping.buttons[button] },
            set: { model.config.mapping.buttons[button] = $0 }
        )
    }
}

struct ButtonBadge: View {
    let button: ButtonID
    @Environment(\.colorScheme) private var colorScheme

    private static let faceColors: [ButtonID: Color] = [
        .a: Color(red: 0.33, green: 0.69, blue: 0.23),
        .b: Color(red: 0.88, green: 0.27, blue: 0.23),
        .x: Color(red: 0.17, green: 0.49, blue: 0.94),
        .y: Color(red: 0.89, green: 0.64, blue: 0.14),
    ]

    var body: some View {
        if let color = Self.faceColors[button] {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay {
                    Text(button.rawValue.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
        } else {
            Text(badgeText)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 7)
                .frame(height: 26)
                .frame(minWidth: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color(red: 0.94, green: 0.94, blue: 0.95))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )
        }
    }

    private var badgeText: String {
        switch button {
        case .dpadUp: return "↑"
        case .dpadDown: return "↓"
        case .dpadLeft: return "←"
        case .dpadRight: return "→"
        default: return button.rawValue.uppercased()
        }
    }
}

struct ButtonBindingRow: View {
    let button: ButtonID
    @Binding var action: OutputAction?
    @State private var editingURL = false

    var body: some View {
        HStack(spacing: 9) {
            HStack(spacing: 11) {
                ButtonBadge(button: button)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label(button))
                    Text(positionHint(button))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: categoryBinding) {
                ForEach(ActionCategory.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 104)

            valueCell
                .frame(width: 158, alignment: .leading)

            trailingCell
                .frame(width: 84, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var valueCell: some View {
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
        case .keyboard:
            KeyComboField(stroke: keystrokeBinding)
        case .function:
            Picker("", selection: functionBinding) {
                ForEach(FunctionKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
        }
    }

    @ViewBuilder private var trailingCell: some View {
        switch category(of: action) {
        case .keyboard:
            KeyRecorderButton(stroke: keystrokeBinding)
        case .function:
            if case .openURL? = action {
                Button("Edit") { editingURL = true }
                    .popover(isPresented: $editingURL, arrowEdge: .bottom) {
                        URLField(urlString: urlBinding)
                            .frame(width: 260)
                            .padding(12)
                    }
            } else {
                Color.clear.frame(height: 1)
            }
        default:
            Color.clear.frame(height: 1)
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
            get: {
                switch action {
                case .openURL?: return .openURL
                case .keyboardViewer?: return .keyboardViewer
                case .precision?: return .precision
                default: return .sleep
                }
            },
            set: { kind in
                switch kind {
                case .sleep: action = .sleep
                case .keyboardViewer: action = .keyboardViewer
                case .precision: action = .precision
                case .openURL:
                    if case .openURL? = action {} else { action = .openURL("https://www.bilibili.com") }
                }
            }
        )
    }

    private var urlBinding: Binding<String> {
        Binding(
            get: { if case .openURL(let u)? = action { return u }; return "" },
            set: { action = .openURL($0) }
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

    private func positionHint(_ b: ButtonID) -> String {
        switch b {
        case .a: return "Bottom face button (PS: Cross)"
        case .b: return "Right face button (PS: Circle)"
        case .x: return "Left face button (PS: Square)"
        case .y: return "Top face button (PS: Triangle)"
        case .lb: return "Left shoulder button"
        case .rb: return "Right shoulder button"
        case .lt: return "Left trigger, below the shoulder"
        case .rt: return "Right trigger, below the shoulder"
        case .l3: return "Press the left stick down"
        case .r3: return "Press the right stick down"
        case .menu: return "Right small center button (Start / ☰)"
        case .options: return "Left small center button (Select / View)"
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight: return "Directional pad, left side"
        }
    }
}

/// Shows the binding as keycap chips; click to type a combo like
/// "cmd+shift+space" or "F6" and press ⏎. Invalid input reverts.
struct KeyComboField: View {
    @Binding var stroke: KeyStroke
    @State private var text = ""
    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        if editing {
            TextField("", text: $text, prompt: Text("cmd+shift+space"))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onAppear {
                    text = stroke.displayString
                    focused = true
                }
                .onSubmit { commit() }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
        } else {
            HStack(spacing: 3) {
                ForEach(Array(stroke.displayParts.enumerated()), id: \.offset) { _, part in
                    KeyCapChip(label: part)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { editing = true }
        }
    }

    private func commit() {
        if let parsed = KeyStroke.parse(text) { stroke = parsed }
        editing = false
    }
}

struct KeyCapChip: View {
    let label: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .medium))
            .padding(.horizontal, 6)
            .frame(height: 22)
            .frame(minWidth: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.14) : Color(red: 0.94, green: 0.94, blue: 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }
}

/// URL entry; commits on ⏎ or focus loss.
struct URLField: View {
    @Binding var urlString: String
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text("https://"))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onAppear { text = urlString }
            .onChange(of: urlString) { _, newValue in text = newValue }
            .onSubmit { commit() }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
    }

    private func commit() {
        urlString = text.trimmingCharacters(in: .whitespaces)
    }
}

struct KeyRecorderButton: View {
    @Binding var stroke: KeyStroke
    @State private var recording = false
    @State private var monitor: Any?
    @State private var modifierRecorder = ModifierOnlyRecorder()

    var body: some View {
        Button(recording ? "Press key" : "Record") { start() }
            .disabled(recording)
            .onDisappear { cancel() }
    }

    private func start() {
        recording = true
        modifierRecorder = ModifierOnlyRecorder()
        let events: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        monitor = NSEvent.addLocalMonitorForEvents(matching: events) { event in
            switch event.type {
            case .flagsChanged:
                switch modifierRecorder.flagsChanged(keyCode: event.keyCode) {
                case .recording: break
                case .bound(let code):
                    stroke = KeyStroke(keyCode: code)
                    cancel()
                case .abandoned: cancel()
                }
                return event // modifier state must stay consistent for the rest of the UI
            case .keyDown:
                if event.keyCode == 53 { // Esc cancels recording without binding
                    cancel()
                    return nil
                }
                stroke = KeyStroke(keyCode: event.keyCode,
                                   modifiers: modifierFlags(from: event.modifierFlags))
                cancel()
                return nil // swallow the key so it doesn't reach other UI
            default:
                cancel() // any click elsewhere abandons recording
                return event
            }
        }
    }

    private func cancel() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
