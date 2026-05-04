import Foundation
import Network

public final class ControlServer: @unchecked Sendable {
    private let pairingCodeProvider: @Sendable () -> String
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "LanAudioRelayMac.ControlServer")

    public var onPairingAccepted: (@Sendable (UUID, String) -> Void)?
    public private(set) var currentSessionId: UUID?

    public init(pairingCodeProvider: @escaping @Sendable () -> String) {
        self.pairingCodeProvider = pairingCodeProvider
    }

    public func start(port: UInt16 = AudioConstants.controlPort) throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            Task.detached {
                await self.handle(connection)
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ nwConnection: NWConnection) async {
        let connection = TCPLineConnection(connection: nwConnection)
        do {
            try await connection.start()
            defer { connection.cancel() }

            let hello = try await connection.receive(HelloRequest.self)
            guard hello.type == "hello",
                  hello.protocolVersion == AudioConstants.protocolVersion
            else {
                try await sendRejected(connection, reason: "Unsupported protocol version.")
                return
            }

            let serverNonce = Pairing.createNonce()
            try await connection.send(ChallengeResponse(
                type: "challenge",
                protocolVersion: AudioConstants.protocolVersion,
                serverName: Host.current().localizedName ?? "Mac",
                serverNonce: serverNonce,
                audioSettings: .default
            ))

            let pair = try await connection.receive(PairRequest.self)
            guard pair.type == "pair",
                  Pairing.verifyProof(
                    expectedCode: pairingCodeProvider(),
                    clientNonce: hello.clientNonce,
                    serverNonce: serverNonce,
                    proof: pair.proof
                  )
            else {
                try await sendRejected(connection, reason: "Invalid pairing code.")
                return
            }

            let sessionId = UUID()
            currentSessionId = sessionId
            try await connection.send(PairResult(
                type: "pairResult",
                accepted: true,
                errorMessage: nil,
                sessionId: sessionId,
                mediaPort: Int(AudioConstants.mediaPort),
                audioSettings: .default
            ))
            onPairingAccepted?(sessionId, hello.clientName)
        } catch {
            connection.cancel()
        }
    }

    private func sendRejected(_ connection: TCPLineConnection, reason: String) async throws {
        try await connection.send(PairResult(
            type: "pairResult",
            accepted: false,
            errorMessage: reason,
            sessionId: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            mediaPort: Int(AudioConstants.mediaPort),
            audioSettings: .default
        ))
    }
}
