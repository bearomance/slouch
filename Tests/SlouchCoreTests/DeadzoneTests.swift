import XCTest
@testable import SlouchCore

final class DeadzoneTests: XCTestCase {
    func test_inputInsideDeadzone_returnsZero() {
        let out = applyRadialDeadzone(StickVector(x: 0.03, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(out.y, 0.0, accuracy: 1e-9)
    }

    func test_fullDeflection_staysFull() {
        let out = applyRadialDeadzone(StickVector(x: 1.0, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(out.y, 0.0, accuracy: 1e-9)
    }

    func test_justAboveDeadzone_rescalesFromZero() {
        // magnitude just above 0.05 should map to just above 0, not jump.
        let out = applyRadialDeadzone(StickVector(x: 0.05000001, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 0.0, accuracy: 1e-4)
    }

    func test_midRange_rescaledLinearly() {
        // mag 0.525, dz 0.05 -> (0.525-0.05)/(1-0.05) = 0.5
        let out = applyRadialDeadzone(StickVector(x: 0.525, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 0.5, accuracy: 1e-6)
    }

    func test_directionPreserved_onDiagonal() {
        let out = applyRadialDeadzone(StickVector(x: 0.6, y: 0.8), deadZone: 0.0)
        XCTAssertEqual(out.x / out.y, 0.6 / 0.8, accuracy: 1e-6)
    }

    func test_deadZoneAtOrAboveOne_returnsZeroOrFinite() {
        let out = applyRadialDeadzone(StickVector(x: 1, y: 0), deadZone: 1.0)
        XCTAssertTrue(out.x.isFinite)
        XCTAssertTrue(out.y.isFinite)
    }
}
