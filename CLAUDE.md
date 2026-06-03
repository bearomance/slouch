# CLAUDE.md

Guidance for working in the Slouch codebase.

## What this is

Slouch is a macOS menu-bar app that turns a game controller into a Mac control
device, optimized for couch/TV video watching. Headline feature: reliable wake
self-heal. Full design lives in
[`docs/superpowers/specs/2026-06-03-slouch-design.md`](docs/superpowers/specs/2026-06-03-slouch-design.md)
— read it before making design decisions.

## Tech stack

- Native **Swift + SwiftUI**, menu-bar-only app (`LSUIElement`, no Dock icon).
- **GameController** framework (`GCController` / `GCExtendedGamepad`) for input.
- **CGEvent** (Core Graphics) for synthesizing mouse/keyboard output.
- macOS 14+ (`MenuBarExtra`, `SettingsLink`).
- No network, no API keys, no secrets. Everything runs locally.

## Architecture

Decomposed into focused, independently testable units (see spec for the
diagram):

- `GamepadSource` — wraps GameController; discovery, connect/disconnect,
  normalized input. Exposes `rebind()` for wake recovery. Behind a protocol.
- `WakeWatcher` — listens for `NSWorkspace` wake notifications; calls
  `rebind()` on wake.
- `MappingEngine` — translates gamepad input → output actions; runs the
  display-linked cursor-move loop.
- `OutputSynthesizer` — emits CGEvents (mouse move/click/scroll, keystrokes).
  Behind a protocol so tests can assert emitted actions.
- `MappingStore` — persists the single mapping + sensitivity as Codable JSON.
- `SystemActions` — system sleep (AppleScript) and open-URL (NSWorkspace).
- `PermissionsManager` — Accessibility trust check + guidance.
- SwiftUI UI — `MenuBarExtra` + settings window (General / Buttons tabs;
  `ButtonBindingEditor` with key recorder and typed-combo entry via
  `KeyStroke.parse`).

## Build & run

- `swift test` — full unit suite (pure-logic core; no hardware needed).
- `swift build` — compile everything including the app target.
- `./Scripts/build-app.sh` — package a signed `Slouch.app` (menu-bar bundle).
- Do NOT `swift run Slouch` from an agent session — it blocks on the GUI event
  loop. Use `open ./Slouch.app` after packaging instead.

## Conventions

- Keep units small and single-purpose; communicate through protocols so input
  and output can be faked in tests. Prefer pure functions for dead-zone /
  speed / mapping-translation logic.
- Comments: only for non-obvious *why* (an invariant, a workaround). Don't
  narrate what the code does — names and the spec carry that.
- Match surrounding style for naming and structure.
- Gotcha: `OutputAction.none` collides with `Optional.none`. In a `switch` over
  `OutputAction?`, a bare `.none` pattern matches `nil`, not the enum case —
  write `OutputAction.none?` / `.some(.none)` explicitly. This has caused
  repeated compile errors; check any new switch over an optional action.

## Testing

- Unit-test the pure logic: dead-zone math, stick→speed, mapping translation.
- Inject a fake `OutputSynthesizer` to assert which actions were emitted; drive
  `MappingEngine` with a synthetic `GamepadSource`.
- The wake-self-heal path is the most important manual check: wake the Mac with
  the controller and confirm input works immediately, no power-cycle.

## Scope discipline

v1 is intentionally minimal. Out of scope unless the spec changes: multiple
mapping profiles, response-curve editor, 8-way thumbstick mode, drift
calibration, media/volume keys, relative-mouse mode, gyro/rumble.
