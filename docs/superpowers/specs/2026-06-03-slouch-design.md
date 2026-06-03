# Slouch — Design

**Tagline:** Control your Mac from the couch with a game controller.

**Date:** 2026-06-03
**Status:** Design approved pending user review

## Problem

Watching video on a Mac that is connected to a TV means controlling the Mac
from the couch with no keyboard or mouse in reach. A game controller is the
natural couch input device. Existing tools (e.g. reControl) map a controller to
mouse/keyboard well, but have a critical flaw for this use case: after the
controller wakes the Mac from sleep, input does not work until the user power-
cycles the controller to force a reconnect. For a couch/TV setup that defeats
the whole point.

## Goal

A macOS menu-bar app that turns a game controller into a Mac control device,
optimized for lounging on the couch watching video. The headline differentiator
is **reliable wake**: pressing a button wakes the Mac and the controller works
immediately, with no manual reconnect.

## Target device & framework

- Primary device: Flydigi Black Warrior 4 Pro, which connects over Bluetooth and
  is recognized by macOS as an Xbox-compatible controller.
- Input is read through Apple's **GameController** framework
  (`GCController` / `GCExtendedGamepad`), which exposes the standardized Xbox
  layout: two analog thumbsticks (+ L3/R3 clicks), D-pad, A/B/X/Y, LB/RB,
  analog LT/RT, Menu, Options.
- **Non-goal:** controller-specific extras (paddles, macro keys, gyro). They are
  not surfaced by GameController when the device presents as a generic Xbox
  controller. Users who want those map them to standard buttons in the
  controller's own firmware.

## Use-case-driven scope

Because the Mac drives a TV, several "obvious" features are unnecessary:

- **Play/pause/fullscreen** are done by clicking on the video itself → covered by
  mouse move + click. No media-key mapping needed.
- **Volume** is controlled by the TV remote, not the Mac → no volume keys.

This collapses the MVP to two pillars: **mouse control** and **wake/sleep**,
plus a keyboard-mapping capability (mainly to trigger voice input for searching).

## MVP feature set

1. **Wake / sleep**
   - A mapped button puts the Mac to sleep.
   - The Mac is woken by the controller via the OS Bluetooth-wake path (requires
     "Allow Bluetooth devices to wake this computer" in System Settings; the app
     documents and surfaces this).
   - **Wake self-heal** (the headline): on system wake, the app re-scans
     controllers and re-binds input handlers automatically, so input works
     immediately without power-cycling the controller.
2. **Mouse control**
   - A thumbstick moves the cursor (push further → move faster).
   - A thumbstick scrolls.
   - Buttons for left / right click.
3. **Keyboard mapping**
   - Any gamepad button → an arbitrary key or key-combo (modifiers + key).
   - This is how "one-button voice input" works: map a button to the global
     hotkey of the user's voice/dictation app.
4. **Sensitivity** — adjustable cursor speed and stick dead zone.
5. **Mapping UI** — a single editable mapping (gamepad input → output action).
   No multi-profile system.
6. **Menu-bar app** — enable/disable toggle and connection status.

### Explicit non-goals (YAGNI for v1)

- Multiple switchable mapping profiles (single mapping only).
- Response-curve editor, 8-way thumbstick mode, drift calibration.
- Media keys, volume keys.
- Relative-mouse / mouse-lock mode (for FPS games).
- Gyro, rumble, controller LED control.

These can be revisited in a v2 if the core proves useful.

## Architecture

Native macOS app, **Swift + SwiftUI**, menu-bar-only (`LSUIElement`, no Dock
icon). The system is decomposed into focused units with clear interfaces so each
can be reasoned about and tested independently.

```
GameController framework
        │  raw controller callbacks
        ▼
┌──────────────────┐     wake notification    ┌──────────────┐
│  GamepadSource   │◀─────────────────────────│  WakeWatcher │
│ (discover, bind, │                          └──────────────┘
│  normalized state)│
└────────┬─────────┘
         │  normalized input (button events + stick/trigger values)
         ▼
┌──────────────────┐     active mapping     ┌──────────────┐
│  MappingEngine   │◀───────────────────────│ MappingStore │
│ (translate input │                        │ (persist)    │
│  → output actions,│                       └──────────────┘
│  drive move loop) │
└────────┬─────────┘
         │  abstract output actions
         ▼
┌──────────────────┐
│OutputSynthesizer │ ── CGEvent ──▶ macOS (mouse move/click/scroll, keystrokes)
└──────────────────┘

SystemActions ── sleep ──▶ macOS power management
PermissionsManager ── checks/guides Accessibility grant
SwiftUI UI ── menu bar + settings window
```

### Units

- **GamepadSource** — wraps GameController. Discovers connected controllers,
  observes connect/disconnect, and exposes a normalized input interface:
  per-frame stick/trigger values and button up/down events. Exposes a
  `rebind()` method that tears down and re-establishes controller observation
  and input handlers (used by wake self-heal). Defined behind a protocol so the
  MappingEngine can be driven by a synthetic source in tests.

- **WakeWatcher** — subscribes to `NSWorkspace.shared.notificationCenter`
  `didWakeNotification` (and sleep notification for symmetry/logging). On wake,
  calls `GamepadSource.rebind()`. Its handler is directly invokable for tests.

- **MappingEngine** — owns the active `Mapping`. Two responsibilities:
  (a) on button events, look up the bound output action and fire it via
  OutputSynthesizer; (b) run a high-frequency move loop (display-linked, ~display
  refresh rate) that reads the move/scroll sticks, applies dead zone + speed,
  and emits cursor-move / scroll actions. Enable/disable gates all output.

- **OutputSynthesizer** — turns abstract output actions into `CGEvent`s:
  mouse move (by delta, clamped to screen bounds), mouse button down/up, scroll,
  and keystroke (virtual keycode + modifier flags). Defined behind a protocol;
  tests inject a fake to assert which actions were emitted.

- **MappingStore** — persists the `Mapping` and sensitivity settings as Codable
  JSON in Application Support. Loads a sensible default "couch" mapping on first
  run.

- **SystemActions** — triggers system sleep (via AppleScript
  `tell application "System Events" to sleep`, which needs no admin rights;
  `pmset sleepnow` is the fallback).

- **PermissionsManager** — checks Accessibility trust (`AXIsProcessTrusted`).
  Posting mouse/keyboard CGEvents requires the app to be granted Accessibility
  permission. If not granted, the app surfaces a banner with a button to open
  the relevant System Settings pane and disables output until granted.

- **UI (SwiftUI)** — `MenuBarExtra` with an enable/disable toggle and status
  (controller connected? permission granted?). A settings window with: the
  sensitivity + dead-zone sliders, and a mapping editor listing each gamepad
  input with its assigned output (mouse move / scroll / click / keystroke /
  sleep). Launch-at-login via `SMAppService` (a simple toggle; optional for v1).

### Data model (mapping)

- **Inputs:** `leftStick`, `rightStick` (as move/scroll sources), D-pad
  up/down/left/right, A/B/X/Y, LB/RB, LT/RT, L3/R3, Menu, Options.
- **Output actions:**
  - `mouseMove(stick)` — assign a stick to drive the cursor.
  - `scroll(stick)` — assign a stick to scroll.
  - `mouseButton(left | right | middle)`
  - `keystroke(keyCode, modifiers)` — covers voice trigger, arrows, Enter, Esc…
  - `system(sleep)`
- **Default "couch" mapping:**
  - Right stick → mouse move
  - Left stick → scroll
  - A → left click
  - B → right click
  - Y → voice-input hotkey (user sets the combo to match their voice app)
  - Menu → sleep
  - D-pad → arrow keys (handy for some video UIs)

### Sensitivity model

- One **cursor speed** slider (max px/sec at full stick deflection).
- One **dead zone** slider (radial dead zone, default ~5%) — important on the
  couch because resting-stick drift would otherwise make the cursor wander.
- A mild fixed acceleration curve is baked in (no user-facing curve editor in
  v1).

## Error handling

- **No Accessibility permission** — detected via `AXIsProcessTrusted`; output is
  disabled, a banner guides the user to grant it, and the app re-checks when it
  regains focus.
- **No controller connected** — status shows "No controller"; the move loop is
  idle.
- **Controller disconnects mid-use** — status updates; output pauses until
  reconnect.
- **Wake** — `rebind()` runs on wake; if no controller is bound within a few
  seconds, the status reflects "reconnecting" so the failure is visible rather
  than silent.
- **Bluetooth-wake not enabled** — cannot be fully auto-detected; documented and
  surfaced as a setup hint, since without it the controller can't wake the Mac
  at all.

## Testing strategy

- **Pure logic (unit tests):** dead-zone math, stick→velocity/speed mapping, and
  the MappingEngine's translation of a given gamepad state into a list of output
  actions. These are pure functions.
- **OutputSynthesizer** behind a protocol → inject a fake in tests to assert
  "left click emitted", "moved by (dx, dy)", "keystroke X+mods emitted".
- **GamepadSource** behind a protocol → drive MappingEngine with synthetic input
  in tests, no hardware needed.
- **WakeWatcher** → invoke its wake handler directly and assert `rebind()` is
  called.
- **Manual integration checklist** on the real device: connect, move/scroll/
  click, voice-trigger fires the hotkey, sleep button sleeps, and the key
  scenario — wake the Mac with the controller and confirm input works
  immediately with no power-cycle.

## Open questions (resolve during planning)

- Exact mechanism for smooth cursor motion: `CGWarpMouseCursorPosition` +
  posted `mouseMoved` event vs. accumulating position and posting absolute
  moves. To be validated for smoothness during implementation.
- Whether launch-at-login ships in v1 or v2.
