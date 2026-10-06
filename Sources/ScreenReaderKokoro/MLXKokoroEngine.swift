import Foundation
import KokoroSwift
import MLX
import MLXUtilsLibrary
import ScreenReaderCore

/// Kokoro on MLX. Loads the model on first use and unloads it after `idleTimeout` without speech.
public actor MLXKokoroEngine: KokoroEngine {
    private let modelURL: URL
    private let voicesURL: URL
    private let idleTimeout: Duration
    private var tts: KokoroTTS?
    private var voices: [String: MLXArray] = [:]
    private var unloadTask: Task<Void, Never>?
    private var unloadGeneration = 0

    var isLoaded: Bool { tts != nil }

    public init(modelURL: URL, voicesURL: URL, idleTimeout: Duration = .seconds(600)) {
        self.modelURL = modelURL
        self.voicesURL = voicesURL
        self.idleTimeout = idleTimeout
    }

    public func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float] {
        unloadTask?.cancel()
        unloadGeneration += 1
        defer { scheduleUnload() }
        let tts = try loadedModel()
        guard let voice = voices[voiceID + ".npy"] else { throw KokoroEngineError.unavailable }
        do {
            return try tts.generateAudio(voice: voice, phonemes: phonemes, speed: speed)
        } catch KokoroTTS.KokoroTTSError.tooManyTokens {
            throw KokoroEngineError.tooManyTokens
        }
    }

    public func phonemize(_ text: String, using phonemizer: any Phonemizer) throws -> String {
        try phonemizer.phonemize(text)
    }

    /// Frees the model's memory; it is loaded again on the next `synthesize`.
    public func unload() {
        unloadTask?.cancel()
        unloadTask = nil
        tts = nil
        voices = [:]
        // Released arrays only return to MLX's buffer cache; give that memory back to the system.
        Memory.clearCache()
    }

    private func loadedModel() throws -> KokoroTTS {
        if let tts { return tts }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: modelURL.path), fileManager.fileExists(atPath: voicesURL.path) else {
            throw KokoroEngineError.unavailable
        }
        // KokoroTTS's initializer traps on bad files, so validate the weights with the throwing loader first.
        do { _ = try MLX.loadArrays(url: modelURL) } catch { throw KokoroEngineError.unavailable }
        // The validated copy is discarded; don't keep its buffers cached next to the real model.
        Memory.clearCache()
        let loadedVoices = NpyzReader.read(fileFromPath: voicesURL) ?? [:]
        guard !loadedVoices.isEmpty else { throw KokoroEngineError.unavailable }
        let tts = KokoroTTS(modelPath: modelURL)
        self.tts = tts
        voices = loadedVoices
        return tts
    }

    private func scheduleUnload() {
        unloadGeneration += 1
        let generation = unloadGeneration
        unloadTask = Task { [weak self, idleTimeout] in
            try? await Task.sleep(for: idleTimeout)
            guard !Task.isCancelled else { return }
            await self?.unloadIfIdle(generation: generation)
        }
    }

    private func unloadIfIdle(generation: Int) {
        guard generation == unloadGeneration else { return }
        unload()
    }
}
