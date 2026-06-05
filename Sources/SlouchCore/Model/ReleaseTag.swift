import Foundation

/// CI tags releases as "build-<commit count>-<short sha>".
public enum ReleaseTag {
    public static func buildNumber(from tag: String) -> Int? {
        let parts = tag.split(separator: "-")
        guard parts.count == 3, parts[0] == "build" else { return nil }
        return Int(parts[1])
    }
}
