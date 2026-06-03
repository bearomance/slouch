import Foundation

/// Radial dead zone: ignores combined X/Y magnitude below `deadZone`, then
/// rescales so output rises smoothly from 0 at the boundary to 1 at full push.
public func applyRadialDeadzone(_ v: StickVector, deadZone: Double) -> StickVector {
    let dz = min(max(deadZone, 0), 0.99)
    let mag = v.magnitude
    guard mag > dz, mag > 0 else { return .zero }
    let rescaled = (mag - dz) / (1 - dz)
    let scale = rescaled / mag
    return StickVector(x: v.x * scale, y: v.y * scale)
}
