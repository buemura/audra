import Combine
import Foundation

/// State and actions behind the floating player widget.
@MainActor
public final class PlayerViewModel: ObservableObject {
    /// Whether the player should be on screen. Stored (not computed) so `$shouldBeVisible`
    /// delivers new values; hide delays and animation are the window's job.
    @Published public private(set) var shouldBeVisible = false

    private let speech: SpeechController
    private let settings: SettingsStore
    private let availableVoices: () -> [VoiceInfo]
    private let readSelection: @MainActor () async -> Void
    private var changeSubscription: AnyCancellable?

    public init(
        speech: SpeechController,
        settings: SettingsStore,
        availableVoices: @escaping () -> [VoiceInfo],
        readSelection: @escaping @MainActor () async -> Void
    ) {
        self.speech = speech
        self.settings = settings
        self.availableVoices = availableVoices
        self.readSelection = readSelection

        Publishers.CombineLatest(speech.$state, settings.$alwaysShowPlayer)
            .map { state, alwaysShow in state != .idle || alwaysShow }
            .removeDuplicates()
            .assign(to: &$shouldBeVisible)

        // Labels and button states are derived from these two objects, so re-render with them.
        changeSubscription = speech.objectWillChange
            .merge(with: settings.objectWillChange)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    public var isPlaying: Bool { speech.state == .speaking }
    public var canStop: Bool { speech.state != .idle }
    public var canGoSlower: Bool { settings.speed.slower != nil }
    public var canGoFaster: Bool { settings.speed.faster != nil }

    /// The text being read (or last read), on one line.
    public var title: String {
        guard let text = speech.currentText else { return "Select text and press play" }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// How much of the current reading has been spoken, from 0 to 1.
    public var progress: Double { speech.progress }

    public var speed: SpeechSpeed {
        get { settings.speed }
        set { settings.speed = newValue }
    }

    /// "Natural voice" or "System voice", or nil before anything was read.
    public var voiceLabel: String? {
        guard speech.currentText != nil else { return nil }
        return currentVoice?.quality == .natural ? "Natural voice" : "System voice"
    }

    /// "pt-BR", or nil when the voice isn't known.
    public var languageLabel: String? {
        guard speech.currentText != nil else { return nil }
        return currentVoice?.language
    }

    private var currentVoice: VoiceInfo? {
        speech.currentVoiceID.flatMap { id in availableVoices().first { $0.id == id } }
    }

    /// Idle: read the current selection. Speaking: pause. Paused: resume.
    public func playPause() async {
        switch speech.state {
        case .idle: await readSelection()
        case .speaking: speech.pause()
        case .paused: speech.resume()
        }
    }

    public func slower() {
        if let speed = settings.speed.slower { settings.speed = speed }
    }

    public func faster() {
        if let speed = settings.speed.faster { settings.speed = speed }
    }

    public func stop() {
        speech.stop()
    }
}
