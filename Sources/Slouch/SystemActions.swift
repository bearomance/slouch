import Foundation

enum SystemActions {
    /// Sleeps the Mac without admin rights.
    static func sleep() {
        let script = "tell application \"System Events\" to sleep"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }
}
