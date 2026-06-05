import AppKit
import SlouchCore

struct AvailableUpdate: Equatable {
    let build: Int
    let zipURL: URL
}

enum SelfUpdater {
    static let repoSlug = "bearomance/slouch"

    static var currentBuild: Int? {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap(Int.init)
    }

    /// Returns a newer build from the latest GitHub release, or nil.
    static func checkForUpdate() async -> AvailableUpdate? {
        struct Release: Decodable {
            struct Asset: Decodable {
                let name: String
                let browser_download_url: URL
            }
            let tag_name: String
            let assets: [Asset]
        }
        guard let current = currentBuild,
              let url = URL(string: "https://api.github.com/repos/\(repoSlug)/releases/latest"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let release = try? JSONDecoder().decode(Release.self, from: data),
              let build = ReleaseTag.buildNumber(from: release.tag_name), build > current,
              let zip = release.assets.first(where: { $0.name == "Slouch.app.zip" })
        else { return nil }
        return AvailableUpdate(build: build, zipURL: zip.browser_download_url)
    }

    /// Downloads the zip, swaps the running bundle in place, and relaunches.
    static func install(_ update: AvailableUpdate) async throws {
        let (zipFile, _) = try await URLSession.shared.download(from: update.zipURL)
        let staging = zipFile.deletingLastPathComponent()
            .appendingPathComponent("slouch-update-\(update.build)")
        try? FileManager.default.removeItem(at: staging)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-xk", zipFile.path, staging.path]
        try unzip.run()
        unzip.waitUntilExit()
        let newApp = staging.appendingPathComponent("Slouch.app")
        guard unzip.terminationStatus == 0,
              FileManager.default.fileExists(atPath: newApp.appendingPathComponent("Contents/MacOS/Slouch").path)
        else { throw CocoaError(.fileReadCorruptFile) }

        // Swap the bundle we are running from; the running binary stays alive
        // on the old inodes until relaunch.
        let target = Bundle.main.bundleURL
        try FileManager.default.removeItem(at: target)
        try FileManager.default.moveItem(at: newApp, to: target)

        relaunch(target)
    }

    private static func relaunch(_ app: URL) {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "sleep 1; /usr/bin/open \"\(app.path)\""]
        try? shell.run()
        NSApp.terminate(nil)
    }
}
