import Foundation

public struct GamepadBattery: Equatable, Sendable {
    public var level: Double // 0...1
    public var isCharging: Bool
    public init(level: Double, isCharging: Bool) {
        self.level = level
        self.isCharging = isCharging
    }
}

/// Abstracts the source of gamepad input so the engine can be driven by real
/// hardware or by a synthetic source in tests.
public protocol GamepadSource: AnyObject {
    var isConnected: Bool { get }
    /// Human-readable name of the connected controller, if known.
    var controllerName: String? { get }
    /// Battery state, if the controller reports one.
    var battery: GamepadBattery? { get }
    /// Current snapshot of sticks + pressed buttons.
    func currentState() -> GamepadState
    /// Called when a controller connects/disconnects.
    var onConnectionChange: ((Bool) -> Void)? { get set }
    /// Tear down and re-establish controller observation (used after wake).
    func rebind()
}

public extension GamepadSource {
    var controllerName: String? { nil }
    var battery: GamepadBattery? { nil }
}
