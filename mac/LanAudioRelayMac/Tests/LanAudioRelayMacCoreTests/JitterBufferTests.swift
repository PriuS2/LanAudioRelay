import Foundation
import XCTest
@testable import LanAudioRelayMacCore

final class JitterBufferTests: XCTestCase {
    func testJitterBufferWaitsForTargetDepthBeforePlayout() {
        let buffer = JitterBuffer(targetDepth: 3, maxFrames: 8)
        buffer.push(packet(10))
        buffer.push(packet(11))

        XCTAssertNil(buffer.pop())

        buffer.push(packet(12))

        XCTAssertEqual(buffer.pop()?.sequence, 10)
    }

    func testJitterBufferReordersOutOfOrderPackets() {
        let buffer = JitterBuffer(targetDepth: 3, maxFrames: 8)
        buffer.push(packet(3))
        buffer.push(packet(1))
        buffer.push(packet(2))

        XCTAssertEqual(buffer.pop()?.sequence, 1)
        XCTAssertEqual(buffer.pop()?.sequence, 2)
        XCTAssertEqual(buffer.pop()?.sequence, 3)
    }

    func testJitterBufferRecoversAfterSenderStopsAndResumes() {
        let buffer = JitterBuffer(targetDepth: 2, maxFrames: 8)
        buffer.push(packet(10))
        buffer.push(packet(11))

        XCTAssertEqual(buffer.pop()?.sequence, 10)
        XCTAssertEqual(buffer.pop()?.sequence, 11)

        for _ in 0..<100 {
            XCTAssertNil(buffer.pop())
        }

        buffer.push(packet(12))
        buffer.push(packet(13))

        XCTAssertEqual(buffer.pop()?.sequence, 12)
        XCTAssertEqual(buffer.pop()?.sequence, 13)
    }
}

private func packet(_ sequence: UInt32) -> AudioPacket {
    AudioPacket(
        sessionId: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        sequence: sequence,
        timestamp: UInt64(sequence) * UInt64(AudioConstants.samplesPerFrame),
        codec: AudioConstants.codecOpus,
        payload: Data([1, 2, 3])
    )
}
