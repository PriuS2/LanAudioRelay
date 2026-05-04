import Foundation
import XCTest
@testable import LanAudioRelayMacCore

final class AudioPacketTests: XCTestCase {
    func testPacketSerializesToWindowsCompatibleBytes() throws {
        let sessionId = UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff")!
        let packet = AudioPacket(
            sessionId: sessionId,
            sequence: 0x01020304,
            timestamp: 0x0102030405060708,
            codec: AudioConstants.codecOpus,
            payload: Data([0x01, 0x02])
        )

        let bytes = try packet.serialize()

        XCTAssertEqual(bytes.hex, "4c415231010133221100554477668899aabbccddeeff01020304010203040506070800020102")
    }

    func testPacketParsesWindowsCompatibleBytes() throws {
        let data = Data(hex: "4c415231010133221100554477668899aabbccddeeff01020304010203040506070800020102")

        let packet = try AudioPacket.parse(data)

        XCTAssertEqual(packet.sessionId, UUID(uuidString: "00112233-4455-6677-8899-aabbccddeeff")!)
        XCTAssertEqual(packet.sequence, 0x01020304)
        XCTAssertEqual(packet.timestamp, 0x0102030405060708)
        XCTAssertEqual(packet.codec, AudioConstants.codecOpus)
        XCTAssertEqual(packet.payload, Data([0x01, 0x02]))
    }
}

private extension Data {
    init(hex: String) {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            bytes.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        self.init(bytes)
    }

    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
