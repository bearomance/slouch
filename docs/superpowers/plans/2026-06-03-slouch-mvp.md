# Slouch MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu-bar app that turns a game controller into a Mac control device (mouse + keyboard mapping + sleep), with reliable input recovery after the Mac wakes from sleep.

**Architecture:** A Swift Package with a platform-light, fully unit-tested `SlouchCore` library (input model, mapping translation, dead-zone/speed math, persistence) sitting behind `GamepadSource` and `OutputSynthesizer` protocols, plus a thin `Slouch` SwiftUI executable target that supplies the concrete GameController and CGEvent implementations and wires up the menu-bar UI and wake recovery.

**Tech Stack:** Swift 5.9+ / Swift 6 toolchain, SwiftPM, SwiftUI (`MenuBarExtra`), GameController framework, Core Graphics (`CGEvent`), AppKit (`NSWorkspace`), XCTest. **macOS 14+** (raised from the spec's macOS 13 because `SettingsLink` is macOS 14+; update README's "macOS 13" line to match when implementing).

---

## File Structure

```
Package.swift
Sources/
  SlouchCore/
    Model/
      Inputs.swift            # StickID, ButtonID, StickVector, GamepadState
      Outputs.swift           # MouseButton, ModifierFlags, KeyStroke, OutputAction, StickRole, SynthCommand
      Mapping.swift           # Mapping (+ couchDefault), Settings, Config
    Engine/
      Deadzone.swift          # radial dead-zone (pure)
      SpeedCurve.swift        # stick magnitude -> speed (pure)
      MappingEngine.swift     # GamepadState (+dt) -> [SynthCommand]
    IO/
      GamepadSource.swift     # protocol + GamepadObserver
      OutputSynthesizer.swift # protocol
    Store/
      MappingStore.swift      # Codable JSON persistence
  Slouch/
    SlouchApp.swift           # @main, MenuBarExtra, .accessory activation
    AppModel.swift            # wires source + engine + synth + wake + permissions; runloop
    GCGamepadSource.swift     # concrete GamepadSource (GameController)
    CGOutputSynthesizer.swift # concrete OutputSynthesizer (CGEvent)
    WakeWatcher.swift         # NSWorkspace wake -> rebind
    SystemActions.swift       # sleep
    PermissionsManager.swift  # AXIsProcessTrusted + open settings
    SettingsView.swift        # sliders + mapping editor
Tests/
  SlouchCoreTests/
    DeadzoneTests.swift
    SpeedCurveTests.swift
    MappingModelTests.swift
    MappingEngineTests.swift
    MappingStoreTests.swift
```

**Conventions used throughout:**
- All `SlouchCore` types crossing into tests/app are `public`.
- Stick space: `x` right-positive, `y` up-positive, each in `-1...1`.
- Screen space (in `SynthCommand`): `dy` positive = downward. The engine inverts stick-Y so pushing up moves the cursor up.
- Comments only for non-obvious "why".

---

## Task 1: Package scaffold + first failing test

**Files:**
- Create: `Package.swift`
- Create: `Sources/SlouchCore/Engine/Deadzone.swift` (empty placeholder so the target compiles)
- Create: `Tests/SlouchCoreTests/DeadzoneTests.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Slouch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SlouchCore"),
        .testTarget(name: "SlouchCoreTests", dependencies: ["SlouchCore"]),
        .executableTarget(name: "Slouch", dependencies: ["SlouchCore"]),
    ]
)
```

- [ ] **Step 2: Create the executable target's entry so the package resolves**

Create `Sources/Slouch/SlouchApp.swift` with a temporary stub (replaced in Task 9):

```swift
@main
struct SlouchApp {
    static func main() {}
}
```

- [ ] **Step 3: Create a placeholder so `SlouchCore` compiles**

Create `Sources/SlouchCore/Engine/Deadzone.swift`:

```swift
import Foundation
```

- [ ] **Step 4: Write the failing test**

Create `Tests/SlouchCoreTests/DeadzoneTests.swift`:

```swift
import XCTest
@testable import SlouchCore

final class DeadzoneTests: XCTestCase {
    func test_inputInsideDeadzone_returnsZero() {
        let v = StickVector(x: 0.03, y: 0.0)
        let out = applyRadialDeadzone(v, deadZone: 0.05)
        XCTAssertEqual(out.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(out.y, 0.0, accuracy: 1e-9)
    }
}
```

- [ ] **Step 5: Run test to verify it fails to compile**

Run: `swift test --filter DeadzoneTests`
Expected: FAIL — `cannot find 'StickVector'` / `cannot find 'applyRadialDeadzone'`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "Scaffold SwiftPM package with first failing test"
```

---

## Task 2: StickVector + radial dead zone (TDD)

**Files:**
- Create: `Sources/SlouchCore/Model/Inputs.swift`
- Modify: `Sources/SlouchCore/Engine/Deadzone.swift`
- Modify: `Tests/SlouchCoreTests/DeadzoneTests.swift`

- [ ] **Step 1: Add the remaining failing tests**

Replace `Tests/SlouchCoreTests/DeadzoneTests.swift` with:

```swift
import XCTest
@testable import SlouchCore

final class DeadzoneTests: XCTestCase {
    func test_inputInsideDeadzone_returnsZero() {
        let out = applyRadialDeadzone(StickVector(x: 0.03, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 0.0, accuracy: 1e-9)
        XCTAssertEqual(out.y, 0.0, accuracy: 1e-9)
    }

    func test_fullDeflection_staysFull() {
        let out = applyRadialDeadzone(StickVector(x: 1.0, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(out.y, 0.0, accuracy: 1e-9)
    }

    func test_justAboveDeadzone_rescalesFromZero() {
        // magnitude just above 0.05 should map to just above 0, not jump.
        let out = applyRadialDeadzone(StickVector(x: 0.05000001, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 0.0, accuracy: 1e-4)
    }

    func test_midRange_rescaledLinearly() {
        // mag 0.525, dz 0.05 -> (0.525-0.05)/(1-0.05) = 0.5
        let out = applyRadialDeadzone(StickVector(x: 0.525, y: 0.0), deadZone: 0.05)
        XCTAssertEqual(out.x, 0.5, accuracy: 1e-6)
    }

    func test_directionPreserved_onDiagonal() {
        let out = applyRadialDeadzone(StickVector(x: 0.6, y: 0.8), deadZone: 0.0)
        XCTAssertEqual(out.x / out.y, 0.6 / 0.8, accuracy: 1e-6)
    }
}
```

- [ ] **Step 2: Create the input model**

Create `Sources/SlouchCore/Model/Inputs.swift`:

```swift
import Foundation

public struct StickVector: Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    public static let zero = StickVector(x: 0, y: 0)
    public var magnitude: Double { (x * x + y * y).squareRoot() }
}

public enum StickID: String, Codable, CaseIterable, Sendable {
    case left, right
}

public enum ButtonID: String, Codable, CaseIterable, Sendable {
    case a, b, x, y
    case lb, rb, lt, rt
    case l3, r3
    case menu, options
    case dpadUp, dpadDown, dpadLeft, dpadRight
}

public struct GamepadState: Equatable {
    public var leftStick: StickVector
    public var rightStick: StickVector
    public var pressed: Set<ButtonID>
    public init(leftStick: StickVector = .zero,
                rightStick: StickVector = .zero,
                pressed: Set<ButtonID> = []) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.pressed = pressed
    }
}
```

- [ ] **Step 3: Implement the dead zone**

Replace `Sources/SlouchCore/Engine/Deadzone.swift` with:

```swift
import Foundation

/// Radial dead zone: ignores combined X/Y magnitude below `deadZone`, then
/// rescales so output rises smoothly from 0 at the boundary to 1 at full push.
public func applyRadialDeadzone(_ v: StickVector, deadZone: Double) -> StickVector {
    let mag = v.magnitude
    guard mag > deadZone, mag > 0 else { return .zero }
    let rescaled = (mag - deadZone) / (1 - deadZone)
    let scale = rescaled / mag
    return StickVector(x: v.x * scale, y: v.y * scale)
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter DeadzoneTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SlouchCore/Model/Inputs.swift Sources/SlouchCore/Engine/Deadzone.swift Tests/SlouchCoreTests/DeadzoneTests.swift
git commit -m "Add input model and radial dead zone"
```

---

## Task 3: Speed curve (TDD)

**Files:**
- Create: `Sources/SlouchCore/Engine/SpeedCurve.swift`
- Create: `Tests/SlouchCoreTests/SpeedCurveTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/SlouchCoreTests/SpeedCurveTests.swift`:

```swift
import XCTest
@testable import SlouchCore

final class SpeedCurveTests: XCTestCase {
    func test_zeroMagnitude_isZero() {
        XCTAssertEqual(curvedSpeed(magnitude: 0.0), 0.0, accuracy: 1e-9)
    }

    func test_fullMagnitude_isOne() {
        XCTAssertEqual(curvedSpeed(magnitude: 1.0), 1.0, accuracy: 1e-9)
    }

    func test_midMagnitude_isBelowLinear() {
        // exponent 1.5 means 0.5 -> 0.5^1.5 ≈ 0.3536, giving finer low-end control.
        XCTAssertEqual(curvedSpeed(magnitude: 0.5), 0.3535533, accuracy: 1e-5)
    }

    func test_clampsAboveOne() {
        XCTAssertEqual(curvedSpeed(magnitude: 1.4), 1.0, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter SpeedCurveTests`
Expected: FAIL — `cannot find 'curvedSpeed'`.

- [ ] **Step 3: Implement**

Create `Sources/SlouchCore/Engine/SpeedCurve.swift`:

```swift
import Foundation

/// Mild fixed acceleration: output = magnitude^exponent, clamped to 0...1.
/// Gives precision at small deflections without a user-facing curve editor.
public let speedCurveExponent: Double = 1.5

public func curvedSpeed(magnitude: Double) -> Double {
    let clamped = min(max(magnitude, 0), 1)
    return Foundation.pow(clamped, speedCurveExponent)
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter SpeedCurveTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SlouchCore/Engine/SpeedCurve.swift Tests/SlouchCoreTests/SpeedCurveTests.swift
git commit -m "Add fixed-exponent speed curve"
```

---

## Task 4: Output model + Mapping + Settings + Config (TDD)

**Files:**
- Create: `Sources/SlouchCore/Model/Outputs.swift`
- Create: `Sources/SlouchCore/Model/Mapping.swift`
- Create: `Tests/SlouchCoreTests/MappingModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Tests/SlouchCoreTests/MappingModelTests.swift`:

```swift
import XCTest
@testable import SlouchCore

final class MappingModelTests: XCTestCase {
    func test_couchDefault_hasExpectedBindings() {
        let m = Mapping.couchDefault
        XCTAssertEqual(m.rightStick, .mouseMove)
        XCTAssertEqual(m.leftStick, .scroll)
        XCTAssertEqual(m.buttons[.a], .mouseClick(.left))
        XCTAssertEqual(m.buttons[.b], .mouseClick(.right))
        XCTAssertEqual(m.buttons[.menu], .sleep)
    }

    func test_config_roundTripsThroughJSON() throws {
        let original = Config.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func test_keystroke_roundTripsWithModifiers() throws {
        let stroke = KeyStroke(keyCode: 49, modifiers: [.command, .shift])
        let action = OutputAction.keystroke(stroke)
        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(OutputAction.self, from: data)
        XCTAssertEqual(decoded, action)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter MappingModelTests`
Expected: FAIL — `cannot find 'Mapping'` etc.

- [ ] **Step 3: Create the output model**

Create `Sources/SlouchCore/Model/Outputs.swift`:

```swift
import Foundation

public enum MouseButton: String, Codable, Equatable, Sendable {
    case left, right, middle
}

public struct ModifierFlags: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = ModifierFlags(rawValue: 1 << 0)
    public static let shift   = ModifierFlags(rawValue: 1 << 1)
    public static let option  = ModifierFlags(rawValue: 1 << 2)
    public static let control = ModifierFlags(rawValue: 1 << 3)
}

public struct KeyStroke: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: ModifierFlags
    public init(keyCode: UInt16, modifiers: ModifierFlags = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum StickRole: String, Codable, Equatable, Sendable {
    case mouseMove, scroll, none
}

public enum OutputAction: Codable, Equatable, Sendable {
    case mouseClick(MouseButton)
    case keystroke(KeyStroke)
    case sleep
    case none
}

/// What the engine asks the synthesizer to do. `dy` positive = screen-down.
public enum SynthCommand: Equatable, Sendable {
    case moveMouse(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case mouseDown(MouseButton)
    case mouseUp(MouseButton)
    case keyDown(KeyStroke)
    case keyUp(KeyStroke)
    case sleep
}
```

- [ ] **Step 4: Create the mapping/settings/config model**

Create `Sources/SlouchCore/Model/Mapping.swift`:

```swift
import Foundation

public struct Mapping: Codable, Equatable, Sendable {
    public var leftStick: StickRole
    public var rightStick: StickRole
    public var buttons: [ButtonID: OutputAction]

    public init(leftStick: StickRole, rightStick: StickRole, buttons: [ButtonID: OutputAction]) {
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.buttons = buttons
    }

    public static var couchDefault: Mapping {
        Mapping(
            leftStick: .scroll,
            rightStick: .mouseMove,
            buttons: [
                .a: .mouseClick(.left),
                .b: .mouseClick(.right),
                // Y triggers the user's voice-input app; default Cmd+Shift+Space.
                .y: .keystroke(KeyStroke(keyCode: 49, modifiers: [.command, .shift])),
                .menu: .sleep,
                .dpadUp: .keystroke(KeyStroke(keyCode: 126)),
                .dpadDown: .keystroke(KeyStroke(keyCode: 125)),
                .dpadLeft: .keystroke(KeyStroke(keyCode: 123)),
                .dpadRight: .keystroke(KeyStroke(keyCode: 124)),
            ]
        )
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var cursorSpeed: Double   // px/sec at full deflection
    public var scrollSpeed: Double   // lines/sec at full deflection
    public var deadZone: Double      // 0...0.5

    public init(cursorSpeed: Double = 1400, scrollSpeed: Double = 30, deadZone: Double = 0.05) {
        self.cursorSpeed = cursorSpeed
        self.scrollSpeed = scrollSpeed
        self.deadZone = deadZone
    }

    public static let `default` = Settings()
}

public struct Config: Codable, Equatable, Sendable {
    public var mapping: Mapping
    public var settings: Settings
    public init(mapping: Mapping, settings: Settings) {
        self.mapping = mapping
        self.settings = settings
    }
    public static let `default` = Config(mapping: .couchDefault, settings: .default)
}
```

- [ ] **Step 5: Run tests**

Run: `swift test --filter MappingModelTests`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add Sources/SlouchCore/Model/Outputs.swift Sources/SlouchCore/Model/Mapping.swift Tests/SlouchCoreTests/MappingModelTests.swift
git commit -m "Add output model, mapping, settings, and config"
```

---

## Task 5: MappingEngine — button edges (TDD)

**Files:**
- Create: `Sources/SlouchCore/Engine/MappingEngine.swift`
- Create: `Tests/SlouchCoreTests/MappingEngineTests.swift`

- [ ] **Step 1: Write failing tests for button press/release edges**

Create `Tests/SlouchCoreTests/MappingEngineTests.swift`:

```swift
import XCTest
@testable import SlouchCore

final class MappingEngineTests: XCTestCase {
    private func makeEngine() -> MappingEngine {
        MappingEngine(mapping: .couchDefault, settings: .default)
    }

    func test_buttonPress_emitsMouseDownOnce() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        XCTAssertTrue(cmds.contains(.mouseDown(.left)))
    }

    func test_buttonHeld_doesNotRepeatMouseDown() {
        let engine = makeEngine()
        _ = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        XCTAssertFalse(cmds.contains(.mouseDown(.left)))
    }

    func test_buttonRelease_emitsMouseUp() {
        let engine = makeEngine()
        _ = engine.process(state: GamepadState(pressed: [.a]), dt: 1.0 / 60)
        let cmds = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        XCTAssertTrue(cmds.contains(.mouseUp(.left)))
    }

    func test_keystrokeButton_emitsKeyDownThenKeyUp() {
        let engine = makeEngine()
        let down = engine.process(state: GamepadState(pressed: [.y]), dt: 1.0 / 60)
        let up = engine.process(state: GamepadState(pressed: []), dt: 1.0 / 60)
        let stroke = KeyStroke(keyCode: 49, modifiers: [.command, .shift])
        XCTAssertTrue(down.contains(.keyDown(stroke)))
        XCTAssertTrue(up.contains(.keyUp(stroke)))
    }

    func test_sleepButton_emitsSleepOnPressOnly() {
        let engine = makeEngine()
        let down = engine.process(state: GamepadState(pressed: [.menu]), dt: 1.0 / 60)
        let held = engine.process(state: GamepadState(pressed: [.menu]), dt: 1.0 / 60)
        XCTAssertTrue(down.contains(.sleep))
        XCTAssertFalse(held.contains(.sleep))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter MappingEngineTests`
Expected: FAIL — `cannot find 'MappingEngine'`.

- [ ] **Step 3: Implement the engine (button handling only for now)**

Create `Sources/SlouchCore/Engine/MappingEngine.swift`:

```swift
import Foundation

public final class MappingEngine {
    public var mapping: Mapping
    public var settings: Settings
    private var previouslyPressed: Set<ButtonID> = []

    public init(mapping: Mapping, settings: Settings) {
        self.mapping = mapping
        self.settings = settings
    }

    public func process(state: GamepadState, dt: Double) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        commands.append(contentsOf: buttonCommands(state: state))
        previouslyPressed = state.pressed
        return commands
    }

    private func buttonCommands(state: GamepadState) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        let justPressed = state.pressed.subtracting(previouslyPressed)
        let justReleased = previouslyPressed.subtracting(state.pressed)

        for button in justPressed {
            switch mapping.buttons[button] {
            case .mouseClick(let b): commands.append(.mouseDown(b))
            case .keystroke(let k): commands.append(.keyDown(k))
            case .sleep: commands.append(.sleep)
            case .none, nil: break
            }
        }
        for button in justReleased {
            switch mapping.buttons[button] {
            case .mouseClick(let b): commands.append(.mouseUp(b))
            case .keystroke(let k): commands.append(.keyUp(k))
            case .sleep, .none, nil: break
            }
        }
        return commands
    }
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter MappingEngineTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SlouchCore/Engine/MappingEngine.swift Tests/SlouchCoreTests/MappingEngineTests.swift
git commit -m "Add MappingEngine button-edge translation"
```

---

## Task 6: MappingEngine — stick move & scroll (TDD)

**Files:**
- Modify: `Sources/SlouchCore/Engine/MappingEngine.swift`
- Modify: `Tests/SlouchCoreTests/MappingEngineTests.swift`

- [ ] **Step 1: Add failing stick tests**

Append these methods inside `MappingEngineTests` in `Tests/SlouchCoreTests/MappingEngineTests.swift`:

```swift
    func test_rightStickFullRight_movesCursorRight() {
        let engine = makeEngine()
        let dt = 0.5
        let cmds = engine.process(state: GamepadState(rightStick: StickVector(x: 1, y: 0)), dt: dt)
        // speed at full = cursorSpeed (1400) * curvedSpeed(1)=1 * dt(0.5) = 700
        guard case let .moveMouse(dx, dy)? = cmds.first(where: { if case .moveMouse = $0 { return true }; return false }) else {
            return XCTFail("expected moveMouse")
        }
        XCTAssertEqual(dx, 700, accuracy: 1e-6)
        XCTAssertEqual(dy, 0, accuracy: 1e-6)
    }

    func test_rightStickUp_movesCursorUp_negativeDy() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(rightStick: StickVector(x: 0, y: 1)), dt: 0.5)
        guard case let .moveMouse(_, dy)? = cmds.first(where: { if case .moveMouse = $0 { return true }; return false }) else {
            return XCTFail("expected moveMouse")
        }
        XCTAssertLessThan(dy, 0)
    }

    func test_rightStickInsideDeadzone_emitsNoMove() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(rightStick: StickVector(x: 0.02, y: 0)), dt: 0.5)
        XCTAssertFalse(cmds.contains { if case .moveMouse = $0 { return true }; return false })
    }

    func test_leftStickDown_scrolls() {
        let engine = makeEngine()
        let cmds = engine.process(state: GamepadState(leftStick: StickVector(x: 0, y: -1)), dt: 0.5)
        XCTAssertTrue(cmds.contains { if case .scroll = $0 { return true }; return false })
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter MappingEngineTests`
Expected: FAIL — new tests fail (no `.moveMouse`/`.scroll` emitted yet).

- [ ] **Step 3: Add stick handling to the engine**

In `Sources/SlouchCore/Engine/MappingEngine.swift`, update `process(state:dt:)` to also append stick commands, and add the helper:

```swift
    public func process(state: GamepadState, dt: Double) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        commands.append(contentsOf: stickCommands(state: state, dt: dt))
        commands.append(contentsOf: buttonCommands(state: state))
        previouslyPressed = state.pressed
        return commands
    }

    private func stickCommands(state: GamepadState, dt: Double) -> [SynthCommand] {
        var commands: [SynthCommand] = []
        commands.append(contentsOf: stickCommand(role: mapping.leftStick, raw: state.leftStick, dt: dt))
        commands.append(contentsOf: stickCommand(role: mapping.rightStick, raw: state.rightStick, dt: dt))
        return commands
    }

    private func stickCommand(role: StickRole, raw: StickVector, dt: Double) -> [SynthCommand] {
        let v = applyRadialDeadzone(raw, deadZone: settings.deadZone)
        let mag = v.magnitude
        guard mag > 0 else { return [] }
        let unitX = v.x / mag
        let unitY = v.y / mag
        let speed = curvedSpeed(magnitude: mag)
        switch role {
        case .mouseMove:
            let s = speed * settings.cursorSpeed * dt
            return [.moveMouse(dx: unitX * s, dy: -unitY * s)]
        case .scroll:
            let s = speed * settings.scrollSpeed * dt
            return [.scroll(dx: unitX * s, dy: -unitY * s)]
        case .none:
            return []
        }
    }
```

Note: keep the existing `buttonCommands(state:)` method unchanged.

- [ ] **Step 4: Run tests**

Run: `swift test --filter MappingEngineTests`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/SlouchCore/Engine/MappingEngine.swift Tests/SlouchCoreTests/MappingEngineTests.swift
git commit -m "Add stick move and scroll translation to MappingEngine"
```

---

## Task 7: IO protocols + MappingStore (TDD for store)

**Files:**
- Create: `Sources/SlouchCore/IO/GamepadSource.swift`
- Create: `Sources/SlouchCore/IO/OutputSynthesizer.swift`
- Create: `Sources/SlouchCore/Store/MappingStore.swift`
- Create: `Tests/SlouchCoreTests/MappingStoreTests.swift`

- [ ] **Step 1: Define the IO protocols (no tests; consumed by app target)**

Create `Sources/SlouchCore/IO/GamepadSource.swift`:

```swift
import Foundation

/// Abstracts the source of gamepad input so the engine can be driven by real
/// hardware or by a synthetic source in tests.
public protocol GamepadSource: AnyObject {
    var isConnected: Bool { get }
    /// Current snapshot of sticks + pressed buttons.
    func currentState() -> GamepadState
    /// Called when a controller connects/disconnects.
    var onConnectionChange: ((Bool) -> Void)? { get set }
    /// Tear down and re-establish controller observation (used after wake).
    func rebind()
}
```

Create `Sources/SlouchCore/IO/OutputSynthesizer.swift`:

```swift
import Foundation

/// Abstracts emission of OS input events so the engine can be unit-tested.
public protocol OutputSynthesizer: AnyObject {
    func perform(_ command: SynthCommand)
}
```

- [ ] **Step 2: Write failing store tests**

Create `Tests/SlouchCoreTests/MappingStoreTests.swift`:

```swift
import XCTest
@testable import SlouchCore

final class MappingStoreTests: XCTestCase {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func test_loadFromEmptyDir_returnsDefault() {
        let store = MappingStore(directory: tempDir())
        XCTAssertEqual(store.load(), Config.default)
    }

    func test_saveThenLoad_roundTrips() throws {
        let dir = tempDir()
        let store = MappingStore(directory: dir)
        var config = Config.default
        config.settings.cursorSpeed = 999
        try store.save(config)

        let reloaded = MappingStore(directory: dir).load()
        XCTAssertEqual(reloaded.settings.cursorSpeed, 999)
        XCTAssertEqual(reloaded, config)
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `swift test --filter MappingStoreTests`
Expected: FAIL — `cannot find 'MappingStore'`.

- [ ] **Step 4: Implement MappingStore**

Create `Sources/SlouchCore/Store/MappingStore.swift`:

```swift
import Foundation

public final class MappingStore {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("config.json")
    }

    /// Default location: ~/Library/Application Support/Slouch
    public convenience init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Slouch", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.init(directory: base)
    }

    public func load() -> Config {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return .default
        }
        return config
    }

    public func save(_ config: Config) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 5: Run all tests (full suite green checkpoint)**

Run: `swift test`
Expected: PASS — all suites (Deadzone, SpeedCurve, MappingModel, MappingEngine, MappingStore).

- [ ] **Step 6: Commit**

```bash
git add Sources/SlouchCore/IO Sources/SlouchCore/Store Tests/SlouchCoreTests/MappingStoreTests.swift
git commit -m "Add IO protocols and config persistence"
```

---

## Task 8: CGOutputSynthesizer (concrete CGEvent output)

**Files:**
- Create: `Sources/Slouch/CGOutputSynthesizer.swift`

This wraps `CGEvent`. It is not unit-tested (it talks to the OS); verified manually in Task 13.

- [ ] **Step 1: Implement the synthesizer**

Create `Sources/Slouch/CGOutputSynthesizer.swift`:

```swift
import CoreGraphics
import AppKit
import SlouchCore

final class CGOutputSynthesizer: OutputSynthesizer {
    private var downButtons: Set<MouseButton> = []

    func perform(_ command: SynthCommand) {
        switch command {
        case let .moveMouse(dx, dy): moveMouse(dx: dx, dy: dy)
        case let .scroll(dx, dy): scroll(dx: dx, dy: dy)
        case let .mouseDown(button): mouseButton(button, down: true)
        case let .mouseUp(button): mouseButton(button, down: false)
        case let .keyDown(stroke): key(stroke, down: true)
        case let .keyUp(stroke): key(stroke, down: false)
        case .sleep: break // handled by SystemActions, not the synthesizer
        }
    }

    private func currentLocation() -> CGPoint {
        // CGEvent uses top-left origin; NSEvent.mouseLocation is bottom-left.
        let p = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: screenHeight - p.y)
    }

    private func clampToScreens(_ p: CGPoint) -> CGPoint {
        guard let main = NSScreen.screens.first else { return p }
        let h = main.frame.height
        let bounds = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let x = min(max(p.x, bounds.minX), bounds.maxX - 1)
        // Convert union bounds (bottom-left) to top-left for clamping y.
        let topY = h - bounds.maxY
        let bottomY = h - bounds.minY
        let y = min(max(p.y, topY), bottomY - 1)
        return CGPoint(x: x, y: y)
    }

    private func moveMouse(dx: Double, dy: Double) {
        let from = currentLocation()
        let to = clampToScreens(CGPoint(x: from.x + dx, y: from.y + dy))
        let isDragging = downButtons.contains(.left)
        let type: CGEventType = isDragging ? .leftMouseDragged : .mouseMoved
        let button: CGMouseButton = .left
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: to, mouseButton: button)
        event?.post(tap: .cghidEventTap)
    }

    private func scroll(dx: Double, dy: Double) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2,
                            wheel1: Int32(dy.rounded()), wheel2: Int32(dx.rounded()), wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }

    private func mouseButton(_ button: MouseButton, down: Bool) {
        if down { downButtons.insert(button) } else { downButtons.remove(button) }
        let location = currentLocation()
        let (type, cgButton): (CGEventType, CGMouseButton)
        switch button {
        case .left: type = down ? .leftMouseDown : .leftMouseUp; cgButton = .left
        case .right: type = down ? .rightMouseDown : .rightMouseUp; cgButton = .right
        case .middle: type = down ? .otherMouseDown : .otherMouseUp; cgButton = .center
        }
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: cgButton)
        event?.post(tap: .cghidEventTap)
    }

    private func cgFlags(_ mods: ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if mods.contains(.command) { flags.insert(.maskCommand) }
        if mods.contains(.shift) { flags.insert(.maskShift) }
        if mods.contains(.option) { flags.insert(.maskAlternate) }
        if mods.contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    private func key(_ stroke: KeyStroke, down: Bool) {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: stroke.keyCode, keyDown: down)
        event?.flags = cgFlags(stroke.modifiers)
        event?.post(tap: .cghidEventTap)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Builds successfully (the executable target still has the stub `main`; that's fine).

- [ ] **Step 3: Commit**

```bash
git add Sources/Slouch/CGOutputSynthesizer.swift
git commit -m "Add CGEvent output synthesizer"
```

---

## Task 9: GCGamepadSource (concrete GameController input) + WakeWatcher + SystemActions + PermissionsManager

**Files:**
- Create: `Sources/Slouch/GCGamepadSource.swift`
- Create: `Sources/Slouch/WakeWatcher.swift`
- Create: `Sources/Slouch/SystemActions.swift`
- Create: `Sources/Slouch/PermissionsManager.swift`

- [ ] **Step 1: Implement GCGamepadSource**

Create `Sources/Slouch/GCGamepadSource.swift`:

```swift
import GameController
import SlouchCore

final class GCGamepadSource: GamepadSource {
    private var controller: GCController?
    var onConnectionChange: ((Bool) -> Void)?

    var isConnected: Bool { controller?.extendedGamepad != nil }

    init() {
        bind()
        NotificationCenter.default.addObserver(
            self, selector: #selector(connected),
            name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(disconnected),
            name: .GCControllerDidDisconnect, object: nil)
    }

    private func bind() {
        controller = GCController.controllers().first { $0.extendedGamepad != nil }
        onConnectionChange?(isConnected)
    }

    func rebind() {
        controller = nil
        bind()
        // Restart wireless discovery in case the link came back without a connect event.
        GCController.startWirelessControllerDiscovery {}
    }

    @objc private func connected() { bind() }
    @objc private func disconnected() {
        controller = nil
        onConnectionChange?(false)
    }

    func currentState() -> GamepadState {
        guard let pad = controller?.extendedGamepad else { return GamepadState() }
        var pressed: Set<ButtonID> = []
        func add(_ id: ButtonID, _ button: GCControllerButtonInput?) {
            if button?.isPressed == true { pressed.insert(id) }
        }
        add(.a, pad.buttonA); add(.b, pad.buttonB); add(.x, pad.buttonX); add(.y, pad.buttonY)
        add(.lb, pad.leftShoulder); add(.rb, pad.rightShoulder)
        add(.lt, pad.leftTrigger); add(.rt, pad.rightTrigger)
        add(.l3, pad.leftThumbstickButton); add(.r3, pad.rightThumbstickButton)
        add(.menu, pad.buttonMenu); add(.options, pad.buttonOptions)
        if pad.dpad.up.isPressed { pressed.insert(.dpadUp) }
        if pad.dpad.down.isPressed { pressed.insert(.dpadDown) }
        if pad.dpad.left.isPressed { pressed.insert(.dpadLeft) }
        if pad.dpad.right.isPressed { pressed.insert(.dpadRight) }

        return GamepadState(
            leftStick: StickVector(x: Double(pad.leftThumbstick.xAxis.value),
                                   y: Double(pad.leftThumbstick.yAxis.value)),
            rightStick: StickVector(x: Double(pad.rightThumbstick.xAxis.value),
                                    y: Double(pad.rightThumbstick.yAxis.value)),
            pressed: pressed)
    }
}
```

- [ ] **Step 2: Implement WakeWatcher**

Create `Sources/Slouch/WakeWatcher.swift`:

```swift
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
```

- [ ] **Step 3: Implement SystemActions**

Create `Sources/Slouch/SystemActions.swift`:

```swift
import Foundation

enum SystemActions {
    /// Sleeps the Mac without admin rights.
    static func sleep() {
        let script = "tell application \"System Events\" to sleep"
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }
}
```

- [ ] **Step 4: Implement PermissionsManager**

Create `Sources/Slouch/PermissionsManager.swift`:

```swift
import AppKit
import ApplicationServices

enum PermissionsManager {
    /// Whether the app may post synthetic input (Accessibility permission).
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the system Accessibility dialog if not yet trusted.
    static func promptIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: Builds successfully.

- [ ] **Step 6: Commit**

```bash
git add Sources/Slouch/GCGamepadSource.swift Sources/Slouch/WakeWatcher.swift Sources/Slouch/SystemActions.swift Sources/Slouch/PermissionsManager.swift
git commit -m "Add GameController source, wake watcher, sleep, permissions"
```

---

## Task 10: AppModel — wiring + run loop

**Files:**
- Create: `Sources/Slouch/AppModel.swift`

- [ ] **Step 1: Implement AppModel**

Create `Sources/Slouch/AppModel.swift`:

```swift
import SwiftUI
import QuartzCore
import SlouchCore

@MainActor
final class AppModel: ObservableObject {
    @Published var isEnabled = false { didSet { isEnabled ? start() : stop() } }
    @Published var isConnected = false
    @Published var isTrusted = PermissionsManager.isTrusted()
    @Published var config: Config { didSet { applyConfig() } }

    private let store = MappingStore()
    private let source: GamepadSource
    private let synth: OutputSynthesizer
    private let engine: MappingEngine
    private var wakeWatcher: WakeWatcher?
    private var displayLink: CVDisplayLink?
    private var lastTick: CFTimeInterval = 0

    init(source: GamepadSource = GCGamepadSource(),
         synth: OutputSynthesizer = CGOutputSynthesizer()) {
        self.source = source
        self.synth = synth
        let loaded = store.load()
        self.config = loaded
        self.engine = MappingEngine(mapping: loaded.mapping, settings: loaded.settings)

        self.source.onConnectionChange = { [weak self] connected in
            Task { @MainActor in self?.isConnected = connected }
        }
        self.isConnected = source.isConnected
        self.wakeWatcher = WakeWatcher { [weak self] in
            Task { @MainActor in self?.source.rebind() }
        }
    }

    private func applyConfig() {
        engine.mapping = config.mapping
        engine.settings = config.settings
        try? store.save(config)
    }

    func recheckPermission() { isTrusted = PermissionsManager.isTrusted() }

    private func start() {
        recheckPermission()
        guard isTrusted else {
            PermissionsManager.promptIfNeeded()
            isEnabled = false
            return
        }
        startDisplayLink()
    }

    private func stop() { stopDisplayLink() }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = lastTick == 0 ? 1.0 / 60 : now - lastTick
        lastTick = now
        let commands = engine.process(state: source.currentState(), dt: dt)
        for command in commands {
            if case .sleep = command { SystemActions.sleep() } else { synth.perform(command) }
        }
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, ctx in
            let model = Unmanaged<AppModel>.fromOpaque(ctx!).takeUnretainedValue()
            Task { @MainActor in model.tick() }
            return kCVReturnSuccess
        }, userInfo)
        CVDisplayLinkStart(link)
        displayLink = link
    }

    private func stopDisplayLink() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
        lastTick = 0
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Builds (the `@main` stub from Task 1 still compiles; it'll be replaced next).

- [ ] **Step 3: Commit**

```bash
git add Sources/Slouch/AppModel.swift
git commit -m "Add AppModel wiring and display-link run loop"
```

---

## Task 11: SwiftUI app shell (menu bar) + Settings UI

**Files:**
- Modify: `Sources/Slouch/SlouchApp.swift` (replace the Task 1 stub)
- Create: `Sources/Slouch/SettingsView.swift`

- [ ] **Step 1: Replace the app entry point**

Replace `Sources/Slouch/SlouchApp.swift` with:

```swift
import SwiftUI

@main
struct SlouchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Slouch", systemImage: model.isEnabled ? "gamecontroller.fill" : "gamecontroller") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Toggle("Enabled", isOn: $model.isEnabled)
        Divider()
        Text(model.isConnected ? "Controller: connected" : "Controller: not found")
        if !model.isTrusted {
            Text("⚠︎ Accessibility permission needed")
            Button("Open Accessibility Settings…") {
                PermissionsManager.openAccessibilitySettings()
            }
        }
        Divider()
        SettingsLink { Text("Settings…") }
        Button("Quit Slouch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
```

- [ ] **Step 2: Create SettingsView**

Create `Sources/Slouch/SettingsView.swift`:

```swift
import SwiftUI
import SlouchCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Sensitivity") {
                LabeledContent("Cursor speed") {
                    Slider(value: $model.config.settings.cursorSpeed, in: 400...3000)
                }
                LabeledContent("Scroll speed") {
                    Slider(value: $model.config.settings.scrollSpeed, in: 5...80)
                }
                LabeledContent("Dead zone") {
                    Slider(value: $model.config.settings.deadZone, in: 0...0.5)
                }
            }
            Section("Sticks") {
                Picker("Right stick", selection: $model.config.mapping.rightStick) {
                    Text("Move mouse").tag(StickRole.mouseMove)
                    Text("Scroll").tag(StickRole.scroll)
                    Text("Off").tag(StickRole.none)
                }
                Picker("Left stick", selection: $model.config.mapping.leftStick) {
                    Text("Move mouse").tag(StickRole.mouseMove)
                    Text("Scroll").tag(StickRole.scroll)
                    Text("Off").tag(StickRole.none)
                }
            }
            // The "Buttons" section is added in Task 12.
        }
        .padding()
        .frame(width: 420)
    }
}
```

- [ ] **Step 3: Build & run**

Run: `swift build && swift run Slouch`
Expected: A game-controller icon appears in the menu bar. Clicking it shows the Enabled toggle, controller status, and Settings/Quit. (Leave it running for the next task.)

- [ ] **Step 4: Commit**

```bash
git add Sources/Slouch/SlouchApp.swift Sources/Slouch/SettingsView.swift
git commit -m "Add menu-bar shell and settings UI"
```

---

## Task 12: In-app button binding editor

Lets the user re-bind any button in the Settings window: pick an action
(off / left / right / middle click / key / sleep), and for "key" record an
arbitrary keystroke. Adds a unit-tested display helper in `SlouchCore`; the
SwiftUI editor itself is verified manually.

**Files:**
- Modify: `Sources/SlouchCore/Model/Outputs.swift`
- Create: `Tests/SlouchCoreTests/KeyStrokeDisplayTests.swift`
- Create: `Sources/Slouch/ButtonBindingEditor.swift`
- Modify: `Sources/Slouch/SettingsView.swift`

- [ ] **Step 1: Write failing tests for the display helper**

Create `Tests/SlouchCoreTests/KeyStrokeDisplayTests.swift`:

```swift
import XCTest
@testable import SlouchCore

final class KeyStrokeDisplayTests: XCTestCase {
    func test_voiceHotkey_rendersModifiersThenKey() {
        let stroke = KeyStroke(keyCode: 49, modifiers: [.command, .shift])
        XCTAssertEqual(stroke.displayString, "⇧⌘Space")
    }

    func test_arrowKey_rendersSymbol() {
        XCTAssertEqual(KeyStroke(keyCode: 126).displayString, "↑")
    }

    func test_unknownKey_fallsBackToCode() {
        XCTAssertEqual(KeyStroke(keyCode: 200).displayString, "key 200")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter KeyStrokeDisplayTests`
Expected: FAIL — `value of type 'KeyStroke' has no member 'displayString'`.

- [ ] **Step 3: Add the display helper to Outputs.swift**

Append to `Sources/SlouchCore/Model/Outputs.swift`:

```swift
public extension ModifierFlags {
    /// macOS-convention order: ⌃⌥⇧⌘.
    var symbolString: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

public extension KeyStroke {
    var displayString: String {
        symbolString(of: modifiers) + KeyStroke.keyName(for: keyCode)
    }

    private func symbolString(of mods: ModifierFlags) -> String { mods.symbolString }

    static func keyName(for code: UInt16) -> String {
        knownKeyNames[code] ?? "key \(code)"
    }

    private static let knownKeyNames: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}
```

- [ ] **Step 4: Run tests**

Run: `swift test --filter KeyStrokeDisplayTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Create the editor view**

Create `Sources/Slouch/ButtonBindingEditor.swift`:

```swift
import SwiftUI
import AppKit
import SlouchCore

func modifierFlags(from flags: NSEvent.ModifierFlags) -> ModifierFlags {
    var m: ModifierFlags = []
    if flags.contains(.command) { m.insert(.command) }
    if flags.contains(.shift) { m.insert(.shift) }
    if flags.contains(.option) { m.insert(.option) }
    if flags.contains(.control) { m.insert(.control) }
    return m
}

private enum ActionKind: String, CaseIterable, Identifiable {
    case none = "Off"
    case leftClick = "Left click"
    case rightClick = "Right click"
    case middleClick = "Middle click"
    case key = "Key…"
    case sleep = "Sleep"
    var id: String { rawValue }
}

private func kind(of action: OutputAction?) -> ActionKind {
    switch action {
    case .mouseClick(.left): return .leftClick
    case .mouseClick(.right): return .rightClick
    case .mouseClick(.middle): return .middleClick
    case .keystroke: return .key
    case .sleep: return .sleep
    case .none, nil: return .none
    }
}

private func makeAction(for kind: ActionKind, existing: OutputAction?) -> OutputAction {
    switch kind {
    case .none: return .none
    case .leftClick: return .mouseClick(.left)
    case .rightClick: return .mouseClick(.right)
    case .middleClick: return .mouseClick(.middle)
    case .sleep: return .sleep
    case .key:
        if case .keystroke(let k)? = existing { return .keystroke(k) }
        return .keystroke(KeyStroke(keyCode: 49)) // default Space
    }
}

struct ButtonsSection: View {
    @ObservedObject var model: AppModel
    private let buttons: [ButtonID] = [
        .a, .b, .x, .y, .lb, .rb, .lt, .rt, .l3, .r3, .menu, .options,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
    ]

    var body: some View {
        Section("Buttons") {
            ForEach(buttons, id: \.self) { button in
                ButtonBindingRow(button: button, action: binding(for: button))
            }
        }
    }

    private func binding(for button: ButtonID) -> Binding<OutputAction?> {
        Binding(
            get: { model.config.mapping.buttons[button] },
            set: { model.config.mapping.buttons[button] = $0 }
        )
    }
}

struct ButtonBindingRow: View {
    let button: ButtonID
    @Binding var action: OutputAction?

    var body: some View {
        HStack {
            Text(label(button)).frame(width: 90, alignment: .leading)
            Picker("", selection: kindBinding) {
                ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            if case .keystroke? = action {
                KeyRecorderButton(stroke: keystrokeBinding)
            }
        }
    }

    private var kindBinding: Binding<ActionKind> {
        Binding(
            get: { kind(of: action) },
            set: { action = makeAction(for: $0, existing: action) }
        )
    }

    private var keystrokeBinding: Binding<KeyStroke> {
        Binding(
            get: { if case .keystroke(let k)? = action { return k }; return KeyStroke(keyCode: 49) },
            set: { action = .keystroke($0) }
        )
    }

    private func label(_ b: ButtonID) -> String {
        switch b {
        case .dpadUp: return "D-pad ↑"
        case .dpadDown: return "D-pad ↓"
        case .dpadLeft: return "D-pad ←"
        case .dpadRight: return "D-pad →"
        default: return b.rawValue.uppercased()
        }
    }
}

struct KeyRecorderButton: View {
    @Binding var stroke: KeyStroke
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(recording ? "Press a key…" : stroke.displayString) {
            recording ? cancel() : start()
        }
        .frame(minWidth: 100)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            stroke = KeyStroke(keyCode: event.keyCode,
                               modifiers: modifierFlags(from: event.modifierFlags))
            cancel()
            return nil // swallow the key so it doesn't reach other UI
        }
    }

    private func cancel() {
        recording = false
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
```

- [ ] **Step 6: Add the Buttons section to SettingsView**

In `Sources/Slouch/SettingsView.swift`, replace the placeholder comment line:

```swift
            // The "Buttons" section is added in Task 12.
```

with:

```swift
            ButtonsSection(model: model)
```

- [ ] **Step 7: Build & run**

Run: `swift build && swift run Slouch`
Expected: Builds. Open Settings → "Buttons": each button shows an action picker. Set one to "Key…", click the recorder button, press a key combo, and confirm the button label updates (e.g. "⇧⌘Space").

- [ ] **Step 8: Verify persistence**

Change A to "Right click", quit Slouch, relaunch, reopen Settings.
Expected: A still shows "Right click" (written to `~/Library/Application Support/Slouch/config.json`).

- [ ] **Step 9: Commit**

```bash
git add Sources/SlouchCore/Model/Outputs.swift Tests/SlouchCoreTests/KeyStrokeDisplayTests.swift Sources/Slouch/ButtonBindingEditor.swift Sources/Slouch/SettingsView.swift
git commit -m "Add in-app button binding editor with key recorder"
```

---

## Task 13: Manual end-to-end verification on the real controller

No code changes — this validates the integrated app. Record results in the commit message.

- [ ] **Step 1: Grant Accessibility permission**

Run: `swift run Slouch`, open the menu, click "Open Accessibility Settings…", and add the `Slouch` binary (path printed by `swift build --show-bin-path`). Toggle it on. Back in the menu, confirm the warning is gone (use the menu's re-open to refresh).

- [ ] **Step 2: Verify mouse + click**

Connect the controller. Enable Slouch. Confirm: right stick moves the cursor (faster the harder you push), A clicks (links open), B right-clicks (context menu), left stick scrolls a long page.

- [ ] **Step 3: Verify keyboard mapping**

Set your voice/dictation app's global hotkey to ⌘⇧Space (the default Y binding). Press Y; confirm the voice app activates. Press D-pad in a text field; confirm arrow-key navigation.

- [ ] **Step 4: Verify sleep**

Press Menu; confirm the Mac sleeps.

- [ ] **Step 5: Verify the headline — wake self-heal**

With "Allow Bluetooth devices to wake this computer" enabled in System Settings, let the Mac sleep, then wake it by pressing a controller button. Confirm the cursor responds immediately **without** power-cycling the controller. (This exercises `WakeWatcher` → `rebind()`.)

- [ ] **Step 6: Commit the verification record**

```bash
git commit --allow-empty -m "Verify Slouch MVP end-to-end on Flydigi controller

- mouse move/scroll/click: OK
- keyboard mapping + voice hotkey: OK
- sleep on Menu: OK
- wake self-heal (no power-cycle needed): OK"
```

---

## Task 14 (optional): Launch at login

**Files:**
- Modify: `Sources/Slouch/AppModel.swift`
- Modify: `Sources/Slouch/SlouchApp.swift` (add a menu toggle)

- [ ] **Step 1: Add launch-at-login to AppModel**

Add to `AppModel` in `Sources/Slouch/AppModel.swift`:

```swift
import ServiceManagement
```

and inside the class:

```swift
    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled) {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
```

- [ ] **Step 2: Add the menu toggle**

In `MenuContent` (in `Sources/Slouch/SlouchApp.swift`), add below the Enabled toggle:

```swift
        Toggle("Launch at login", isOn: $model.launchAtLogin)
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: Builds. (Note: `SMAppService.mainApp` requires running from a real `.app` bundle to fully persist; verify after packaging in Xcode.)

- [ ] **Step 4: Commit**

```bash
git add Sources/Slouch/AppModel.swift Sources/Slouch/SlouchApp.swift
git commit -m "Add launch-at-login toggle"
```

---

## Notes for the implementer

- **Run the full unit suite often:** `swift test`. Tasks 2–7 must stay green.
- **`.app` packaging / signing:** `swift run` is fine for development. For a distributable build, create an Xcode app target (or a packaging script) that produces a signed `.app`; Accessibility permission attaches more cleanly to a stable bundle path than to the SwiftPM debug binary, which changes on rebuild.
- **If Accessibility seems granted but input is dropped after a rebuild:** the binary path changed; re-add it in Accessibility settings. This is a dev-only annoyance that bundling resolves.
- **D-pad key codes used:** 126 up, 125 down, 123 left, 124 right; 49 = space.
```
