import MLX
import AudraCore
import XCTest
@testable import AudraKokoro

final class MLXKokoroEngineTests: XCTestCase {
    private var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Audra/Kokoro", isDirectory: true)
    }

    func testMissingModelIsUnavailable() async {
        let engine = MLXKokoroEngine(
            modelURL: URL(fileURLWithPath: "/nonexistent/model.safetensors"),
            voicesURL: URL(fileURLWithPath: "/nonexistent/voices.npz")
        )
        do {
            _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "af_heart", speed: 1)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? KokoroEngineError, .unavailable)
        }
    }

    func testCorruptModelIsUnavailable() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = directory.appendingPathComponent("model.safetensors")
        let voices = directory.appendingPathComponent("voices.npz")
        try Data("not a safetensors file".utf8).write(to: model)
        try Data([0, 1, 2, 3, 255, 254]).write(to: voices)
        let engine = MLXKokoroEngine(modelURL: model, voicesURL: voices)
        do {
            _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "af_heart", speed: 1)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? KokoroEngineError, .unavailable)
        }
    }

    func testUnloadsAfterIdleTimeout() async throws {
        let model = modelDirectory.appendingPathComponent(KokoroModelAssets.modelFileName)
        let voices = modelDirectory.appendingPathComponent(KokoroModelAssets.voicesFileName)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: model.path), "Kokoro model not installed")
        let engine = MLXKokoroEngine(modelURL: model, voicesURL: voices, idleTimeout: .milliseconds(300))

        _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "af_heart", speed: 1)
        let loadedAfterSpeech = await engine.isLoaded
        XCTAssertTrue(loadedAfterSpeech)
        try await Task.sleep(for: .seconds(1))
        let loadedAfterIdle = await engine.isLoaded
        XCTAssertFalse(loadedAfterIdle)
        // The freed buffers go back to the system, not into MLX's buffer cache.
        XCTAssertLessThan(Memory.cacheMemory, 1_000_000)

        _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "af_heart", speed: 1)
        let loadedAgain = await engine.isLoaded
        XCTAssertTrue(loadedAgain)
    }

    /// Needs the model files installed (Task 14, Step 6).
    func testSynthesizesSpeech() async throws {
        let model = modelDirectory.appendingPathComponent(KokoroModelAssets.modelFileName)
        let voices = modelDirectory.appendingPathComponent(KokoroModelAssets.voicesFileName)
        try XCTSkipUnless(FileManager.default.fileExists(atPath: model.path), "Kokoro model not installed")
        let engine = MLXKokoroEngine(modelURL: model, voicesURL: voices)

        let samples = try await engine.synthesize(phonemes: "həlˈO wˈɜɹld!", voiceID: "af_heart", speed: 1)
        XCTAssertGreaterThan(samples.count, 12_000) // > 0.5 s at 24 kHz
        XCTAssertGreaterThan(samples.map(abs).max() ?? 0, 0.05)

        do {
            _ = try await engine.synthesize(phonemes: String(repeating: "a", count: 600), voiceID: "af_heart", speed: 1)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? KokoroEngineError, .tooManyTokens)
        }

        do {
            _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "xx_nobody", speed: 1)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? KokoroEngineError, .unavailable)
        }
    }
}
