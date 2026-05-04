import Foundation
import Network

final class TCPLineConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "LanAudioRelayMac.TCPLineConnection")
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var receiveBuffer = Data()

    init(connection: NWConnection) {
        self.connection = connection
    }

    init(host: String, port: UInt16) {
        self.connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
    }

    func start() async throws {
        let resumeGate = ContinuationResumeGate()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if resumeGate.tryResume() {
                        continuation.resume()
                    }
                case .failed(let error):
                    if resumeGate.tryResume() {
                        continuation.resume(throwing: error)
                    }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send<T: Encodable>(_ value: T) async throws {
        var data = try encoder.encode(value)
        data.append(0x0a)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receive<T: Decodable>(_ type: T.Type) async throws -> T {
        let line = try await receiveLine()
        return try decoder.decode(T.self, from: line)
    }

    func cancel() {
        connection.cancel()
    }

    private func receiveLine() async throws -> Data {
        while true {
            if let newline = receiveBuffer.firstIndex(of: 0x0a) {
                let line = receiveBuffer[..<newline]
                receiveBuffer.removeSubrange(...newline)
                return Data(line)
            }

            let chunk = try await receiveChunk()
            if chunk.isEmpty {
                throw ProtocolError.socketClosed
            }
            receiveBuffer.append(chunk)
        }
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                    return
                }
                if isComplete {
                    continuation.resume(throwing: ProtocolError.socketClosed)
                    return
                }
                continuation.resume(returning: Data())
            }
        }
    }
}

private final class ContinuationResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else {
            return false
        }

        didResume = true
        return true
    }
}
