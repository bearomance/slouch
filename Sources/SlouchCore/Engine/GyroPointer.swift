import Foundation

/// Turns angular velocity into cursor deltas (radians; the engine applies
/// sensitivity). Gyromouse/JoyShockMapper lineage: bias calibration on
/// reset, stillness gate with slow drift absorption, tightening of small
/// motions, fast motion passed through unfiltered.
public final class GyroPointer {
    /// Seconds of samples averaged into the zero bias after reset.
    public static let calibrationWindow = 1.0
    /// Below this magnitude the pad counts as still: no output, bias tracks. ~1°/s.
    public static let stillThreshold = 0.0175
    /// Below this, output scales linearly toward zero (hands jitter). ~5°/s.
    public static let tighteningThreshold = 0.0873
    private static let driftAlphaPerSecond = 0.5

    private var bias = RotationRate.zero
    private var calibrating = true
    private var elapsed = 0.0
    private var sum = RotationRate.zero

    public init() {}

    public func reset() {
        calibrating = true
        elapsed = 0
        sum = .zero
        bias = .zero
    }

    /// Feed every tick. Returns radians of cursor travel this tick:
    /// turn right → +dx, tilt up → -dy (screen y grows downward).
    public func process(rate: RotationRate, dt: Double) -> (dx: Double, dy: Double) {
        if calibrating {
            sum.x += rate.x * dt
            sum.y += rate.y * dt
            sum.z += rate.z * dt
            elapsed += dt
            if elapsed >= Self.calibrationWindow {
                bias = RotationRate(x: sum.x / elapsed, y: sum.y / elapsed, z: sum.z / elapsed)
                calibrating = false
            }
            return (0, 0)
        }

        let rx = rate.x - bias.x
        let ry = rate.y - bias.y
        let rz = rate.z - bias.z
        let magnitude = (rx * rx + ry * ry + rz * rz).squareRoot()
        if magnitude < Self.stillThreshold {
            let alpha = min(1, Self.driftAlphaPerSecond * dt)
            bias.x += (rate.x - bias.x) * alpha
            bias.y += (rate.y - bias.y) * alpha
            bias.z += (rate.z - bias.z) * alpha
            return (0, 0)
        }

        var x = -ry
        var y = -rx
        let planar = (x * x + y * y).squareRoot()
        if planar > 0, planar < Self.tighteningThreshold {
            let scale = planar / Self.tighteningThreshold
            x *= scale
            y *= scale
        }
        return (x * dt, y * dt)
    }
}
