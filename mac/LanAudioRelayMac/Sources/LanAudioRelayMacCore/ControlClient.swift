import Foundation

public final class ControlClient {
    public init() {}

    public func connectAndPair(
        host: String,
        pairingCode: String,
        controlPort: UInt16 = AudioConstants.controlPort
    ) async throws -> PairingSession {
        let connection = TCPLineConnection(host: host, port: controlPort)
        try await connection.start()
        defer { connection.cancel() }

        let clientNonce = Pairing.createNonce()
        try await connection.send(HelloRequest(
            clientName: Host.current().localizedName ?? "Mac",
            clientNonce: clientNonce
        ))

        let challenge = try await connection.receive(ChallengeResponse.self)
        guard challenge.type == "challenge",
              challenge.protocolVersion == AudioConstants.protocolVersion
        else {
            throw ProtocolError.unsupportedProtocol
        }

        let proof = Pairing.createProof(
            code: pairingCode,
            clientNonce: clientNonce,
            serverNonce: challenge.serverNonce
        )
        try await connection.send(PairRequest(proof: proof))

        let result = try await connection.receive(PairResult.self)
        guard result.accepted else {
            throw ProtocolError.pairingRejected(result.errorMessage ?? "Pairing rejected")
        }

        return PairingSession(
            sessionId: result.sessionId,
            receiverHost: host,
            mediaPort: result.mediaPort,
            audioSettings: result.audioSettings
        )
    }
}
