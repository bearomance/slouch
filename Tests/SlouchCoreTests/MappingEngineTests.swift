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

    func test_sleepButton_emitsSleepOnPressOnly() {
        let engine = makeEngine()
        let down = engine.process(state: GamepadState(pressed: [.menu]), dt: 1.0 / 60)
        let held = engine.process(state: GamepadState(pressed: [.menu]), dt: 1.0 / 60)
        XCTAssertTrue(down.contains(.sleep))
        XCTAssertFalse(held.contains(.sleep))
    }
}
