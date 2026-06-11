import SwiftUI
import QuartzCore
import ServiceManagement
import SlouchCore

@MainActor
final class AppModel: NSObject, ObservableObject {
    @Published var isEnabled = false { didSet { isEnabled ? start() : stop() } }
    @Published var isConnected = false
    @Published var controllerName: String?
    @Published var isReconnecting = false
    @Published var battery: GamepadBattery?
    @Published var availableUpdate: AvailableUpdate?
    @Published var isUpdating = false
    @Published var isTrusted = PermissionsManager.isTrusted()
    @Published var config: Config { didSet { applyConfig() } }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = oldValue
            }
        }
    }

    private let store = MappingStore()
    private let source: GamepadSource
    private let synth: OutputSynthesizer
    private let engine: MappingEngine
    private var wakeWatcher: WakeWatcher?
    private var displayLink: CADisplayLink?
    private var lastTick: CFTimeInterval = 0

    init(source: GamepadSource = GCGamepadSource(),
         synth: OutputSynthesizer = CGOutputSynthesizer()) {
        self.source = source
        self.synth = synth
        let loaded = store.load()
        self.config = loaded
        self.engine = MappingEngine(mapping: loaded.mapping, settings: loaded.settings)
        super.init()

        self.source.onConnectionChange = { [weak self] connected in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = connected
                self.controllerName = self.source.controllerName
                if connected { self.isReconnecting = false }
                self.updateBattery()
                self.updateDisplayLink()
            }
        }
        self.isConnected = source.isConnected
        self.controllerName = source.controllerName
        self.wakeWatcher = WakeWatcher { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isReconnecting = true
                self.source.rebind()
                if self.source.isConnected { self.isReconnecting = false }
            }
        }

        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.recheckPermission() }
            }

        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleScreenChange() }
            }

        if loaded.settings.enableOnLaunch {
            // didSet (and thus start()) doesn't fire for assignments inside init.
            Task { @MainActor [weak self] in self?.isEnabled = true }
        }

        updateBattery()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.updateBattery() }
        }

        checkForUpdate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.checkForUpdate() }
        }
    }

    private var batteryTimer: Timer?
    private var updateTimer: Timer?

    private func checkForUpdate() {
        guard config.settings.checkForUpdates else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.availableUpdate = await SelfUpdater.checkForUpdate()
        }
    }

    func installUpdate() {
        guard let update = availableUpdate, !isUpdating else { return }
        isUpdating = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await SelfUpdater.install(update) // terminates the app on success
            } catch {
                self.isUpdating = false
            }
        }
    }

    private func updateBattery() {
        let current = source.battery
        if current != battery { battery = current }
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
        // Match the user's keyboard repeat feel from System Settings.
        if NSEvent.keyRepeatDelay > 0 { engine.repeatInitialDelay = NSEvent.keyRepeatDelay }
        if NSEvent.keyRepeatInterval > 0 { engine.repeatInterval = NSEvent.keyRepeatInterval }
        updateDisplayLink()
    }

    private func stop() { stopDisplayLink() }

    // No controller → nothing to poll; don't spin the display link.
    private func updateDisplayLink() {
        if isEnabled && isConnected {
            if displayLink == nil { startDisplayLink() }
        } else {
            stopDisplayLink()
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = lastTick == 0 ? 1.0 / 60 : now - lastTick
        lastTick = now
        let commands = engine.process(state: source.currentState(), dt: dt)
        for command in commands {
            switch command {
            // Slight delay so trailing HID reports (e.g. an analog trigger
            // settling back) don't wake the Mac right after it sleeps.
            case .sleep:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { SystemActions.sleep() }
            case .openURL(let url): SystemActions.open(urlString: url)
            // ⌥⌘F5 is the system accessibility-shortcut toggle; with only
            // "Accessibility Keyboard" checked in Settings ▸ Accessibility ▸
            // Shortcut it toggles the on-screen keyboard directly.
            case .keyboardViewer:
                let stroke = KeyStroke(keyCode: 96, modifiers: [.command, .option])
                synth.perform(.keyDown(stroke))
                synth.perform(.keyUp(stroke))
            default: synth.perform(command)
            }
        }
    }

    private func startDisplayLink() {
        guard let link = NSScreen.main?.displayLink(target: self, selector: #selector(tick(_:)))
        else { return }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastTick = 0
    }

    // The link is bound to one screen; rebind when displays change (TV on/off).
    private func handleScreenChange() {
        guard displayLink != nil else { return }
        stopDisplayLink()
        updateDisplayLink()
    }

    deinit {
        displayLink?.invalidate()
        batteryTimer?.invalidate()
        updateTimer?.invalidate()
    }
}
