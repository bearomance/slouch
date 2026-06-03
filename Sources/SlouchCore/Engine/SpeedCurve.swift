import Foundation

/// Mild fixed acceleration: output = magnitude^exponent, clamped to 0...1.
/// Gives precision at small deflections without a user-facing curve editor.
public let speedCurveExponent: Double = 1.5

public func curvedSpeed(magnitude: Double) -> Double {
    let clamped = min(max(magnitude, 0), 1)
    return Foundation.pow(clamped, speedCurveExponent)
}
