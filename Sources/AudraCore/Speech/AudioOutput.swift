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
    /// Called when playback stops on its own (e.g. the audio device changed); everything queued is dropped.
    var onFailure: (@MainActor () -> Void)? { get set }
}

/// `AudioOutput` on `AVAudioEngine`. The engine runs only while audio is queued.
@MainActor
public final class AVAudioEngineOutput: AudioOutput {
    public var onFailure: (@MainActor () -> Void)?

    private struct Entry {
        let onStart: @MainActor () -> Void
        let onEnd: @MainActor () -> Void
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
    private var queue: [Entry] = []
    private var isPaused = false
    /// Bumped whenever the queue is dropped so completion handlers of dropped buffers are ignored.
    private var epoch = 0
    nonisolated(unsafe) private var configurationObserver: (any NSObjectProtocol)?

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // A device or route change stops the engine; queued buffers would then never finish.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in self?.configurationChanged() }
        }
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
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
        isPaused = false
        dropQueue()
    }

    private func dropQueue() {
        epoch += 1
        queue.removeAll()
        player.stop()
        engine.stop()
    }

    private func bufferFinished(epoch: Int) {
        guard epoch == self.epoch, !queue.isEmpty else { return }
        let finished = queue.removeFirst()
        finished.onEnd()
        // onEnd may have stopped playback.
        guard epoch == self.epoch else { return }
        if let next = queue.first {
            next.onStart()
        } else {
            // Drained: release the audio device instead of rendering silence. `schedule` restarts it.
            dropQueue()
        }
    }

    private func configurationChanged() {
        guard !queue.isEmpty else {
            // Nothing was playing; leave the engine stopped so the next `schedule` restarts it.
            dropQueue()
            return
        }
        isPaused = false
        dropQueue()
        onFailure?()
    }
}
