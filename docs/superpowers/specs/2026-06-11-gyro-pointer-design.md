# Gyro pointer

Hold a bound button and turn the controller to steer the cursor, like
pointing a laser pen. Release and the gyro stops. Developed on the
`gyro-pointer` branch; merges to master only after field validation.

Target hardware: Switch Pro (the user's controller). Feasibility via the
GameController framework is confirmed by SDL's macOS backend: gate on
`motion.hasRotationRate`, set `motion.sensorsActive = true` (off by
default — no data otherwise), read `motion.rotationRate` in radians/sec.
macOS has a known Switch-gyro axis-inversion bug (SDL #14751), so the
default axis signs must be verified on real hardware and invert toggles are
part of the design, not an afterthought.

## Activation

Never always-on. New `OutputAction.gyroPointer` — a hold-style action like
`.precision`: gyro output only while the button is held. Holding Precision
Cursor at the same time slows the gyro cursor by the same factor.

## Pipeline (pure logic, `SlouchCore/Engine/GyroPointer.swift`)

Algorithm follows the gyromouse / JoyShockMapper lineage:

1. **Bias calibration** — average `rotationRate` over the first ~1s of
   samples (controller assumed still right after connect); output is zero
   while calibrating. Recalibrated on every connect/rebind (so also after
   wake). While running, whenever the rate sits below a stillness threshold
   (~1°/s) the bias slowly tracks it (EMA), absorbing temperature drift —
   and still samples produce no cursor motion (doubles as the drift gate).
2. **Axis mapping** — local space: yaw (rotation about the controller's
   vertical axis) → cursor x, pitch → cursor y. Default signs: turn right →
   cursor right, tilt up → cursor up; per-axis invert toggles in settings.
   Player-space mapping (gravity-blended yaw+roll) is out of scope for v1.
3. **Tightening** — below ~5°/s, motion scales linearly toward zero
   (hands are never perfectly still); above the threshold rotation passes
   through unfiltered (smoothing fast motion is pure latency).
4. **Sensitivity** — `gyroSensitivity` in px per degree of rotation,
   default 50 (45° turn ≈ 2250 px, roughly one screen width), range 10–150.

## Engine integration

`MappingEngine` feeds every tick's `rotationRate` (new optional field on
`GamepadState`) to the `GyroPointer` regardless of button state, so
calibration and drift tracking always run. Only while the bound button is
held does the result become a `.moveMouse` command. `resetGyroCalibration()`
is called by the app on every connect/rebind.

## App layer

- `GamepadSource` gains `setMotionEnabled(_:)` (default no-op).
  `GCGamepadSource` applies it as `motion.sensorsActive` on the bound
  controller (re-applied on every bind). `AppModel` enables it only when
  the mapping actually binds Gyro Pointer — the IMU costs controller
  battery, so it stays off otherwise.
- `currentState()` carries `rotationRate` only when sensors are active.
- UI: "Gyro Pointer" joins the Function category in the Buttons editor.
  General tab gains a Gyro pointer section: sensitivity slider and
  horizontal/vertical invert toggles.

## Settings

`gyroSensitivity` (50), `gyroInvertX` (false), `gyroInvertY` (false) —
decoded with defaults so old configs load unchanged.

## Testing

Unit (pure core): zero output during calibration; constant bias removed
after calibration; post-calibration motion passes through at the right
scale and sign; sub-threshold motion tightened; still-state drift absorbed;
reset restarts calibration. Engine: gyro moves the cursor only while the
bound button is held; sensitivity and inverts apply; no rotationRate → no
output.

Manual (field): axis directions on real Switch Pro hardware (macOS
inversion bug), drift after 10+ minutes, calibration after wake, feel of
the sensitivity default.
