import AVFoundation
import CoreMedia
import Foundation
import LanAudioRelayMacCore
import ScreenCaptureKit

final class MacSystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private let sampleQueue = DispatchQueue(label: "LanAudioRelayMac.SystemAudioCapture")
    private var stream: SCStream?
    private var pendingSamples: [Int16] = []

    var onFrame: (@Sendable (PCMFrame) -> Void)?
    var onError: (@Sendable (String) -> Void)?

    func start() async throws {
        if stream != nil {
            throw NSError(domain: "LanAudioRelayMac", code: 1, userInfo: [NSLocalizedDescriptionKey: "Capture is already running."])
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw NSError(domain: "LanAudioRelayMac", code: 2, userInfo: [NSLocalizedDescriptionKey: "No display is available for ScreenCaptureKit."])
        }

        let excludedApps = content.applications.filter { application in
            application.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = AudioConstants.sampleRate
        configuration.channelCount = AudioConstants.channels
        configuration.width = 2
        configuration.height = 2
        configuration.queueDepth = 3
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        guard let stream else {
            return
        }

        do {
            try await stream.stopCapture()
        } catch {
            onError?("Failed to stop capture: \(error.localizedDescription)")
        }
        self.stream = nil
        pendingSamples.removeAll()
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onError?("Capture stopped: \(error.localizedDescription)")
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid else {
            return
        }

        process(sampleBuffer)
    }

    private func process(_ sampleBuffer: CMSampleBuffer) {
        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, _ in
                guard
                    let description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                    let format = AVAudioFormat(
                        standardFormatWithSampleRate: description.mSampleRate,
                        channels: description.mChannelsPerFrame
                    ),
                    let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        bufferListNoCopy: audioBufferList.unsafePointer
                    )
                else {
                    return
                }

                append(buffer)
            }
        } catch {
            onError?("Audio sample conversion failed: \(error.localizedDescription)")
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            return
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        for frame in 0..<frameLength {
            let left = channelData[0][frame]
            let right = channelCount > 1 ? channelData[1][frame] : left
            pendingSamples.append(Self.int16(left))
            pendingSamples.append(Self.int16(right))
        }

        while pendingSamples.count >= AudioConstants.pcmSamplesPerFrame {
            let frameSamples = Array(pendingSamples.prefix(AudioConstants.pcmSamplesPerFrame))
            pendingSamples.removeFirst(AudioConstants.pcmSamplesPerFrame)

            let squareSum = frameSamples.reduce(Float(0)) { partial, sample in
                let normalized = Float(sample) / Float(Int16.max)
                return partial + normalized * normalized
            }
            let level = sqrt(squareSum / Float(frameSamples.count))
            onFrame?(PCMFrame(samples: frameSamples, level: level))
        }
    }

    private static func int16(_ value: Float) -> Int16 {
        let clamped = min(max(value, -1), 1)
        return Int16(clamped * Float(Int16.max))
    }
}
