import Foundation

public struct StickVector: Equatable {
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

public struct GamepadState: Equatable {
    public var leftStick: StickVector
    public var rightStick: StickVector
    public var pressed: Set<ButtonID>
    public init(leftStick: StickVector = .zero,
                rightStick: StickVector = .zero,
                pressed: Set<ButtonID> = []) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.pressed = pressed
    }
}
