import XCTest
@testable import SlouchCore

final class MappingEngineTests: XCTestCase {
    private func makeEngine() -> MappingEngine {
        MappingEngine(mapping: .couchDefault, settings: .default)
    }

    func test_buttonPress_emitsMouseDownOnce() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        XCTAssertTrue(cmds.contains(.mouseDown(.left)))
    }

    func test_buttonHeld_doesNotRepeatMouseDown() {
        let engine = makeEngine()
        _ = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        XCTAssertFalse(cmds.contains(.mouseDown(.left)))
    }

    func test_buttonRelease_emitsMouseUp() {
        let engine = makeEngine()
        _ = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        XCTAssertTrue(cmds.contains(.mouseUp(.left)))
    }

    func test_keystrokeButton_emitsKeyDownThenKeyUp() {
        let engine = makeEngine()
        let down = engine.process(state: GamepadState(pressed: [.y]), dt: 1.0 / 60)
        let up = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        let stroke = KeyStroke(keyCode: 49, modifiers: [.command, .shift])
        XCTAssertTrue(down.contains(.keyDown(stroke)))
        XCTAssertTrue(up.contains(.keyUp(stroke)))
    }

    func test_openURLButton_emitsOnPressOnly() {
        var mapping = Mapping.couchDefault
        mapping.buttons[.x] = .openURL("https://www.bilibili.com")
        let engine = MappingEngine(mapping: mapping, settings: .default)
        let down = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        let held = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        XCTAssertTrue(down.contains(.openURL("https://www.bilibili.com")))
        XCTAssertFalse(held.contains(.openURL("https://www.bilibili.com")))
    }

    func test_keyboardViewerButton_emitsOnPressOnly() {
        var mapping = Mapping.couchDefault
        mapping.buttons[.x] = .keyboardViewer
        let engine = MappingEngine(mapping: mapping, settings: .default)
        let down = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        let held = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        let up = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        XCTAssertTrue(down.contains(.keyboardViewer))
        XCTAssertFalse(held.contains(.keyboardViewer))
        XCTAssertFalse(up.contains(.keyboardViewer))
    }

    func test_sleepButton_emitsSleepOnReleaseOnly() {
        // On press the system would sleep and the button-release HID report
        // would immediately wake it again — so sleep fires on release.
        let engine = makeEngine()
        let down = engine.process(state: GamepadState(pressed: [.menu]), dt: 1.0 / 60)
        let held = engine.process(state: GamepadState(pressed: [.menu]), dt: 1.0 / 60)
        let up = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        XCTAssertFalse(down.contains(.sleep))
        XCTAssertFalse(held.contains(.sleep))
        XCTAssertTrue(up.contains(.sleep))
    }

    func test_rightStickFullRight_movesCursorRight() {
        let engine = makeEngine()
        let dt = 0.5
        let cmds = engine.process(state: GamepadState(rightStick: StickVector(x: 1, y: 0)), dt: dt)
        // speed at full = cursorSpeed (1400) * curvedSpeed(1)=1 * dt(0.5) = 700
        guard case let .moveMouse(dx, dy)? = cmds.first(where: { if case .moveMouse = $0 { return true }; return false }) else {
            return XCTFail("expected moveMouse")
        }
        XCTAssertEqual(dx, 700, accuracy: 1e-6)
        XCTAssertEqual(dy, 0, accuracy: 1e-6)
    }

    func test_rightStickUp_movesCursorUp_negativeDy() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(rightStick: StickVector(x: 0, y: 1)), dt: 0.5)
        guard case let .moveMouse(_, dy)? = cmds.first(where: { if case .moveMouse = $0 { return true }; return false }) else {
            return XCTFail("expected moveMouse")
        }
        XCTAssertLessThan(dy, 0)
    }

    func test_rightStickInsideDeadzone_emitsNoMove() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(rightStick: StickVector(x: 0.02, y: 0)), dt: 0.5)
        XCTAssertFalse(cmds.contains { if case .moveMouse = $0 { return true }; return false })
    }

    func test_leftStickDown_scrolls() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(leftStick: StickVector(x: 0, y: -1)), dt: 0.5)
        XCTAssertTrue(cmds.contains { if case .scroll = $0 { return true }; return false })
    }
}
