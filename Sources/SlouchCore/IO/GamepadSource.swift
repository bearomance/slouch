import Foundation

/// Abstracts the source of gamepad input so the engine can be driven by real
/// hardware or by a synthetic source in tests.
public protocol GamepadSource: AnyObject {
    var isConnected: Bool { get }
    /// Human-readable name of the connected controller, if known.
    var controllerName: String? { get }
    /// Current snapshot of sticks + pressed buttons.
    func currentState() -> GamepadState
    /// Called when a controller connects/disconnects.
    var onConnectionChange: ((Bool) -> Void)? { get set }
    /// Tear down and re-establish controller observation (used after wake).
    func rebind()
}

public extension GamepadSource {
    var controllerName: String? { nil }
}
