import XCTest
@testable import SlouchCore

final class KeyRepeatTests: XCTestCase {
    private let arrow = KeyStroke(keyCode: 126)

    private func makeEngine(_ buttons: [ButtonID: OutputAction]) -> MappingEngine {
        MappingEngine(mapping: Mapping(leftStick: .none, rightStick: .none, buttons: buttons),
                      settings: .default)
    }

    private func repeats(in cmds: [SynthCommand]) -> Int {
        cmds.filter { if case .keyRepeat = $0 { return true }; return false }.count
    }

    func test_heldKeystroke_noRepeatBeforeInitialDelay() {
        let engine = makeEngine([.dpadUp: .keystroke(arrow)])
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.39)
        XCTAssertEqual(repeats(in: cmds), 0)
    }

    func test_heldKeystroke_repeatsAfterInitialDelay() {
        let engine = makeEngine([.dpadUp: .keystroke(arrow)])
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 1.0 / 60)
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.39)
        let cmds = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.02)
        XCTAssertEqual(repeats(in: cmds), 1)
        if case .keyRepeat(let k)? = cmds.first(where: { if case .keyRepeat = $0 { return true }; return false }) {
            XCTAssertEqual(k, arrow)
        }
    }

    func test_repeat_firesAtIntervalAfterDelay() {
        let engine = makeEngine([.dpadUp: .keystroke(arrow)])
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 1.0 / 60)
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.4) // first repeat
        XCTAssertEqual(repeats(in: engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.04)), 0)
        XCTAssertEqual(repeats(in: engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.05)), 1)
        XCTAssertEqual(repeats(in: engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.08)), 1)
    }

    func test_release_stopsRepeating() {
        let engine = makeEngine([.dpadUp: .keystroke(arrow)])
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 1.0 / 60)
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.5)
        _ = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: []), dt: 1.0)
        XCTAssertEqual(repeats(in: cmds), 0)
    }

    func test_rePress_restartsInitialDelay() {
        let engine = makeEngine([.dpadUp: .keystroke(arrow)])
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 1.0 / 60)
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.5)
        _ = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 0.2)
        XCTAssertEqual(repeats(in: cmds), 0)
    }

    func test_standaloneModifier_neverRepeats() {
        let engine = makeEngine([.x: .keystroke(KeyStroke(keyCode: 54))]) // bare R⌘
        _ = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: [.x]), dt: 2.0)
        XCTAssertEqual(repeats(in: cmds), 0)
    }

    func test_mouseClick_neverRepeats() {
        let engine = makeEngine([.b: .mouseClick(.left)])
        _ = engine.process(state: GamepadState(pressed: [.b]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: [.b]), dt: 2.0)
        XCTAssertEqual(repeats(in: cmds), 0)
        XCTAssertEqual(cmds.filter { $0 == .mouseDown(.left) }.count, 0)
    }

    func test_atMostOneRepeatPerTick_evenWithHugeDt() {
        let engine = makeEngine([.dpadUp: .keystroke(arrow)])
        _ = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: [.dpadUp]), dt: 5.0)
        XCTAssertEqual(repeats(in: cmds), 1)
    }
}
