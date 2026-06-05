import XCTest
@testable import SlouchCore

final class ReleaseTagTests: XCTestCase {
    func test_parsesBuildNumberFromTag() {
        XCTAssertEqual(ReleaseTag.buildNumber(from: "build-78-2122669"), 78)
        XCTAssertEqual(ReleaseTag.buildNumber(from: "build-5-abc1234"), 5)
    }

    func test_rejectsForeignTags() {
        XCTAssertNil(ReleaseTag.buildNumber(from: "latest"))
        XCTAssertNil(ReleaseTag.buildNumber(from: "v1.0.0"))
        XCTAssertNil(ReleaseTag.buildNumber(from: "build-abc-123"))
        XCTAssertNil(ReleaseTag.buildNumber(from: ""))
    }

    func test_settingsWithoutCheckForUpdates_decodesToTrue() throws {
        let json = #"{"cursorSpeed":1400,"scrollSpeed":30,"deadZone":0.05}"#
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        XCTAssertTrue(decoded.checkForUpdates)
    }
}
