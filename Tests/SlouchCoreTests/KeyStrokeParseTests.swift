import XCTest
@testable import SlouchCore

final class KeyStrokeParseTests: XCTestCase {
    func test_parsesPlainKey() {
        XCTAssertEqual(KeyStroke.parse("F6"), KeyStroke(keyCode: 97))
    }

    func test_parsesFullWidthPlus_fromCJKInputMethod() {
        XCTAssertEqual(KeyStroke.parse("cmd＋opt＋f5"),
                       KeyStroke(keyCode: 96, modifiers: [.command, .option]))
    }

    func test_parsesWordModifiers() {
        XCTAssertEqual(KeyStroke.parse("cmd+shift+space"),
                       KeyStroke(keyCode: 49, modifiers: [.command, .shift]))
    }

    func test_parsesSymbolModifiers() {
        XCTAssertEqual(KeyStroke.parse("⇧⌘Space"),
                       KeyStroke(keyCode: 49, modifiers: [.command, .shift]))
    }

    func test_parsesAliases() {
        XCTAssertEqual(KeyStroke.parse("esc"), KeyStroke(keyCode: 53))
        XCTAssertEqual(KeyStroke.parse("enter"), KeyStroke(keyCode: 36))
        XCTAssertEqual(KeyStroke.parse("up"), KeyStroke(keyCode: 126))
    }

    func test_parsesLetterCaseInsensitive() {
        XCTAssertEqual(KeyStroke.parse("a"), KeyStroke(keyCode: 0))
        XCTAssertEqual(KeyStroke.parse("A"), KeyStroke(keyCode: 0))
    }

    func test_rejectsInvalidInput() {
        XCTAssertNil(KeyStroke.parse("notakey"))
        XCTAssertNil(KeyStroke.parse(""))
        XCTAssertNil(KeyStroke.parse("cmd+"))
    }
}
