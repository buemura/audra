import AVFoundation

/// `SpeechSynthesizing` backed by the offline system speech engine.
@MainActor
public final class AVSpeechSynthesizerAdapter: NSObject, SpeechSynthesizing {
    public var onFinish: (@MainActor () -> Void)?
    public var onProgress: (@MainActor (Int) -> Void)?
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        let utterance = AVSpeechUtterance(string: text)
        if let voiceID, let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        }
        utterance.rate = speed.utteranceRate
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }

    public func stop() {
        currentUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    public func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    public func resume() {
        synthesizer.continueSpeaking()
    }
}

extension AVSpeechSynthesizerAdapter: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let finished = ObjectIdentifier(utterance)
        Task { @MainActor in
            guard let current = self.currentUtterance, ObjectIdentifier(current) == finished else { return }
            self.currentUtterance = nil
            self.onFinish?()
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        let speaking = ObjectIdentifier(utterance)
        let offset = characterRange.location
        Task { @MainActor in
            guard let current = self.currentUtterance, ObjectIdentifier(current) == speaking else { return }
            self.onProgress?(offset)
        }
    }
}
