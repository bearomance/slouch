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
}

public enum StickRole: String, Codable, Equatable, Sendable {
    case mouseMove, scroll, none
}

public enum OutputAction: Codable, Equatable, Sendable {
    case mouseClick(MouseButton)
    case keystroke(KeyStroke)
    case sleep
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
        symbolString(of: modifiers) + KeyStroke.keyName(for: keyCode)
    }

    private func symbolString(of mods: ModifierFlags) -> String { mods.symbolString }

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
    ]
}

/// What the engine asks the synthesizer to do. `dy` positive = screen-down.
public enum SynthCommand: Equatable, Sendable {
    case moveMouse(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case mouseDown(MouseButton)
    case mouseUp(MouseButton)
    case keyDown(KeyStroke)
    case keyUp(KeyStroke)
    case sleep
}
