import XCTest
@testable import SlouchCore

final class MappingModelTests: XCTestCase {
    func test_couchDefault_hasExpectedBindings() {
        let m = Mapping.couchDefault
        XCTAssertEqual(m.rightStick, .mouseMove)
        XCTAssertEqual(m.leftStick, .scroll)
        XCTAssertEqual(m.buttons[.a], .mouseClick(.left))
        XCTAssertEqual(m.buttons[.b], .mouseClick(.right))
        XCTAssertEqual(m.buttons[.menu], .sleep)
    }

    func test_config_roundTripsThroughJSON() throws {
        let original = Config.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_openURL_roundTripsThroughJSON() throws {
        let action = OutputAction.openURL("https://www.bilibili.com")
        let data = try JSONEncoder().encode(action)
        XCTAssertEqual(try JSONDecoder().decode(OutputAction.self, from: data), action)
    }

    func test_keystroke_roundTripsWithModifiers() throws {
        let stroke = KeyStroke(keyCode: 49, modifiers: [.command, .shift])
        let action = OutputAction.keystroke(stroke)
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(OutputAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }
}
