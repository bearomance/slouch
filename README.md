# Slouch

> Control your Mac from the couch with a game controller.

Slouch is a macOS menu-bar app that turns a game controller into a Mac control
device. It's built for one scenario in particular: a Mac connected to a TV,
controlled from the couch with no keyboard or mouse in reach.

## Why

Lounging on the couch watching video on a TV-connected Mac, a game controller is
the natural input device. Existing controller-to-mouse tools work well, but tend
to share one flaw for this setup: after the controller wakes the Mac from sleep,
input doesn't work until you power-cycle the controller to force a reconnect.
That defeats the purpose of a couch remote.

Slouch's headline feature is **reliable wake**: press a button, the Mac wakes,
and the controller works immediately — no manual reconnect. (Field-tested
against the alternatives.)

## Install

Grab `Slouch.app.zip` from the [latest release](https://github.com/bearomance/slouch/releases),
unzip, and launch. On first run:

1. Grant **Accessibility** in System Settings ▸ Privacy & Security ▸
   Accessibility (so Slouch can move the mouse and send keys). Release builds
   are signed with a stable identity, so upgrades keep the grant.
2. The first sleep triggers a one-time **Automation** prompt (Slouch drives
   System Events to sleep the Mac) — allow it.

## Features

- **Wake / sleep** — a button sleeps the Mac; waking with the controller works
  immediately thanks to automatic re-bind on wake.
- **Mouse control** — one stick moves the cursor, the other scrolls; buttons
  left/right/middle-click, with real double-click support. Holding a click and
  moving the stick drags.
- **Keyboard mapping** — map any button (including stick clicks) to a key or
  combo. Record it from the keyboard or type it (`cmd+shift+space`, `F6`).
  Held buttons auto-repeat like a real keyboard.
- **Bare modifier keys** — bind a button to just ⌘ / ⌥ / ⇧ / ⌃ (left and right
  distinguished), e.g. hold-to-talk on Right Option.
- **System functions** — sleep, open a URL in the default browser, toggle the
  macOS Accessibility Keyboard.
- **Menu-bar app** — enable/disable, connection status, controller battery
  (when the controller reports it), and the build version at a glance.
- **Adjustable** — cursor speed, scroll speed, scroll direction, and stick
  dead zone.

## Requirements

- macOS 14 (Sonoma) or later.
- A game controller that macOS recognizes as a standard controller. Most modern
  Bluetooth controllers (Xbox-compatible, DualSense, etc.) work, since input is
  read through Apple's GameController framework.
- To wake the Mac with the controller, enable **"Allow Bluetooth devices to wake
  this computer"** in System Settings (recent macOS enables this by default for
  paired input devices).

## How it works

Slouch reads the controller through Apple's **GameController** framework and
synthesizes mouse/keyboard input via **CGEvent**. On system wake it re-scans and
re-binds the controller automatically. See the
[design doc](docs/superpowers/specs) for the full architecture.

No API keys or secrets — Slouch runs locally on free Apple frameworks. The
only network access is a daily update check against GitHub releases (one-click
in-app update; can be turned off in General settings).

## Building

A native Swift / SwiftUI app built with SwiftPM (no Xcode project required).

```sh
swift test               # run the unit suite
./Scripts/build-app.sh   # package a signed Slouch.app menu-bar bundle
```

`build-app.sh` signs with the `Slouch Code Signing` keychain identity when
present and falls back to ad-hoc signing (ad-hoc builds re-prompt for
Accessibility after every rebuild).

## License

[MIT](LICENSE).
