import AppKit
import CoreGraphics
import KeyboardShortcuts
import ScreenReaderCore

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let speech: SpeechController
    @Published private(set) var hasAccessibilityPermission = AccessibilityPermission.isGranted
    @Published private(set) var voices: [VoiceInfo] = SystemVoices.all()

    private let coordinator: ReadSelectionCoordinator
    private var permissionTimer: Timer?
    private var playerPanel: PlayerPanelController?

    init() {
        let settings = SettingsStore()
        let speech = SpeechController(synthesizer: AVSpeechSynthesizerAdapter())
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
        coordinator = ReadSelectionCoordinator(
            textSource: textSource,
            speech: speech,
            settings: settings,
            languageDetector: NLLanguageDetector(),
            availableVoices: { SystemVoices.all() },
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
            availableVoices: { SystemVoices.all() },
            readSelection: { [weak self] in await self?.readSelection() }
        )
        playerPanel = PlayerPanelController(viewModel: player)
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
        voices = SystemVoices.all()
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
