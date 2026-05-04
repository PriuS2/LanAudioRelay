import Foundation

public struct HelloRequest: Codable, Sendable {
    public let type: String
    public let protocolVersion: Int
    public let clientName: String
    public let clientNonce: String

    public init(type: String = "hello", protocolVersion: Int = AudioConstants.protocolVersion, clientName: String, clientNonce: String) {
        self.type = type
        self.protocolVersion = protocolVersion
        self.clientName = clientName
        self.clientNonce = clientNonce
    }
}

public struct ChallengeResponse: Codable, Sendable {
    public let type: String
    public let protocolVersion: Int
    public let serverName: String
    public let serverNonce: String
    public let audioSettings: AudioSettings
}

public struct PairRequest: Codable, Sendable {
    public let type: String
    public let proof: String

    public init(type: String = "pair", proof: String) {
        self.type = type
        self.proof = proof
    }
}

public struct PairResult: Codable, Sendable {
    public let type: String
    public let accepted: Bool
    public let errorMessage: String?
    public let sessionId: UUID
    public let mediaPort: Int
    public let audioSettings: AudioSettings
}

public struct PairingSession: Sendable {
    public let sessionId: UUID
    public let receiverHost: String
    public let mediaPort: Int
    public let audioSettings: AudioSettings
}
