import Foundation

public enum MouseButton: String, Codable, Equatable, Sendable {
    case left, right, middle
}

public struct ModifierFlags: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = ModifierFlags(rawValue: 1 << 0)
    public static let shift   = ModifierFlags(rawValue: 1 << 1)
    public static let option  = ModifierFlags(rawValue: 1 << 2)
    public static let control = ModifierFlags(rawValue: 1 << 3)
}

public struct KeyStroke: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: ModifierFlags
    public init(keyCode: UInt16, modifiers: ModifierFlags = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Physical presses of function-block keys carry the Fn (secondary-fn)
    // flag; system symbolic hotkeys like ⌥⌘F5 only match when it's present.
    public var needsFnFlag: Bool { Self.fnFlaggedKeyCodes.contains(keyCode) }

    /// The eight side-specific modifier keys, bindable standalone.
    public static let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]

    private static let fnFlaggedKeyCodes: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, // F1–F12
        105, 107, 113, 106, 64, 79, 80, 90,                     // F13–F20
        114, 115, 116, 117, 119, 121,                           // help, home, pgup, fwd-delete, end, pgdn
        123, 124, 125, 126,                                     // arrows
    ]
}

public enum StickRole: String, Codable, Equatable, Sendable {
    case mouseMove, scroll, none
}

/// The Mac's media keys — not regular key codes; synthesized as
/// NX_SYSDEFINED system events.
public enum MediaKey: String, Codable, CaseIterable, Equatable, Sendable {
    case playPause, nextTrack, previousTrack, volumeUp, volumeDown, mute

    /// NX_KEYTYPE_* from IOKit's ev_keymap.h.
    public var nxKeyCode: Int32 {
        switch self {
        case .playPause: return 16
        case .nextTrack: return 17
        case .previousTrack: return 18
        case .volumeUp: return 0
        case .volumeDown: return 1
        case .mute: return 7
        }
    }

    /// Volume keys repeat while held, like on a real keyboard. Mute toggles
    /// and play/next/previous have no hold semantics, so they must not.
    public var repeats: Bool { self == .volumeUp || self == .volumeDown }
}

public enum OutputAction: Codable, Equatable, Sendable {
    case mouseClick(MouseButton)
    case keystroke(KeyStroke)
    case mediaKey(MediaKey)
    case openURL(String)
    case sleep
    case keyboardViewer
    case precision // hold to slow the cursor for small targets
    case none
}

public extension ModifierFlags {
    /// macOS-convention order: ⌃⌥⇧⌘.
    var symbolString: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

public extension KeyStroke {
    var displayString: String {
        modifiers.symbolString + KeyStroke.keyName(for: keyCode)
    }

    /// One element per key, for keycap-style rendering: ["⇧", "⌘", "T"].
    var displayParts: [String] {
        modifiers.symbolString.map(String.init) + [KeyStroke.keyName(for: keyCode)]
    }

    static func keyName(for code: UInt16) -> String {
        knownKeyNames[code] ?? "key \(code)"
    }

    private static let knownKeyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\",
        43: ",", 44: "/", 47: ".", 50: "`",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        // Side-specific modifiers, bindable standalone (e.g. hold-to-talk).
        58: "L⌥", 61: "R⌥",
        55: "L⌘", 54: "R⌘",
        56: "L⇧", 60: "R⇧",
        59: "L⌃", 62: "R⌃",
    ]

    /// Parses a typed key combo like "F6", "cmd+shift+space", or "⇧⌘Space".
    /// Returns nil if no key (or an unknown key) is present.
    static func parse(_ text: String) -> KeyStroke? {
        var mods: ModifierFlags = []
        var rest = Substring(text.trimmingCharacters(in: .whitespaces))

        symbols: while let c = rest.first {
            switch c {
            case "⌃": mods.insert(.control); rest.removeFirst()
            case "⌥": mods.insert(.option); rest.removeFirst()
            case "⇧": mods.insert(.shift); rest.removeFirst()
            case "⌘": mods.insert(.command); rest.removeFirst()
            default: break symbols
            }
        }

        var keyToken: String?
        // "＋" is what CJK input methods produce for plus.
        for token in rest.split(whereSeparator: { $0 == "+" || $0 == "＋" || $0 == " " }) {
            switch token.lowercased() {
            case "cmd", "command": mods.insert(.command)
            case "shift": mods.insert(.shift)
            case "opt", "option", "alt": mods.insert(.option)
            case "ctrl", "control": mods.insert(.control)
            default:
                guard keyToken == nil else { return nil }
                keyToken = String(token)
            }
        }
        guard let keyToken, let code = nameToCode[keyToken.lowercased()] else { return nil }
        return KeyStroke(keyCode: code, modifiers: mods)
    }

    private static let nameToCode: [String: UInt16] = {
        var map: [String: UInt16] = [:]
        for (code, name) in knownKeyNames { map[name.lowercased()] = code }
        let aliases: [String: UInt16] = [
            "space": 49, "esc": 53, "escape": 53, "enter": 36, "return": 36,
            "tab": 48, "delete": 51, "backspace": 51,
            "up": 126, "down": 125, "left": 123, "right": 124,
            "lopt": 58, "lalt": 58, "leftoption": 58,
            "ropt": 61, "ralt": 61, "rightoption": 61,
            "lcmd": 55, "leftcommand": 55, "rcmd": 54, "rightcommand": 54,
            "lshift": 56, "leftshift": 56, "rshift": 60, "rightshift": 60,
            "lctrl": 59, "leftcontrol": 59, "rctrl": 62, "rightcontrol": 62,
        ]
        map.merge(aliases) { current, _ in current }
        return map
    }()
}

/// What the engine asks the synthesizer to do. `dy` positive = screen-down.
public enum SynthCommand: Equatable, Sendable {
    case moveMouse(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case mouseDown(MouseButton)
    case mouseUp(MouseButton)
    case keyDown(KeyStroke)
    case keyUp(KeyStroke)
    case keyRepeat(KeyStroke)
    case mediaKey(MediaKey) // synthesizer posts a complete down+up pair
    case openURL(String)
    case sleep
    case keyboardViewer
}
