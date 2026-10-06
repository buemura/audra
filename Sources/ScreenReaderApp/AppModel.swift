import AppKit
import Combine
import CoreGraphics
import KeyboardShortcuts
import ScreenReaderCore
import ScreenReaderKokoro

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let speech: SpeechController
    let modelStore: KokoroModelStore
    @Published private(set) var hasAccessibilityPermission = AccessibilityPermission.isGranted
    @Published private(set) var voices: [VoiceInfo]

    private let coordinator: ReadSelectionCoordinator
    private let kokoroEngine: MLXKokoroEngine
    private var permissionTimer: Timer?
    private var playerPanel: PlayerPanelController?
    private var modelStateSubscription: AnyCancellable?

    init() {
        let settings = SettingsStore()
        let modelStore = KokoroModelStore(
            directory: Self.modelDirectory,
            assets: KokoroModelAssets.all,
            downloader: URLSessionModelDownloader()
        )
        let kokoroEngine = MLXKokoroEngine(
            modelURL: modelStore.url(for: KokoroModelAssets.modelFileName),
            voicesURL: modelStore.url(for: KokoroModelAssets.voicesFileName)
        )
        let languageDetector = NLLanguageDetector()
        let synthesizer = RoutingSynthesizer(
            system: AVSpeechSynthesizerAdapter(),
            kokoro: KokoroSynthesizer(
                engine: kokoroEngine,
                output: AVAudioEngineOutput(),
                phonemizer: KokoroPhonemizers.phonemizer(for:)
            ),
            fallbackVoiceID: { text in
                Self.systemVoice(for: text, settings: settings, languageDetector: languageDetector)
            }
        )
        let speech = SpeechController(synthesizer: synthesizer)
        let availableVoices: () -> [VoiceInfo] = { [unowned modelStore] in
            Self.allVoices(modelReady: modelStore.state == .ready)
        }
        let textSource = FirstAvailableTextSource([
            AccessibilityTextSource(),
            ClipboardTextSource(
                pasteboard: SystemPasteboard(),
                copySender: CopyKeySender(),
                modifiersHeld: {
                    !CGEventSource.flagsState(.hidSystemState)
                        .intersection([.maskAlternate, .maskShift, .maskControl, .maskCommand])
                        .isEmpty
                }
            ),
        ])
        self.settings = settings
        self.speech = speech
        self.modelStore = modelStore
        self.kokoroEngine = kokoroEngine
        voices = availableVoices()
        coordinator = ReadSelectionCoordinator(
            textSource: textSource,
            speech: speech,
            settings: settings,
            languageDetector: languageDetector,
            availableVoices: availableVoices,
            onNoText: { NSSound.beep() }
        )

        KeyboardShortcuts.onKeyUp(for: .readSelection) { [weak self] in
            Task { @MainActor in await self?.toggleReading() }
        }

        if !hasAccessibilityPermission {
            AccessibilityPermission.request()
            pollForPermission()
        }

        let player = PlayerViewModel(
            speech: speech,
            settings: settings,
            availableVoices: availableVoices,
            readSelection: { [weak self] in await self?.readSelection() }
        )
        playerPanel = PlayerPanelController(viewModel: player)

        // Natural voices appear in the pickers once the model is ready. @Published emits before
        // the property changes, so use the emitted state rather than reading it back.
        modelStateSubscription = modelStore.$state
            .map { $0 == .ready }
            .removeDuplicates()
            .sink { [weak self] ready in self?.voices = Self.allVoices(modelReady: ready) }
        modelStore.start()
    }

    /// Hotkey action: stop if speaking or paused, otherwise read the selection.
    func toggleReading() async {
        if speech.state == .idle && !ensurePermission() { return }
        await coordinator.toggle()
    }

    /// "Read Selection" menu action.
    func readSelection() async {
        guard ensurePermission() else { return }
        await coordinator.readSelection()
    }

    /// Re-reads installed voices (the user may have downloaded new ones in System Settings).
    func refreshVoices() {
        voices = Self.allVoices(modelReady: modelStore.state == .ready)
    }

    /// Deletes the downloaded natural voice model and frees the memory it uses.
    func removeNaturalVoices() {
        modelStore.remove()
        let engine = kokoroEngine
        Task { await engine.unload() }
    }

    private static var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenReader/Kokoro", isDirectory: true)
    }

    /// System voices, plus the natural voices once their model is downloaded.
    private static func allVoices(modelReady: Bool) -> [VoiceInfo] {
        SystemVoices.all() + (modelReady ? KokoroVoiceCatalog.voiceInfos() : [])
    }

    /// The system voice that continues a reading Kokoro couldn't finish: the usual voice
    /// selection, with natural voices left out.
    private static func systemVoice(for text: String, settings: SettingsStore, languageDetector: NLLanguageDetector) -> String? {
        let isSystemVoice = { (id: String) in !KokoroVoiceCatalog.isKokoroVoiceID(id) }
        return VoiceSelector.selectVoice(
            detectedLanguage: settings.autoDetectLanguage ? languageDetector.detectLanguage(of: text) : nil,
            defaultVoiceID: settings.defaultVoiceID.flatMap { isSystemVoice($0) ? $0 : nil },
            languageOverrides: settings.languageVoiceOverrides.filter { isSystemVoice($0.value) },
            availableVoices: SystemVoices.all()
        )
    }

    private func ensurePermission() -> Bool {
        hasAccessibilityPermission = AccessibilityPermission.isGranted
        if !hasAccessibilityPermission {
            AccessibilityPermission.request()
            pollForPermission()
        }
        return hasAccessibilityPermission
    }

    /// The grant happens in System Settings while we run, so poll until it shows up.
    private func pollForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.hasAccessibilityPermission = AccessibilityPermission.isGranted
                if self.hasAccessibilityPermission {
                    timer.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
    }
}
