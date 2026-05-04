import Darwin
import Foundation

private enum DiscoveryProtocol {
    static let requestText = "LAR_DISCOVER_V1"
}

private struct DiscoveryResponse: Codable {
    let protocolVersion: Int
    let receiverId: String
    let name: String
    let hostName: String
    let controlPort: Int
}

public final class DiscoveryClient {
    public init() {}

    public func discover(timeout: TimeInterval = 2.0) async -> [ReceiverAnnouncement] {
        await Task.detached {
            do {
                let socketFd = try SocketHelpers.makeUDPSocket(broadcast: true)
                defer { close(socketFd) }

                let request = Data(DiscoveryProtocol.requestText.utf8)
                try SocketHelpers.send(
                    socketFd,
                    data: request,
                    to: try SocketHelpers.endpoint(host: "255.255.255.255", port: AudioConstants.discoveryPort)
                )

                var timeoutValue = timeval(tv_sec: Int(timeout), tv_usec: 0)
                setsockopt(socketFd, SOL_SOCKET, SO_RCVTIMEO, &timeoutValue, socklen_t(MemoryLayout<timeval>.size))

                var receivers: [String: ReceiverAnnouncement] = [:]
                let decoder = JSONDecoder()

                while true {
                    do {
                        let (data, remote) = try SocketHelpers.receive(socketFd)
                        let response = try decoder.decode(DiscoveryResponse.self, from: data)
                        guard response.protocolVersion == AudioConstants.protocolVersion else {
                            continue
                        }

                        let announcement = ReceiverAnnouncement(
                            id: response.receiverId,
                            name: response.name,
                            hostName: response.hostName,
                            ipAddress: SocketHelpers.ipString(from: remote),
                            controlPort: response.controlPort,
                            protocolVersion: response.protocolVersion
                        )
                        receivers[announcement.id] = announcement
                    } catch {
                        break
                    }
                }

                return receivers.values.sorted { $0.name < $1.name }
            } catch {
                return []
            }
        }.value
    }
}

public final class DiscoveryResponder: @unchecked Sendable {
    private let receiverId: String
    private let nameProvider: @Sendable () -> String
    private var socketFd: Int32 = -1
    private var task: Task<Void, Never>?

    public init(receiverId: String = UUID().uuidString, nameProvider: @escaping @Sendable () -> String) {
        self.receiverId = receiverId
        self.nameProvider = nameProvider
    }

    public func start() throws {
        socketFd = try SocketHelpers.makeUDPSocket(reuseAddress: true)
        try SocketHelpers.bind(socketFd, port: AudioConstants.discoveryPort)

        task = Task.detached { [socketFd, receiverId, nameProvider] in
            let encoder = JSONEncoder()
            while !Task.isCancelled {
                do {
                    let (data, remote) = try SocketHelpers.receive(socketFd)
                    guard String(data: data, encoding: .utf8) == DiscoveryProtocol.requestText else {
                        continue
                    }

                    let response = DiscoveryResponse(
                        protocolVersion: AudioConstants.protocolVersion,
                        receiverId: receiverId,
                        name: nameProvider(),
                        hostName: Host.current().localizedName ?? "Mac",
                        controlPort: Int(AudioConstants.controlPort)
                    )
                    try SocketHelpers.send(socketFd, data: encoder.encode(response), to: remote)
                } catch {
                    if Task.isCancelled { break }
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }
    }
}
