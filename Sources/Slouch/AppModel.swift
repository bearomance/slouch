import SwiftUI
import QuartzCore
import ServiceManagement
import SlouchCore

@MainActor
final class AppModel: ObservableObject {
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
    private var displayLink: CVDisplayLink?
    private var lastTick: CFTimeInterval = 0

    init(source: GamepadSource = GCGamepadSource(),
         synth: OutputSynthesizer = CGOutputSynthesizer()) {
        self.source = source
        self.synth = synth
        let loaded = store.load()
        self.config = loaded
        self.engine = MappingEngine(mapping: loaded.mapping, settings: loaded.settings)

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

    private func tick() {
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
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, ctx in
            let model = Unmanaged<AppModel>.fromOpaque(ctx!).takeUnretainedValue()
            Task { @MainActor in model.tick() }
            return kCVReturnSuccess
        }, userInfo)
        CVDisplayLinkStart(link)
        displayLink = link
    }

    private func stopDisplayLink() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
        lastTick = 0
    }

    deinit {
        if let link = displayLink { CVDisplayLinkStop(link) }
        batteryTimer?.invalidate()
        updateTimer?.invalidate()
    }
}
