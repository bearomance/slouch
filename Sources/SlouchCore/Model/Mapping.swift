import Foundation

public struct Mapping: Codable, Equatable, Sendable {
    public var leftStick: StickRole
    public var rightStick: StickRole
    public var buttons: [ButtonID: OutputAction]

    public init(leftStick: StickRole, rightStick: StickRole, buttons: [ButtonID: OutputAction]) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.buttons = buttons
    }

    public static var couchDefault: Mapping {
        Mapping(
            leftStick: .scroll,
            rightStick: .mouseMove,
            buttons: [
                .a: .mouseClick(.left),
                .b: .mouseClick(.right),
                // Y triggers the user's voice-input app; default Cmd+Shift+Space.
                .y: .keystroke(KeyStroke(keyCode: 49, modifiers: [.command, .shift])),
                .menu: .sleep,
                .dpadUp: .keystroke(KeyStroke(keyCode: 126)),
                .dpadDown: .keystroke(KeyStroke(keyCode: 125)),
                .dpadLeft: .keystroke(KeyStroke(keyCode: 123)),
                .dpadRight: .keystroke(KeyStroke(keyCode: 124)),
            ]
        )
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var cursorSpeed: Double   // px/sec at full deflection
    public var scrollSpeed: Double   // lines/sec at full deflection
    public var deadZone: Double      // 0...0.5

    public init(cursorSpeed: Double = 1400, scrollSpeed: Double = 30, deadZone: Double = 0.05) {
        self.cursorSpeed = cursorSpeed
        self.scrollSpeed = scrollSpeed
        self.deadZone = deadZone
    }

    public static let `default` = Settings()
}

public struct Config: Codable, Equatable, Sendable {
    public var mapping: Mapping
    public var settings: Settings
    public init(mapping: Mapping, settings: Settings) {
        self.mapping = mapping
        self.settings = settings
    }
    public static let `default` = Config(mapping: .couchDefault, settings: .default)
}
