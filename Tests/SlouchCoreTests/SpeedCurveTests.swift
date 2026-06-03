import XCTest
@testable import SlouchCore

final class SpeedCurveTests: XCTestCase {
    func test_zeroMagnitude_isZero() {
        XCTAssertEqual(curvedSpeed(magnitude: 0.0), 0.0, accuracy: 1e-9)
    }

    func test_fullMagnitude_isOne() {
        XCTAssertEqual(curvedSpeed(magnitude: 1.0), 1.0, accuracy: 1e-9)
    }

    func test_midMagnitude_isBelowLinear() {
        // exponent 1.5 means 0.5 -> 0.5^1.5 ≈ 0.3536, giving finer low-end control.
        XCTAssertEqual(curvedSpeed(magnitude: 0.5), 0.3535533, accuracy: 1e-5)
    }

    func test_clampsAboveOne() {
        XCTAssertEqual(curvedSpeed(magnitude: 1.4), 1.0, accuracy: 1e-9)
    }
}
