import XCTest
@testable import SlouchCore

final class PrecisionModeTests: XCTestCase {
    private func makeEngine() -> MappingEngine {
        MappingEngine(
            mapping: Mapping(leftStick: .mouseMove, rightStick: .scroll,
                             buttons: [.lb: .precision, .a: .mouseClick(.left)]),
            settings: .default)
    }

    private func mouseDx(_ cmds: [SynthCommand]) -> Double? {
        for cmd in cmds { if case let .moveMouse(dx, _) = cmd { return dx } }
        return nil
    }

    func test_precisionHeld_slowsCursor_byDefaultFactor() {
        let engine = makeEngine()
        let state = GamepadState(leftStick: StickVector(x: 1, y: 0), pressed: [.lb])
        let normal = makeEngine().process(state: GamepadState(leftStick: StickVector(x: 1, y: 0)), dt: 0.5)
        let slowed = engine.process(state: state, dt: 0.5)
        XCTAssertEqual(mouseDx(slowed)!, mouseDx(normal)! * 0.3, accuracy: 1e-9)
    }

    func test_precisionFactor_isConfigurable() {
        var settings = Settings.default
        settings.precisionFactor = 0.5
        let engine = MappingEngine(
            mapping: Mapping(leftStick: .mouseMove, rightStick: .scroll,
                             buttons: [.lb: .precision]),
            settings: settings)
        let normal = makeEngine().process(state: GamepadState(leftStick: StickVector(x: 1, y: 0)), dt: 0.5)
        let slowed = engine.process(state: GamepadState(leftStick: StickVector(x: 1, y: 0), pressed: [.lb]), dt: 0.5)
        XCTAssertEqual(mouseDx(slowed)!, mouseDx(normal)! * 0.5, accuracy: 1e-9)
    }

    func test_settingsWithoutPrecisionFactor_decodesToDefault() throws {
        let json = #"{"cursorSpeed":1400,"scrollSpeed":30,"deadZone":0.05}"#
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.precisionFactor, 0.3)
    }

    func test_precisionReleased_restoresSpeed() {
        let engine = makeEngine()
        _ = engine.process(state: GamepadState(leftStick: StickVector(x: 1, y: 0), pressed: [.lb]), dt: 0.5)
        let cmds = engine.process(state: GamepadState(leftStick: StickVector(x: 1, y: 0)), dt: 0.5)
        let baseline = makeEngine().process(state: GamepadState(leftStick: StickVector(x: 1, y: 0)), dt: 0.5)
        XCTAssertEqual(mouseDx(cmds)!, mouseDx(baseline)!, accuracy: 1e-9)
    }

    func test_precisionDoesNotAffectScroll() {
        let engine = makeEngine()
        let held = engine.process(state: GamepadState(rightStick: StickVector(x: 0, y: 1), pressed: [.lb]), dt: 0.5)
        let normal = makeEngine().process(state: GamepadState(rightStick: StickVector(x: 0, y: 1)), dt: 0.5)
        func scrollDy(_ cmds: [SynthCommand]) -> Double? {
            for cmd in cmds { if case let .scroll(_, dy) = cmd { return dy } }
            return nil
        }
        XCTAssertEqual(scrollDy(held)!, scrollDy(normal)!, accuracy: 1e-9)
    }

    func test_precisionButton_emitsNothingOnPressAndRelease() {
        let engine = makeEngine()
        let down = engine.process(state: GamepadState(pressed: [.lb]), dt: 1.0 / 60)
        let up = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        XCTAssertTrue(down.isEmpty)
        XCTAssertTrue(up.isEmpty)
    }

    func test_precision_roundTripsThroughJSON() throws {
        let action = OutputAction.precision
        let data = try JSONEncoder().encode(action)
        XCTAssertEqual(try JSONDecoder().decode(OutputAction.self, from: data), action)
    }
}
