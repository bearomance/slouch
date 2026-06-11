import XCTest
@testable import SlouchCore

final class MediaKeyTests: XCTestCase {
    private func makeEngine(_ buttons: [ButtonID: OutputAction]) -> MappingEngine {
        MappingEngine(mapping: Mapping(leftStick: .none, rightStick: .none, buttons: buttons),
                      settings: .default)
    }

    private func mediaKeys(in cmds: [SynthCommand]) -> [MediaKey] {
        cmds.compactMap { if case .mediaKey(let k) = $0 { return k }; return nil }
    }

    func test_press_firesOnce() {
        let engine = makeEngine([.x: .mediaKey(.playPause)])
        let cmds = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        XCTAssertEqual(mediaKeys(in: cmds), [.playPause])
    }

    func test_release_firesNothing() {
        let engine = makeEngine([.x: .mediaKey(.nextTrack)])
        _ = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        XCTAssertEqual(mediaKeys(in: cmds), [])
    }

    func test_heldVolume_repeatsOnTheRepeatClock() {
        let engine = makeEngine([.rb: .mediaKey(.volumeUp)])
        _ = engine.process(state: GamepadState(pressed: [.rb]), dt: 1.0 / 60)
        XCTAssertEqual(mediaKeys(in: engine.process(state: GamepadState(pressed: [.rb]), dt: 0.39)), [])
        XCTAssertEqual(mediaKeys(in: engine.process(state: GamepadState(pressed: [.rb]), dt: 0.02)), [.volumeUp])
        XCTAssertEqual(mediaKeys(in: engine.process(state: GamepadState(pressed: [.rb]), dt: 0.08)), [.volumeUp])
    }

    func test_heldPlayPause_neverRepeats() {
        let engine = makeEngine([.x: .mediaKey(.playPause)])
        _ = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        XCTAssertEqual(mediaKeys(in: engine.process(state: GamepadState(pressed: [.x]), dt: 2.0)), [])
    }

    func test_heldMute_neverRepeats() {
        let engine = makeEngine([.x: .mediaKey(.mute)])
        _ = engine.process(state: GamepadState(pressed: [.x]), dt: 1.0 / 60)
        XCTAssertEqual(mediaKeys(in: engine.process(state: GamepadState(pressed: [.x]), dt: 2.0)), [])
    }

    func test_config_roundTripsWithMediaKeyBinding() throws {
        var config = Config.default
        config.mapping.buttons[.y] = .mediaKey(.nextTrack)
        let decoded = try MappingStore.decode(MappingStore.encode(config))
        XCTAssertEqual(decoded, config)
    }
}
