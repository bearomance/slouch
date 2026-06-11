# Media keys

Bind gamepad buttons to the Mac's media keys: Play/Pause, Next track,
Previous track, Volume up, Volume down, Mute.

## Why

Slouch exists for couch video watching; volume and play/pause are among the
highest-frequency operations in that scenario. Media keys are not regular
key codes — `keystroke` bindings cannot produce them. They require
`NX_SYSDEFINED` system events (the same events the keyboard driver posts for
the F7–F12 media functions).

This removes "media/volume keys" from the v1 out-of-scope list.

## Model (SlouchCore)

- `MediaKey: String, Codable, CaseIterable` — `playPause, nextTrack,
  previousTrack, volumeUp, volumeDown, mute`. Carries its NX key code
  (PLAY=16, NEXT=17, PREVIOUS=18, SOUND_UP=0, SOUND_DOWN=1, MUTE=7) and a
  `repeats` flag: true only for the volume keys. Mute toggles, so it must
  not repeat; play/next/previous have no hold semantics.
- `OutputAction.mediaKey(MediaKey)` — new case. Old config files decode
  unchanged; configs containing media keys are not readable by older builds
  (acceptable, same as any new action).
- `SynthCommand.mediaKey(MediaKey)` — one command per logical key press.

## Engine

On button just-pressed, emit `.mediaKey(key)` once. Release emits nothing —
the synthesizer sends a complete down+up pair per command, so a controller
disconnect can never leave a media key stuck down (the reason this design
was chosen over mirroring down/up like keystrokes).

Held volume keys re-fire through the existing repeat clock (same
delay/interval as keystroke repeat, which follows the system keyboard
settings). The repeat guard generalizes from "keystroke, non-modifier" to
"keystroke, non-modifier — or media key with `repeats == true`".

## Synthesizer

`NSEvent.otherEvent(with: .systemDefined, subtype: 8 /* AUX_CONTROL_BUTTONS */,
data1: nxKeyCode << 16 | 0xA00 (down) / 0xB00 (up))`, posted via `.cgEvent`
to the HID event tap. Down then up, back to back.

## UI

`ButtonBindingEditor` gains a "Media" action category; the value cell is a
six-item picker (Play / Pause, Next track, Previous track, Volume up,
Volume down, Mute). Switching a button to the category defaults to
Play / Pause.

## Testing

Unit (pure logic): press emits exactly one `.mediaKey`; release emits
nothing; held volume key repeats on the engine clock; held Play/Pause never
repeats; `Config` round-trips through JSON with a media-key binding.

Manual: bind volume up/down/mute/play-pause, verify against a playing video,
including the on-screen volume HUD and hold-to-repeat feel.
