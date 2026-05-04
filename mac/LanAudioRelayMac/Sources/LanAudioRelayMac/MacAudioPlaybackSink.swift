import AVFoundation
import Foundation
import LanAudioRelayMacCore

final class MacAudioPlaybackSink {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(
        standardFormatWithSampleRate: Double(AudioConstants.sampleRate),
        channels: AVAudioChannelCount(AudioConstants.channels)
    )!
    private let lock = NSLock()
    private var started = false

    var volume: Float {
        get { player.volume }
        set { player.volume = min(max(newValue, 0), 1) }
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !started else {
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        player.play()
        started = true
    }

    func write(_ samples: [Int16]) {
        guard samples.count == AudioConstants.pcmSamplesPerFrame,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(AudioConstants.samplesPerFrame)
              ),
              let channels = buffer.floatChannelData
        else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(AudioConstants.samplesPerFrame)
        for frame in 0..<AudioConstants.samplesPerFrame {
            channels[0][frame] = Float(samples[frame * 2]) / Float(Int16.max)
            channels[1][frame] = Float(samples[frame * 2 + 1]) / Float(Int16.max)
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    func clear() {
        player.stop()
        player.reset()
        if started {
            player.play()
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }

        player.stop()
        engine.stop()
        if started {
            engine.detach(player)
        }
        started = false
    }
}
