import XCTest
@testable import SlouchCore

final class KeyStrokeFnFlagTests: XCTestCase {
    func test_functionKeys_carryFnFlag() {
        XCTAssertTrue(KeyStroke(keyCode: 96).needsFnFlag)   // F5
        XCTAssertTrue(KeyStroke(keyCode: 122).needsFnFlag)  // F1
        XCTAssertTrue(KeyStroke(keyCode: 111).needsFnFlag)  // F12
    }

    func test_navigationBlockKeys_carryFnFlag() {
        XCTAssertTrue(KeyStroke(keyCode: 126).needsFnFlag)  // up arrow
        XCTAssertTrue(KeyStroke(keyCode: 115).needsFnFlag)  // home
        XCTAssertTrue(KeyStroke(keyCode: 121).needsFnFlag)  // page down
        XCTAssertTrue(KeyStroke(keyCode: 117).needsFnFlag)  // forward delete
    }

    func test_ordinaryKeys_doNotCarryFnFlag() {
        XCTAssertFalse(KeyStroke(keyCode: 0).needsFnFlag)   // a
        XCTAssertFalse(KeyStroke(keyCode: 36).needsFnFlag)  // return
        XCTAssertFalse(KeyStroke(keyCode: 49).needsFnFlag)  // space
        XCTAssertFalse(KeyStroke(keyCode: 51).needsFnFlag)  // delete
    }
}
