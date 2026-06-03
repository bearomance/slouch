import XCTest
@testable import SlouchCore

final class DeadzoneTests: XCTestCase {
    func test_inputInsideDeadzone_returnsZero() {
        let v = StickVector(x: 0.03, y: 0.0)
        let out = applyRadialDeadzone(v, deadZone: 0.05)
        XCTAssertEqual(out.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(out.y, 0.0, accuracy: 1e-9)
    }
}
