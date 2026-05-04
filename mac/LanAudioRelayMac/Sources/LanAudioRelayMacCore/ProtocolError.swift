import Foundation

public enum ProtocolError: Error, Equatable {
    case invalidPacket
    case invalidSessionId
    case unsupportedProtocol
    case invalidPayloadLength
    case invalidPairingCode
    case pairingRejected(String)
    case socketClosed
    case opusError(Int32)
}
