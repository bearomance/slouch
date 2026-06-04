# Similar projects: gamepad→keyboard/mouse mappers (research notes)

Surveyed 2026-06-04 to learn from prior art. Source-level findings below; no
code copied (see licensing note on ControllerKeys).

## The landscape

| Project | Stack | Input layer | Status / notes |
|---|---|---|---|
| [Enjoyable](https://github.com/dragonfax/enjoyable) / [enjoyable-silicon](https://github.com/pedroh77/enjoyable-silicon) | Obj-C | IOKit HID | The 2013 classic; silicon fork is build/UI modernization only |
| [ControllerKeys](https://github.com/NSEvent/xbox-controller-mapper) | Swift/SwiftUI | GameController + IOKit HID supplements | Feature-richest by far. **Source-available, NOT open source** — paid binary; study only, never copy code |
| [dualsense-controller-mapper](https://github.com/aklmans/dualsense-controller-mapper) | — | — | Just a fork of ControllerKeys |
| [AntiMicroX](https://github.com/AntiMicroX/antimicrox) | C++/Qt/SDL | SDL | Mature cross-platform; macOS second-class |
| [JoyKeyMapper](https://github.com/magicien/JoyKeyMapper) / [JoyMapperSilicon](https://github.com/qibinc/JoyMapperSilicon) | Swift | Raw HID via JoyConSwift | Switch-only; enables IMU but ships no gyro pointer |
| [gyromouse](https://github.com/Yamakaky/gyromouse) | Rust | SDL | JoyShockMapper-lineage gyro algorithms, best reference for gyro math |

## Wake self-heal is a validated differentiator

- Enjoyable has **zero** sleep/wake/reconnect handling — no `didWakeNotification`
  observer, no rebind path. Recovery is left entirely to IOKit re-enumeration.
- ControllerKeys handles wake but still shipped bugs here (their issue #12
  "Reconnect controller via bluetooth breaks button mappings").
- AntiMicroX has recurring reconnect complaints (#810/#821/#663) and even a
  "tray app prevents system sleep" regression (#1326).

Slouch's proactive `WakeWatcher → rebind()` is more robust than what any of
them ship. Keep it the headline.

## Bug risk found in our own code

macOS may **reuse the same `GCController` object during Bluetooth reconnect
and deliver `didDisconnect` AFTER `didConnect`** (documented in ControllerKeys
source comments; their defense is checking `GCController.controllers()` still
contains the pad before tearing down, plus a connection-generation counter).

`GCGamepadSource` currently nils `controller` unconditionally on the
disconnect notification — in the out-of-order case we would kill a live,
freshly reconnected controller. Fix: on disconnect, re-run `bind()` (or check
the system list) instead of unconditional teardown. This sits on the
wake-self-heal critical path.

## Key repeat (backlog item) — design parameters from the field

- ControllerKeys models **two distinct semantics**, both per-button
  `DispatchSourceTimer`, cancelled on release:
  - *turbo*: re-run the full press (down+up) each tick; default interval 0.2s
  - *hold-repeat*: re-post **keyDown only** (what apps watching key-down
    streams expect); default interval 0.033s
- AntiMicroX: per-binding toggle, default 100ms when enabled, floor 10ms.
- Enjoyable has none (open feature requests on both forks confirm demand).

Plan for Slouch: hold-repeat semantics (re-send keyDown), ~400ms initial
delay + ~80ms interval, keystroke bindings only (mouse hold = drag must stay;
Function actions don't repeat).

## Gyro pointer (if/when spec admits it) — full pipeline

Feasibility on Switch Pro via GameController framework is **confirmed by
SDL's macOS backend** (`SDL_mfijoystick.m`): gate on `motion.hasRotationRate`,
set `motion.sensorsActive = true` (defaults off — no data otherwise), read
`motion.rotationRate` in **radians/sec**. Known macOS bug: Switch gyro axes
inverted/inaccurate (SDL #14751, #13197) → expose invert-X/Y toggles and
verify signs on real hardware. JoyKeyMapper is *not* GCMotion evidence — it
uses raw HID (JoyConSwift) and never shipped a gyro pointer.

Algorithm (gyromouse / JoyShockMapper lineage):

1. **Calibrate bias**: average rotationRate while still (~1s) on connect —
   and re-calibrate on every `rebind()` after wake. Optionally continuous
   recalibration whenever the pad is detected still (Δrot < 1°/s).
2. **Axis mapping**: local space = yaw→x, pitch→y (simplest); player space
   blends yaw+roll via the gravity up-vector so it feels right regardless of
   grip — recommended for couch use.
3. **Noise**: tiered smoothing — only smooth below a threshold (~5°/s),
   fast motion passes through unfiltered (smoothing above threshold = pure
   latency). Plus "tightening": scale tiny motions quadratically toward zero.
   ControllerKeys instead uses a 1€ filter per axis; either works.
4. **Sensitivity**: for a 2D cursor use gyro-sens ≥ 8 (8 → 45° of controller
   turn = full screen width); cubic sensitivity curve feels right.
5. **Sub-pixel residual accumulation** before rounding to integer pixels
   (we already do this for scroll).
6. **Activation**: never always-on. Hold-a-clutch-button model ("gyro on
   while held", or inverted "gyro off while held" = the mouse-lift gesture).

## Smaller things worth stealing

- **Record modifier-only keys**: monitor `.flagsChanged` alongside `.keyDown`
  during recording; track the *peak* modifier set; when all modifiers release
  without a regular key, bind the peak as a modifier-only stroke. Would let
  the Record button capture a bare right-Option instead of requiring typed
  `ropt`.
- **Double-click synthesis**: two fast synthesized clicks read as two single
  clicks — macOS needs `.mouseEventClickState = 2`. Track per-button click
  times (~0.5s window) and set the field. Couch double-click is a real need.
- **Modifier flags on scroll events**: held modifiers should be unioned onto
  synthesized scroll events or ⌘-scroll-zoom style gestures won't work.
- **Mouse event correlation**: set `.mouseEventNumber` consistently across
  down/drag/up of one gesture (some apps correlate by it).
- **Perf notes**: `CGEvent.post` IPC is the dominant CPU cost; never use
  `CGWarpMouseCursorPosition` alongside it. 120Hz DispatchSourceTimer was
  enough for ControllerKeys (display UI refresh decoupled and throttled).
  Consider idling our display-link loop when sticks are centered and nothing
  is held.
- **Forward-compatible Codable**: explicit `CodingKeys` + `decodeIfPresent`
  with defaults everywhere (we already do this in `Settings`) — validated as
  the right pattern for config schema growth.

## Deliberately not chasing (scope discipline)

Per-app profile switching, layers/chords/macros, on-screen keyboard with
swipe typing, radial command wheels, touchpad emulation, scripting. All
validated as v2+ territory by ControllerKeys' feature list; none of it serves
the couch-video v1 spec.
