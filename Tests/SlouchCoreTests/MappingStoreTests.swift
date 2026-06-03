import XCTest
@testable import SlouchCore

final class MappingStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_loadFromEmptyDir_returnsDefault() {
        let store = MappingStore(directory: tempDir())
        XCTAssertEqual(store.load(), Config.default)
    }

    func test_saveThenLoad_roundTrips() throws {
        let dir = tempDir()
        let store = MappingStore(directory: dir)
        var config = Config.default
        config.settings.cursorSpeed = 999
        try store.save(config)

        let reloaded = MappingStore(directory: dir).load()
        XCTAssertEqual(reloaded.settings.cursorSpeed, 999)
        XCTAssertEqual(reloaded, config)
    }
}
