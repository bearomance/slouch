import Foundation

public struct StickVector: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    public static let zero = StickVector(x: 0, y: 0)
    public var magnitude: Double { (x * x + y * y).squareRoot() }
}

public enum StickID: String, Codable, CaseIterable, Sendable {
    case left, right
}

public enum ButtonID: String, Codable, CaseIterable, Sendable {
    case a, b, x, y
    case lb, rb, lt, rt
    case l3, r3
    case menu, options
    case dpadUp, dpadDown, dpadLeft, dpadRight
}

/// Angular velocity in the controller's frame, radians/sec.
/// x = pitch (tilt up/down), y = yaw (turn left/right), z = roll.
public struct RotationRate: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
    public static let zero = RotationRate(x: 0, y: 0, z: 0)
}

public struct GamepadState: Equatable, Sendable {
    public var leftStick: StickVector
    public var rightStick: StickVector
    public var pressed: Set<ButtonID>
    /// nil when the controller has no gyro or its sensors are off.
    public var rotationRate: RotationRate?
    public init(leftStick: StickVector = .zero,
                rightStick: StickVector = .zero,
                pressed: Set<ButtonID> = [],
                rotationRate: RotationRate? = nil) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.pressed = pressed
        self.rotationRate = rotationRate
    }
}
