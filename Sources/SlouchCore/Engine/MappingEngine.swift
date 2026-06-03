import Foundation

public final class MappingEngine {
    public var mapping: Mapping
    public var settings: Settings
    private var previouslyPressed: Set<ButtonID> = []

    public init(mapping: Mapping, settings: Settings) {
        self.mapping = mapping
        self.settings = settings
    }

    public func process(state: GamepadState, dt: Double) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        commands.append(contentsOf: buttonCommands(state: state))
        previouslyPressed = state.pressed
        return commands
    }

    private func buttonCommands(state: GamepadState) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        let justPressed = state.pressed.subtracting(previouslyPressed)
        let justReleased = previouslyPressed.subtracting(state.pressed)

        for button in justPressed {
            switch mapping.buttons[button] {
            case .mouseClick(let b): commands.append(.mouseDown(b))
            case .keystroke(let k): commands.append(.keyDown(k))
            case .sleep: commands.append(.sleep)
            case OutputAction.none?, nil: break
            }
        }
        for button in justReleased {
            switch mapping.buttons[button] {
            case .mouseClick(let b): commands.append(.mouseUp(b))
            case .keystroke(let k): commands.append(.keyUp(k))
            case .sleep, OutputAction.none?, nil: break
            }
        }
        return commands
    }
}
