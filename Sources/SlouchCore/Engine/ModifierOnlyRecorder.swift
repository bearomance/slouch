import Foundation

/// Tracks .flagsChanged events while the key recorder is armed so a bare
/// modifier press can be bound. Industry convention (ShortcutRecorder,
/// Enjoyable): commit on release of all modifiers, not on press.
public struct ModifierOnlyRecorder: Sendable {
    public enum Outcome: Equatable, Sendable {
        case recording
        case bound(UInt16)
        case abandoned
    }

    private var held: Set<UInt16> = []
    private var pressed: Set<UInt16> = []

    public init() {}

    public mutating func flagsChanged(keyCode: UInt16) -> Outcome {
        guard KeyStroke.modifierKeyCodes.contains(keyCode) else { return .recording }
        if held.remove(keyCode) == nil {
            held.insert(keyCode)
            pressed.insert(keyCode)
            return .recording
        }
        guard held.isEmpty else { return .recording }
        return pressed.count == 1 ? .bound(keyCode) : .abandoned
    }
}
