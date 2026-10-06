import Foundation
@testable import ScreenReaderCore

@MainActor
final class FakeKokoroEngine: KokoroEngine {
    struct Call: Equatable {
        let phonemes: String
        let voiceID: String
        let speed: Float
    }

    struct Failure: Error {}

    private(set) var calls: [Call] = []
    /// Thrown by every call.
    var error: (any Error)?
    /// Phonemes that throw `Failure`.
    var failingPhonemes: Set<String> = []
    /// Phonemes that throw `KokoroEngineError.unavailable`.
    var unavailablePhonemes: Set<String> = []
    /// While true, calls wait until `release()`.
    var holdsCalls = false
    private var held: [CheckedContinuation<Void, Never>] = []

    func synthesize(phonemes: String, voiceID: String, speed: Float) async throws -> [Float] {
        calls.append(Call(phonemes: phonemes, voiceID: voiceID, speed: speed))
        if holdsCalls { await withCheckedContinuation { held.append($0) } }
        if let error { throw error }
        if unavailablePhonemes.contains(phonemes) { throw KokoroEngineError.unavailable }
        if failingPhonemes.contains(phonemes) { throw Failure() }
        return Array(repeating: 0.1, count: phonemes.unicodeScalars.count)
    }

    func release() {
        holdsCalls = false
        held.forEach { $0.resume() }
        held = []
    }
}

/// Mirrors `AVAudioEngineOutput`: the first queued buffer starts at once, each next one when
/// the previous ends, and nothing is reported after `stop()`.
@MainActor
final class FakeAudioOutput: AudioOutput {
    struct Item {
        let samples: [Float]
        let onStart: @MainActor () -> Void
        let onEnd: @MainActor () -> Void
    }

    private(set) var queue: [Item] = []
    private(set) var scheduledCount = 0
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    private(set) var stopCount = 0

    func schedule(_ samples: [Float], onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void) {
        queue.append(Item(samples: samples, onStart: onStart, onEnd: onEnd))
        scheduledCount += 1
        if queue.count == 1 { onStart() }
    }

    /// Simulates the playing buffer reaching its end.
    func finishCurrent() {
        guard !queue.isEmpty else { return }
        let finished = queue.removeFirst()
        finished.onEnd()
        queue.first?.onStart()
    }

    func pause() { pauseCount += 1 }
    func resume() { resumeCount += 1 }

    func stop() {
        stopCount += 1
        queue.removeAll()
    }
}

/// Returns the text itself as "phonemes".
struct FakePhonemizer: Phonemizer {
    struct Failure: Error {}
    var failing: Set<String> = []

    func phonemize(_ text: String) throws -> String {
        if failing.contains(text) { throw Failure() }
        return text
    }
}
