import XCTest
@testable import SlouchCore

final class GyroEngineTests: XCTestCase {
    private let dt = 1.0 / 60

    private func makeEngine(settings: Settings = .default) -> MappingEngine {
        MappingEngine(mapping: Mapping(leftStick: .none, rightStick: .none,
                                       buttons: [.lb: .gyroPointer]),
                      settings: settings)
    }

    private func calibrate(_ engine: MappingEngine) {
        var t = 0.0
        while t < GyroPointer.calibrationWindow + dt {
            _ = engine.process(state: GamepadState(rotationRate: .zero), dt: dt)
            t += dt
        }
    }

    private func moves(in cmds: [SynthCommand]) -> [(dx: Double, dy: Double)] {
        cmds.compactMap { if case .moveMouse(let dx, let dy) = $0 { return (dx, dy) }; return nil }
    }

    private let turning = RotationRate(x: 0, y: 0.5, z: 0)

    func test_heldGyroButton_movesCursor() {
        let engine = makeEngine()
        calibrate(engine)
        let cmds = engine.process(state: GamepadState(pressed: [.lb], rotationRate: turning), dt: dt)
        let move = moves(in: cmds)
        XCTAssertEqual(move.count, 1)
        // 0.5 rad/s yaw → -x radians, converted to degrees × sensitivity (px/°).
        let expected = -0.5 * dt * (180 / Double.pi) * Settings.default.gyroSensitivity
        XCTAssertEqual(move[0].dx, expected, accuracy: 1e-9)
        XCTAssertEqual(move[0].dy, 0, accuracy: 1e-9)
    }

    func test_notHeld_noCursorMotion() {
        let engine = makeEngine()
        calibrate(engine)
        let cmds = engine.process(state: GamepadState(rotationRate: turning), dt: dt)
        XCTAssertTrue(moves(in: cmds).isEmpty)
    }

    func test_noRotationRate_noCursorMotion() {
        let engine = makeEngine()
        calibrate(engine)
        let cmds = engine.process(state: GamepadState(pressed: [.lb]), dt: dt)
        XCTAssertTrue(moves(in: cmds).isEmpty)
    }

    func test_invertX_flipsSign() {
        var inverted = Settings.default
        inverted.gyroInvertX = true
        let engine = makeEngine(settings: inverted)
        calibrate(engine)
        let plain = makeEngine()
        calibrate(plain)
        let a = moves(in: engine.process(state: GamepadState(pressed: [.lb], rotationRate: turning), dt: dt))
        let b = moves(in: plain.process(state: GamepadState(pressed: [.lb], rotationRate: turning), dt: dt))
        XCTAssertEqual(a[0].dx, -b[0].dx, accuracy: 1e-9)
    }

    func test_sensitivity_scalesLinearly() {
        var doubled = Settings.default
        doubled.gyroSensitivity = Settings.default.gyroSensitivity * 2
        let engine = makeEngine(settings: doubled)
        calibrate(engine)
        let plain = makeEngine()
        calibrate(plain)
        let a = moves(in: engine.process(state: GamepadState(pressed: [.lb], rotationRate: turning), dt: dt))
        let b = moves(in: plain.process(state: GamepadState(pressed: [.lb], rotationRate: turning), dt: dt))
        XCTAssertEqual(a[0].dx, 2 * b[0].dx, accuracy: 1e-9)
    }

    func test_settings_roundTripWithGyroFields() throws {
        var config = Config.default
        config.settings.gyroSensitivity = 80
        config.settings.gyroInvertY = true
        config.mapping.buttons[.lb] = .gyroPointer
        let decoded = try MappingStore.decode(MappingStore.encode(config))
        XCTAssertEqual(decoded, config)
    }
}
