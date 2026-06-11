import GameController
import SlouchCore

final class GCGamepadSource: GamepadSource {
    private var controller: GCController?
    var onConnectionChange: ((Bool) -> Void)?

    var isConnected: Bool { controller?.extendedGamepad != nil }

    var controllerName: String? { controller?.vendorName }

    var battery: GamepadBattery? {
        guard let b = controller?.battery, b.batteryLevel >= 0,
              b.batteryState != .unknown else { return nil }
        return GamepadBattery(level: Double(b.batteryLevel),
                              isCharging: b.batteryState == .charging)
    }

    init() {
        // LSUIElement apps are never frontmost; without this the framework drops all input.
        GCController.shouldMonitorBackgroundEvents = true
        bind()
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.bind()
        }
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            // BT reconnect can replay a stale disconnect after the new connect;
            // ignore it unless it's for the controller we're actually using.
            if let gone = note.object as? GCController, gone !== self.controller { return }
            self.bind()
        }
    }

    private var motionEnabled = false

    func setMotionEnabled(_ enabled: Bool) {
        motionEnabled = enabled
        applyMotionState()
    }

    // sensorsActive is per-GCController state; re-apply on every bind.
    private func applyMotionState() {
        guard let motion = controller?.motion, motion.hasRotationRate else { return }
        motion.sensorsActive = motionEnabled
    }

    private func bind() {
        controller = GCController.controllers().first { $0.extendedGamepad != nil }
        applyMotionState()
        onConnectionChange?(isConnected)
    }

    func rebind() {
        controller = nil
        bind()
        // Restart wireless discovery in case the link came back without a connect event.
        GCController.startWirelessControllerDiscovery {}
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

        var rotation: RotationRate?
        if let motion = controller?.motion, motion.sensorsActive, motion.hasRotationRate {
            rotation = RotationRate(x: motion.rotationRate.x,
                                    y: motion.rotationRate.y,
                                    z: motion.rotationRate.z)
        }

        return GamepadState(
            leftStick: StickVector(x: Double(pad.leftThumbstick.xAxis.value),
                                   y: Double(pad.leftThumbstick.yAxis.value)),
            rightStick: StickVector(x: Double(pad.rightThumbstick.xAxis.value),
                                    y: Double(pad.rightThumbstick.yAxis.value)),
            pressed: pressed,
            rotationRate: rotation)
    }
}
