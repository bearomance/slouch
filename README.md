# Slouch

> Control your Mac from the couch with a game controller.

Slouch is a macOS menu-bar app that turns a game controller into a Mac control
device. It's built for one scenario in particular: a Mac connected to a TV,
controlled from the couch with no keyboard or mouse in reach.

> **Status:** MVP implemented — all features below work and the unit suite is
> green. Pending real-hardware verification of the wake-self-heal path.

## Why

Lounging on the couch watching video on a TV-connected Mac, a game controller is
the natural input device. Existing controller-to-mouse tools work well, but tend
to share one flaw for this setup: after the controller wakes the Mac from sleep,
input doesn't work until you power-cycle the controller to force a reconnect.
That defeats the purpose of a couch remote.

Slouch's headline feature is **reliable wake**: press a button, the Mac wakes,
and the controller works immediately — no manual reconnect.

## Features (MVP)

- **Wake / sleep** — a button sleeps the Mac; waking with the controller works
  immediately thanks to automatic re-connect on wake.
- **Mouse control** — a thumbstick moves the cursor, a thumbstick scrolls,
  buttons left/right-click. (On a TV, clicking the video handles
  play/pause/fullscreen, so no media keys are needed.)
- **Keyboard mapping** — map any button to an arbitrary key or key-combo,
  including a one-button trigger for your dictation / voice-input app. Combos
  can be recorded from the keyboard or typed (e.g. `cmd+shift+space`, `F6`).
- **Open URL** — map a button to launch a site in your default browser
  (one button straight to your video site of choice).
- **In-app binding editor** — every button is re-bindable from the Settings
  window: pick Mouse / Keyboard / Function, then the detail.
- **Adjustable** — cursor speed, scroll speed, and stick dead zone, with ranges
  and recommended values shown.
- **Menu-bar app** — enable/disable and connection status at a glance.

## Requirements

- macOS 14 (Sonoma) or later.
- A game controller that macOS recognizes as a standard controller. Most modern
  Bluetooth controllers (Xbox-compatible, DualSense, etc.) work, since input is
  read through Apple's GameController framework.
- **Accessibility permission** must be granted (so the app can move the mouse and
  send keys). Slouch guides you through this on first run.
- To wake the Mac with the controller, enable **"Allow Bluetooth devices to wake
  this computer"** in System Settings (recent macOS enables this by default for
  paired input devices).
- The first sleep triggers a one-time **Automation** prompt (Slouch drives
  System Events to sleep the Mac) — allow it.

## How it works

Slouch reads the controller through Apple's **GameController** framework and
synthesizes mouse/keyboard input via **CGEvent**. On system wake it re-scans and
re-binds the controller automatically. See the
[design doc](docs/superpowers/specs) for the full architecture.

## Building

A native Swift / SwiftUI app built with SwiftPM (no Xcode project required).

```sh
swift test          # run the unit suite
./Scripts/build-app.sh   # build a signed Slouch.app menu-bar bundle
```

`build-app.sh` produces `./Slouch.app`. Launch it, then grant **Accessibility**
in System Settings ▸ Privacy & Security ▸ Accessibility so it can move the mouse
and send keys. Because the bundle is ad-hoc signed, macOS may re-prompt for
Accessibility after a rebuild.

No API keys, secrets, or network access are required — Slouch runs entirely
locally on free Apple frameworks.

## License

TBD.
