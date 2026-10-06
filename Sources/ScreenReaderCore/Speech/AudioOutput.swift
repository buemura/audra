import AVFoundation

/// Plays synthesized sentences back to back.
@MainActor
public protocol AudioOutput: AnyObject {
    /// Queues 24 kHz mono samples after everything already queued. `onStart` runs when this buffer
    /// starts playing, `onEnd` when it has played completely. Neither runs after `stop()`.
    /// Throws if audio output can't start; nothing is queued then.
    func schedule(_ samples: [Float], onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void) throws
    func pause()
    func resume()
    /// Drops everything queued.
    func stop()
}

/// `AudioOutput` on `AVAudioEngine`.
@MainActor
public final class AVAudioEngineOutput: AudioOutput {
    private struct Entry {
        let onStart: @MainActor () -> Void
        let onEnd: @MainActor () -> Void
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
    private var queue: [Entry] = []
    private var isPaused = false
    /// Bumped by `stop()` so completion handlers of dropped buffers are ignored.
    private var epoch = 0

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    public func schedule(_ samples: [Float], onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void) throws {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        if !engine.isRunning { try engine.start() }

        queue.append(Entry(onStart: onStart, onEnd: onEnd))
        let epoch = self.epoch
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.bufferFinished(epoch: epoch) }
        }
        if queue.count == 1 { onStart() }
        if !isPaused && !player.isPlaying { player.play() }
    }

    public func pause() {
        isPaused = true
        player.pause()
    }

    public func resume() {
        isPaused = false
        if engine.isRunning && !queue.isEmpty { player.play() }
    }

    public func stop() {
        epoch += 1
        queue.removeAll()
        isPaused = false
        player.stop()
        engine.stop()
    }

    private func bufferFinished(epoch: Int) {
        guard epoch == self.epoch, !queue.isEmpty else { return }
        let finished = queue.removeFirst()
        finished.onEnd()
        // onEnd may have stopped playback.
        guard epoch == self.epoch else { return }
        queue.first?.onStart()
    }
}
