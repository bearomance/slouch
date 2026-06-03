# Slouch

> Control your Mac from the couch with a game controller.

Slouch is a macOS menu-bar app that turns a game controller into a Mac control
device. It's built for one scenario in particular: a Mac connected to a TV,
controlled from the couch with no keyboard or mouse in reach.

> **Status:** Early development. The design is complete (see
> [`docs/superpowers/specs`](docs/superpowers/specs)); implementation is in
> progress.

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
  including a one-button trigger for your dictation / voice-input app.
- **Adjustable** — cursor speed and stick dead zone.
- **Menu-bar app** — enable/disable and connection status at a glance.

## Requirements

- macOS 13 (Ventura) or later.
- A game controller that macOS recognizes as a standard controller. Most modern
  Bluetooth controllers (Xbox-compatible, DualSense, etc.) work, since input is
  read through Apple's GameController framework.
- **Accessibility permission** must be granted (so the app can move the mouse and
  send keys). Slouch guides you through this on first run.
- To wake the Mac with the controller, enable **"Allow Bluetooth devices to wake
  this computer"** in System Settings.

## How it works

Slouch reads the controller through Apple's **GameController** framework and
synthesizes mouse/keyboard input via **CGEvent**. On system wake it re-scans and
re-binds the controller automatically. See the
[design doc](docs/superpowers/specs) for the full architecture.

## Building

A native Swift / SwiftUI app, built with Xcode. (Build instructions will be added
as the project structure lands.)

No API keys, secrets, or network access are required — Slouch runs entirely
locally on free Apple frameworks.

## License

TBD.
