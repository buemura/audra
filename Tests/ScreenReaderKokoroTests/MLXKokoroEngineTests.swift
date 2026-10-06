import ScreenReaderCore
import XCTest
@testable import ScreenReaderKokoro

final class MLXKokoroEngineTests: XCTestCase {
    private var modelDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenReader/Kokoro", isDirectory: true)
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
            _ = try await engine.synthesize(phonemes: "həlˈO", voiceID: "xx_nobody", speed: 1)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? KokoroEngineError, .unavailable)
        }
    }
}
