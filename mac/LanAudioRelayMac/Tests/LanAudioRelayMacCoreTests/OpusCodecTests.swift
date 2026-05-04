import XCTest
@testable import LanAudioRelayMacCore

final class OpusCodecTests: XCTestCase {
    func testOpusEncoderDecoderRoundTripsStereoFrame() throws {
        let encoder = try OpusFrameEncoder()
        let decoder = try OpusFrameDecoder()
        var pcm = [Int16](repeating: 0, count: AudioConstants.pcmSamplesPerFrame)

        for frame in 0..<AudioConstants.samplesPerFrame {
            let sample = Int16(Double.sin(Double(frame) / 12.0) * 12_000)
            pcm[frame * 2] = sample
            pcm[frame * 2 + 1] = sample
        }

        let payload = try encoder.encode(pcm)
        let decoded = try decoder.decode(payload)

        XCTAssertFalse(payload.isEmpty)
        XCTAssertEqual(decoded.count, AudioConstants.pcmSamplesPerFrame)
        XCTAssertTrue(decoded.contains { $0 != 0 })
    }
}
