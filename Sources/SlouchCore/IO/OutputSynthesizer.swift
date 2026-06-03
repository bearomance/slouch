import Foundation

/// Abstracts emission of OS input events so the engine can be unit-tested.
public protocol OutputSynthesizer: AnyObject {
    func perform(_ command: SynthCommand)
}
