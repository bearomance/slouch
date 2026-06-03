import Foundation

public final class MappingStore {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("config.json")
    }

    /// Default location: ~/Library/Application Support/Slouch
    public convenience init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Slouch", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.init(directory: base)
    }

    public func load() -> Config {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? Self.decode(data) else {
            return .default
        }
        return config
    }

    public func save(_ config: Config) throws {
        try Self.encode(config).write(to: fileURL, options: .atomic)
    }

    public static func encode(_ config: Config) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(config)
    }

    public static func decode(_ data: Data) throws -> Config {
        try JSONDecoder().decode(Config.self, from: data)
    }
}
