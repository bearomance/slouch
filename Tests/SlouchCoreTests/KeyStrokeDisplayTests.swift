import XCTest
@testable import SlouchCore

final class KeyStrokeDisplayTests: XCTestCase {
    func test_voiceHotkey_rendersModifiersThenKey() {
        let stroke = KeyStroke(keyCode: 49, modifiers: [.command, .shift])
        XCTAssertEqual(stroke.displayString, "⇧⌘Space")
    }

    func test_arrowKey_rendersSymbol() {
        XCTAssertEqual(KeyStroke(keyCode: 126).displayString, "↑")
    }

    func test_unknownKey_fallsBackToCode() {
        XCTAssertEqual(KeyStroke(keyCode: 200).displayString, "key 200")
    }

    func test_sideSpecificOption_rendersCompactName() {
        XCTAssertEqual(KeyStroke(keyCode: 61).displayString, "R⌥")
        XCTAssertEqual(KeyStroke(keyCode: 58).displayString, "L⌥")
    }
}
