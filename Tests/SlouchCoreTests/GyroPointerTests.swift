import XCTest
@testable import SlouchCore

final class GyroPointerTests: XCTestCase {
    private let dt = 1.0 / 60

    private func calibrated(_ gyro: GyroPointer, bias: RotationRate = .zero) {
        var t = 0.0
        while t < GyroPointer.calibrationWindow + dt {
            _ = gyro.process(rate: bias, dt: dt)
            t += dt
        }
    }

    func test_duringCalibration_outputsZero() {
        let gyro = GyroPointer()
        let out = gyro.process(rate: RotationRate(x: 1, y: 1, z: 0), dt: dt)
        XCTAssertEqual(out.dx, 0)
        XCTAssertEqual(out.dy, 0)
    }

    func test_calibration_removesConstantBias() {
        let gyro = GyroPointer()
        let bias = RotationRate(x: 0.01, y: -0.012, z: 0.005)
        calibrated(gyro, bias: bias)
        let out = gyro.process(rate: bias, dt: dt)
        XCTAssertEqual(out.dx, 0)
        XCTAssertEqual(out.dy, 0)
    }

    func test_fastMotion_passesThroughUnscaled() {
        let gyro = GyroPointer()
        calibrated(gyro)
        // 0.5 rad/s yaw, well above the tightening threshold.
        let out = gyro.process(rate: RotationRate(x: 0, y: 0.5, z: 0), dt: dt)
        XCTAssertEqual(out.dx, -0.5 * dt, accuracy: 1e-9) // turn right = -yaw = +x
        XCTAssertEqual(out.dy, 0, accuracy: 1e-9)
    }

    func test_pitch_drivesY() {
        let gyro = GyroPointer()
        calibrated(gyro)
        let out = gyro.process(rate: RotationRate(x: 0.5, y: 0, z: 0), dt: dt)
        XCTAssertEqual(out.dy, -0.5 * dt, accuracy: 1e-9) // tilt up = cursor up (negative dy)
        XCTAssertEqual(out.dx, 0, accuracy: 1e-9)
    }

    func test_smallMotion_isTightened() {
        let gyro = GyroPointer()
        calibrated(gyro)
        let rate = GyroPointer.tighteningThreshold / 2
        let out = gyro.process(rate: RotationRate(x: 0, y: rate, z: 0), dt: dt)
        XCTAssertEqual(abs(out.dx), rate * dt / 2, accuracy: 1e-9) // scaled by mag/threshold = 0.5
    }

    func test_stillness_producesNoOutput() {
        let gyro = GyroPointer()
        calibrated(gyro)
        let out = gyro.process(rate: RotationRate(x: GyroPointer.stillThreshold / 2, y: 0, z: 0), dt: dt)
        XCTAssertEqual(out.dx, 0)
        XCTAssertEqual(out.dy, 0)
    }

    func test_slowDrift_isAbsorbedIntoBias() {
        let gyro = GyroPointer()
        calibrated(gyro)
        // Feed a constant sub-stillness drift for a while; bias should absorb
        // it so a subsequent fast motion isn't offset by the drift.
        let drift = RotationRate(x: 0, y: GyroPointer.stillThreshold * 0.8, z: 0)
        for _ in 0..<(60 * 30) { _ = gyro.process(rate: drift, dt: dt) }
        let out = gyro.process(rate: RotationRate(x: 0, y: drift.y + 0.5, z: 0), dt: dt)
        XCTAssertEqual(out.dx, -0.5 * dt, accuracy: 0.001 * dt)
    }

    func test_reset_restartsCalibration() {
        let gyro = GyroPointer()
        calibrated(gyro)
        gyro.reset()
        let out = gyro.process(rate: RotationRate(x: 0, y: 0.5, z: 0), dt: dt)
        XCTAssertEqual(out.dx, 0)
        XCTAssertEqual(out.dy, 0)
    }
}
