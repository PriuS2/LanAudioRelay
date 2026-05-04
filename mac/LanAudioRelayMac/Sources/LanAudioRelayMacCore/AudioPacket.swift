import Foundation

public struct AudioPacket: Equatable, Sendable {
    public static let headerSize = 36
    private static let magic: [UInt8] = Array("LAR1".utf8)

    public let sessionId: UUID
    public let sequence: UInt32
    public let timestamp: UInt64
    public let codec: UInt8
    public let payload: Data

    public init(sessionId: UUID, sequence: UInt32, timestamp: UInt64, codec: UInt8, payload: Data) {
        self.sessionId = sessionId
        self.sequence = sequence
        self.timestamp = timestamp
        self.codec = codec
        self.payload = payload
    }

    public func serialize() throws -> Data {
        guard payload.count <= UInt16.max else {
            throw ProtocolError.invalidPayloadLength
        }

        var data = Data()
        data.reserveCapacity(Self.headerSize + payload.count)
        data.append(contentsOf: Self.magic)
        data.append(UInt8(AudioConstants.protocolVersion))
        data.append(codec)
        data.append(contentsOf: sessionId.dotNetBytes)
        data.appendBigEndian(sequence)
        data.appendBigEndian(timestamp)
        data.appendBigEndian(UInt16(payload.count))
        data.append(payload)
        return data
    }

    public static func parse(_ data: Data) throws -> AudioPacket {
        let bytes = Array(data)
        guard bytes.count >= headerSize else {
            throw ProtocolError.invalidPacket
        }
        guard Array(bytes[0..<4]) == magic else {
            throw ProtocolError.invalidPacket
        }
        guard bytes[4] == UInt8(AudioConstants.protocolVersion) else {
            throw ProtocolError.unsupportedProtocol
        }

        let payloadLength = Int(UInt16(bigEndianBytes: bytes[34..<36]))
        guard bytes.count == headerSize + payloadLength else {
            throw ProtocolError.invalidPayloadLength
        }

        return AudioPacket(
            sessionId: try UUID(dotNetBytes: bytes[6..<22]),
            sequence: UInt32(bigEndianBytes: bytes[22..<26]),
            timestamp: UInt64(bigEndianBytes: bytes[26..<34]),
            codec: bytes[5],
            payload: Data(bytes[headerSize..<(headerSize + payloadLength)])
        )
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func appendBigEndian(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }

    mutating func appendBigEndian(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8((value >> UInt64(shift)) & 0xff))
        }
    }
}

private extension UInt16 {
    init(bigEndianBytes bytes: ArraySlice<UInt8>) {
        let b = Array(bytes)
        self = (UInt16(b[0]) << 8) | UInt16(b[1])
    }
}

private extension UInt32 {
    init(bigEndianBytes bytes: ArraySlice<UInt8>) {
        let b = Array(bytes)
        self = (UInt32(b[0]) << 24) | (UInt32(b[1]) << 16) | (UInt32(b[2]) << 8) | UInt32(b[3])
    }
}

private extension UInt64 {
    init(bigEndianBytes bytes: ArraySlice<UInt8>) {
        self = bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}
