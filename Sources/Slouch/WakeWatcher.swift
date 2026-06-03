import AppKit

/// Re-binds the gamepad after the Mac wakes, so input works immediately
/// without power-cycling the controller. `onWake` is invoked on the main queue.
final class WakeWatcher {
    private let onWake: () -> Void

    init(onWake: @escaping () -> Void) {
        self.onWake = onWake
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(woke),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc func woke() { onWake() }
}
