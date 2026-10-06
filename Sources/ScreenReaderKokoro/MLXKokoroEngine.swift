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

    public init(modelURL: URL, voicesURL: URL, idleTimeout: Duration = .seconds(600)) {
        self.modelURL = modelURL
        self.voicesURL = voicesURL
        self.idleTimeout = idleTimeout
    }

    public func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float] {
        unloadTask?.cancel()
        defer { scheduleUnload() }
        let tts = try loadedModel()
        guard let voice = voices[voiceID + ".npy"] else { throw KokoroEngineError.unavailable }
        do {
            return try tts.generateAudio(voice: voice, phonemes: phonemes, speed: speed)
        } catch KokoroTTS.KokoroTTSError.tooManyTokens {
            throw KokoroEngineError.tooManyTokens
        }
    }

    /// Frees the model's memory; it is loaded again on the next `synthesize`.
    public func unload() {
        unloadTask?.cancel()
        unloadTask = nil
        tts = nil
        voices = [:]
    }

    private func loadedModel() throws -> KokoroTTS {
        if let tts { return tts }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: modelURL.path), fileManager.fileExists(atPath: voicesURL.path) else {
            throw KokoroEngineError.unavailable
        }
        let loadedVoices = NpyzReader.read(fileFromPath: voicesURL) ?? [:]
        guard !loadedVoices.isEmpty else { throw KokoroEngineError.unavailable }
        let tts = KokoroTTS(modelPath: modelURL)
        self.tts = tts
        voices = loadedVoices
        return tts
    }

    private func scheduleUnload() {
        unloadTask = Task { [idleTimeout] in
            try? await Task.sleep(for: idleTimeout)
            guard !Task.isCancelled else { return }
            self.unload()
        }
    }
}
