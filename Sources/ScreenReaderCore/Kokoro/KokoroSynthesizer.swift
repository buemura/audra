import Foundation
import os

/// Speaks with Kokoro voices: splits the text into sentences, phonemizes and synthesizes them in
/// order, and plays each as soon as it's ready, keeping up to two sentences synthesized ahead.
/// Progress is reported per sentence.
@MainActor
public final class KokoroSynthesizer: FallibleSpeechSynthesizing {
    /// Kokoro's input limit, in Unicode scalars (its tokenizer maps each scalar to one token).
    public static let maxPhonemes = 510
    /// Buffers queued at most: the sentence playing plus two ahead.
    static let maxQueuedSentences = 3

    public var onFinish: (@MainActor () -> Void)?
    public var onProgress: (@MainActor (Int) -> Void)?
    public var onEngineFailure: (@MainActor (Int) -> Void)?

    private let engine: any KokoroEngine
    private let output: any AudioOutput
    private let phonemizer: @MainActor (KokoroLanguage) -> (any Phonemizer)?
    private var reading: Reading?
    private let logger = Logger(subsystem: "com.buemura.Audra", category: "Kokoro")

    /// State of one `speak` call. Callbacks check `self.reading === reading` to ignore stale work.
    @MainActor
    private final class Reading {
        var task: Task<Void, Never>?
        var queued = 0
        var synthesisDone = false
        var playingOffset: Int?
        /// Offset of the sentence being synthesized; where a hand-over starts when nothing is playing.
        var synthesizingOffset = 0
        var slotWaiter: CheckedContinuation<Void, Never>?

        func freeSlot() {
            slotWaiter?.resume()
            slotWaiter = nil
        }
    }

    public init(
        engine: any KokoroEngine,
        output: any AudioOutput,
        phonemizer: @escaping @MainActor (KokoroLanguage) -> (any Phonemizer)?
    ) {
        self.engine = engine
        self.output = output
        self.phonemizer = phonemizer
        output.onFailure = { [weak self] in self?.playbackFailed() }
    }

    public func speak(_ text: String, voiceID: String?, speed: SpeechSpeed) {
        stop()
        guard let voice = voiceID.flatMap(KokoroVoiceCatalog.voice(forVoiceID:)),
              let phonemizer = phonemizer(voice.language)
        else {
            onEngineFailure?(0)
            return
        }
        let reading = Reading()
        self.reading = reading
        let sentences = SentenceSplitter.sentences(in: text)
        reading.task = Task { [weak self] in
            await self?.run(reading, sentences: sentences, voice: voice, phonemizer: phonemizer, speed: Float(speed.rawValue))
        }
    }

    public func stop() {
        guard let reading else { return }
        self.reading = nil
        reading.task?.cancel()
        reading.freeSlot()
        output.stop()
    }

    public func pause() {
        if reading != nil { output.pause() }
    }

    public func resume() {
        if reading != nil { output.resume() }
    }

    private func run(
        _ reading: Reading,
        sentences: [SentenceSplitter.Sentence],
        voice: KokoroVoice,
        phonemizer: any Phonemizer,
        speed: Float
    ) async {
        for sentence in sentences {
            while reading.queued >= Self.maxQueuedSentences {
                await withCheckedContinuation { reading.slotWaiter = $0 }
                guard self.reading === reading else { return }
            }
            guard self.reading === reading else { return }
            reading.synthesizingOffset = sentence.offset

            let samples: [Float]
            do {
                samples = try await synthesize(sentence.text, voice: voice, phonemizer: phonemizer, speed: speed)
            } catch KokoroEngineError.unavailable {
                guard self.reading === reading else { return }
                stop()
                onEngineFailure?(reading.playingOffset ?? sentence.offset)
                return
            } catch is CancellationError {
                return
            } catch {
                logger.error("Skipped a sentence: \(String(describing: type(of: error)), privacy: .public)")
                continue
            }
            guard self.reading === reading else { return }
            guard !samples.isEmpty else { continue }

            do {
                try output.schedule(samples, onStart: { [weak self] in
                    guard let self, self.reading === reading else { return }
                    reading.playingOffset = sentence.offset
                    self.onProgress?(sentence.offset)
                }, onEnd: { [weak self] in
                    guard let self, self.reading === reading else { return }
                    reading.queued -= 1
                    if reading.queued == 0 { reading.playingOffset = nil }
                    reading.freeSlot()
                    self.finishIfDone(reading)
                })
                reading.queued += 1
            } catch {
                logger.error("Audio output failed: \(String(describing: type(of: error)), privacy: .public)")
                guard self.reading === reading else { return }
                stop()
                onEngineFailure?(reading.playingOffset ?? sentence.offset)
                return
            }
        }
        guard self.reading === reading else { return }
        reading.synthesisDone = true
        finishIfDone(reading)
    }

    /// The output stopped on its own, e.g. because the audio device changed: hand the rest over.
    private func playbackFailed() {
        guard let reading else { return }
        stop()
        onEngineFailure?(reading.playingOffset ?? reading.synthesizingOffset)
    }

    private func finishIfDone(_ reading: Reading) {
        guard self.reading === reading, reading.synthesisDone, reading.queued == 0 else { return }
        self.reading = nil
        onFinish?()
    }

    private func synthesize(_ text: String, voice: KokoroVoice, phonemizer: any Phonemizer, speed: Float) async throws -> [Float] {
        var samples: [Float] = []
        for chunk in try await phonemeChunks(for: text, phonemizer: phonemizer) {
            try Task.checkCancellation()
            samples += try await engine.synthesize(phonemes: chunk, voiceID: voice.id, speed: speed)
        }
        return samples
    }

    /// Phonemes for `text` in pieces of at most `maxPhonemes` scalars. Over-long text is split
    /// at clause punctuation (then words, then characters) and the pieces are merged back greedily.
    func phonemeChunks(for text: String, phonemizer: any Phonemizer) async throws -> [String] {
        let phonemes = try await engine.phonemize(text, using: phonemizer)
        guard phonemes.unicodeScalars.count > Self.maxPhonemes else {
            return phonemes.isEmpty ? [] : [phonemes]
        }
        let parts = SentenceSplitter.subdivide(text)
        guard parts.count > 1 else {
            return [String(String.UnicodeScalarView(phonemes.unicodeScalars.prefix(Self.maxPhonemes)))]
        }
        var pieces: [String] = []
        for part in parts {
            pieces += try await phonemeChunks(for: part, phonemizer: phonemizer)
        }
        var chunks: [String] = []
        for piece in pieces {
            if let last = chunks.last, last.unicodeScalars.count + 1 + piece.unicodeScalars.count <= Self.maxPhonemes {
                chunks[chunks.count - 1] = last + " " + piece
            } else {
                chunks.append(piece)
            }
        }
        return chunks
    }
}
