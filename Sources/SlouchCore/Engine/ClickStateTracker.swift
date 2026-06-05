import Foundation

/// Computes the CGEvent click state (NSEvent.clickCount) for synthesized
/// clicks — without it macOS never coalesces rapid clicks into a double-click.
public struct ClickStateTracker: Sendable {
    private var lastButton: MouseButton?
    private var lastTime = -Double.infinity
    private var lastX = 0.0
    private var lastY = 0.0
    public private(set) var clickState = 1

    private static let movementTolerance = 5.0

    public init() {}

    public mutating func registerDown(button: MouseButton, x: Double, y: Double,
                                      time: Double, doubleClickInterval: Double) -> Int {
        let continues = button == lastButton
            && time - lastTime <= doubleClickInterval
            && abs(x - lastX) <= Self.movementTolerance
            && abs(y - lastY) <= Self.movementTolerance
        clickState = continues ? clickState + 1 : 1
        lastButton = button
        lastTime = time
        lastX = x
        lastY = y
        return clickState
    }
}
