import XCTest
@testable import SlouchCore

final class StandaloneModifierTests: XCTestCase {
    func test_parse_sideSpecificModifierAliases() {
        XCTAssertEqual(KeyStroke.parse("lcmd"), KeyStroke(keyCode: 55))
        XCTAssertEqual(KeyStroke.parse("rcmd"), KeyStroke(keyCode: 54))
        XCTAssertEqual(KeyStroke.parse("lshift"), KeyStroke(keyCode: 56))
        XCTAssertEqual(KeyStroke.parse("rshift"), KeyStroke(keyCode: 60))
        XCTAssertEqual(KeyStroke.parse("lctrl"), KeyStroke(keyCode: 59))
        XCTAssertEqual(KeyStroke.parse("rctrl"), KeyStroke(keyCode: 62))
    }

    func test_displayString_sideSpecificModifiers() {
        XCTAssertEqual(KeyStroke(keyCode: 55).displayString, "L⌘")
        XCTAssertEqual(KeyStroke(keyCode: 54).displayString, "R⌘")
        XCTAssertEqual(KeyStroke(keyCode: 60).displayString, "R⇧")
        XCTAssertEqual(KeyStroke(keyCode: 62).displayString, "R⌃")
    }

    func test_displayString_roundTripsThroughParse() {
        for code: UInt16 in [54, 55, 56, 58, 59, 60, 61, 62] {
            let stroke = KeyStroke(keyCode: code)
            XCTAssertEqual(KeyStroke.parse(stroke.displayString), stroke)
        }
    }

    func test_displayParts_comboSplitsPerKey() {
        let stroke = KeyStroke(keyCode: 17, modifiers: [.command, .shift])
        XCTAssertEqual(stroke.displayParts, ["⇧", "⌘", "T"])
    }

    func test_displayParts_bareModifierIsSingleChip() {
        XCTAssertEqual(KeyStroke(keyCode: 54).displayParts, ["R⌘"])
    }

    func test_displayParts_plainKey() {
        XCTAssertEqual(KeyStroke(keyCode: 49).displayParts, ["Space"])
    }
}

final class ModifierOnlyRecorderTests: XCTestCase {
    func test_pressAndRelease_singleModifier_binds() {
        var r = ModifierOnlyRecorder()
        XCTAssertEqual(r.flagsChanged(keyCode: 54), .recording) // R⌘ down
        XCTAssertEqual(r.flagsChanged(keyCode: 54), .bound(54)) // R⌘ up
    }

    func test_twoModifiersPressed_abandons() {
        var r = ModifierOnlyRecorder()
        XCTAssertEqual(r.flagsChanged(keyCode: 55), .recording) // L⌘ down
        XCTAssertEqual(r.flagsChanged(keyCode: 58), .recording) // L⌥ down
        XCTAssertEqual(r.flagsChanged(keyCode: 58), .recording) // L⌥ up, L⌘ still held
        XCTAssertEqual(r.flagsChanged(keyCode: 55), .abandoned) // L⌘ up
    }

    func test_nonModifierFlagKeys_areIgnored() {
        var r = ModifierOnlyRecorder()
        XCTAssertEqual(r.flagsChanged(keyCode: 57), .recording) // caps lock
        XCTAssertEqual(r.flagsChanged(keyCode: 61), .recording) // R⌥ down
        XCTAssertEqual(r.flagsChanged(keyCode: 61), .bound(61)) // R⌥ up
    }

    func test_sideIsPreserved() {
        var r = ModifierOnlyRecorder()
        _ = r.flagsChanged(keyCode: 60) // R⇧ down
        XCTAssertEqual(r.flagsChanged(keyCode: 60), .bound(60))
    }
}
