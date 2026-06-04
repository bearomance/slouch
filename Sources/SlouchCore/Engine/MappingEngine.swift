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
        commands.append(contentsOf: stickCommands(state: state, dt: dt))
        commands.append(contentsOf: buttonCommands(state: state))
        previouslyPressed = state.pressed
        return commands
    }

    private func stickCommands(state: GamepadState, dt: Double) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        commands.append(contentsOf: stickCommand(role: mapping.leftStick, raw: state.leftStick, dt: dt))
        commands.append(contentsOf: stickCommand(role: mapping.rightStick, raw: state.rightStick, dt: dt))
        return commands
    }

    private func stickCommand(role: StickRole, raw: StickVector, dt: Double) -> [SynthCommand] {
        let v = applyRadialDeadzone(raw, deadZone: settings.deadZone)
        let mag = v.magnitude
        guard mag > 0 else { return [] }
        let unitX = v.x / mag
        let unitY = v.y / mag
        let speed = curvedSpeed(magnitude: mag)
        switch role {
        case .mouseMove:
            let s = speed * settings.cursorSpeed * dt
            return [.moveMouse(dx: unitX * s, dy: -unitY * s)]
        case .scroll:
            let s = speed * settings.scrollSpeed * dt
            let direction: Double = settings.invertScroll ? 1 : -1
            return [.scroll(dx: unitX * s, dy: direction * unitY * s)]
        case .none:
            return []
        }
    }

    private func buttonCommands(state: GamepadState) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        let justPressed = state.pressed.subtracting(previouslyPressed)
        let justReleased = previouslyPressed.subtracting(state.pressed)

        for button in justPressed {
            switch mapping.buttons[button] {
            case .mouseClick(let b): commands.append(.mouseDown(b))
            case .keystroke(let k): commands.append(.keyDown(k))
            case .openURL(let url): commands.append(.openURL(url))
            case .keyboardViewer: commands.append(.keyboardViewer)
            case .sleep, OutputAction.none?, nil: break
            }
        }
        for button in justReleased {
            switch mapping.buttons[button] {
            case .mouseClick(let b): commands.append(.mouseUp(b))
            case .keystroke(let k): commands.append(.keyUp(k))
            // Sleep fires on release: triggering on press lets the release
            // HID report wake the Mac right back up.
            case .sleep: commands.append(.sleep)
            case .openURL, .keyboardViewer, OutputAction.none?, nil: break
            }
        }
        return commands
    }
}
