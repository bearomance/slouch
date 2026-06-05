import XCTest
@testable import SlouchCore

final class ClickStateTrackerTests: XCTestCase {
    private let interval = 0.5

    func test_firstClick_isState1() {
        var t = ClickStateTracker()
        XCTAssertEqual(t.registerDown(button: .left, x: 100, y: 100, time: 1.0, doubleClickInterval: interval), 1)
    }

    func test_rapidSecondClick_isState2() {
        var t = ClickStateTracker()
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.0, doubleClickInterval: interval)
        XCTAssertEqual(t.registerDown(button: .left, x: 100, y: 100, time: 1.3, doubleClickInterval: interval), 2)
    }

    func test_rapidThirdClick_isState3() {
        var t = ClickStateTracker()
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.0, doubleClickInterval: interval)
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.3, doubleClickInterval: interval)
        XCTAssertEqual(t.registerDown(button: .left, x: 100, y: 100, time: 1.6, doubleClickInterval: interval), 3)
    }

    func test_slowSecondClick_resetsToState1() {
        var t = ClickStateTracker()
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.0, doubleClickInterval: interval)
        XCTAssertEqual(t.registerDown(button: .left, x: 100, y: 100, time: 1.6, doubleClickInterval: interval), 1)
    }

    func test_differentButton_resetsToState1() {
        var t = ClickStateTracker()
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.0, doubleClickInterval: interval)
        XCTAssertEqual(t.registerDown(button: .right, x: 100, y: 100, time: 1.2, doubleClickInterval: interval), 1)
    }

    func test_movedCursor_resetsToState1() {
        var t = ClickStateTracker()
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.0, doubleClickInterval: interval)
        XCTAssertEqual(t.registerDown(button: .left, x: 140, y: 100, time: 1.2, doubleClickInterval: interval), 1)
    }

    func test_clickState_reflectsLastDown_forMouseUp() {
        var t = ClickStateTracker()
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.0, doubleClickInterval: interval)
        _ = t.registerDown(button: .left, x: 100, y: 100, time: 1.3, doubleClickInterval: interval)
        XCTAssertEqual(t.clickState, 2)
    }
}
