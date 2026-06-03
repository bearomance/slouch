import SwiftUI
import QuartzCore
import SlouchCore

@MainActor
final class AppModel: ObservableObject {
    @Published var isEnabled = false { didSet { isEnabled ? start() : stop() } }
    @Published var isConnected = false
    @Published var isReconnecting = false
    @Published var isTrusted = PermissionsManager.isTrusted()
    @Published var config: Config { didSet { applyConfig() } }

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
                self?.isConnected = connected
                if connected { self?.isReconnecting = false }
            }
        }
        self.isConnected = source.isConnected
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
        startDisplayLink()
    }

    private func stop() { stopDisplayLink() }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = lastTick == 0 ? 1.0 / 60 : now - lastTick
        lastTick = now
        let commands = engine.process(state: source.currentState(), dt: dt)
        for command in commands {
            if case .sleep = command { SystemActions.sleep() } else { synth.perform(command) }
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
    }
}
