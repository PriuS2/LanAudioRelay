import Foundation

public enum AudioConstants {
    public static let discoveryPort: UInt16 = 51359
    public static let controlPort: UInt16 = 51360
    public static let mediaPort: UInt16 = 51361

    public static let sampleRate = 48_000
    public static let channels = 2
    public static let bitsPerSample = 16
    public static let frameDurationMs = 20
    public static let samplesPerFrame = sampleRate * frameDurationMs / 1000
    public static let pcmSamplesPerFrame = samplesPerFrame * channels
    public static let pcmBytesPerFrame = pcmSamplesPerFrame * MemoryLayout<Int16>.size
    public static let defaultBitrate = 96_000

    public static let codecOpus: UInt8 = 1
    public static let protocolVersion = 1
}

public struct AudioSettings: Codable, Equatable, Sendable {
    public let sampleRate: Int
    public let channels: Int
    public let frameDurationMs: Int
    public let bitrate: Int
    public let codec: UInt8

    public init(
        sampleRate: Int = AudioConstants.sampleRate,
        channels: Int = AudioConstants.channels,
        frameDurationMs: Int = AudioConstants.frameDurationMs,
        bitrate: Int = AudioConstants.defaultBitrate,
        codec: UInt8 = AudioConstants.codecOpus
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.frameDurationMs = frameDurationMs
        self.bitrate = bitrate
        self.codec = codec
    }

    public static let `default` = AudioSettings()
}
