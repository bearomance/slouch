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
