import Darwin
import Foundation

public final class MediaSender: @unchecked Sendable {
    private let socketFd: Int32
    private let endpoint: sockaddr_in

    public init(host: String, port: UInt16) throws {
        socketFd = try SocketHelpers.makeUDPSocket()
        endpoint = try SocketHelpers.endpoint(host: host, port: port)
    }

    deinit {
        close(socketFd)
    }

    public func send(_ packet: AudioPacket) throws {
        try SocketHelpers.send(socketFd, data: try packet.serialize(), to: endpoint)
    }
}

public final class MediaReceiver: @unchecked Sendable {
    private var socketFd: Int32 = -1
    private var task: Task<Void, Never>?

    public var onPacket: (@Sendable (AudioPacket) -> Void)?
    public var onError: (@Sendable (String) -> Void)?

    public init() {}

    public func start(port: UInt16 = AudioConstants.mediaPort) throws {
        socketFd = try SocketHelpers.makeUDPSocket(reuseAddress: true)
        try SocketHelpers.bind(socketFd, port: port)

        task = Task.detached { [socketFd] in
            while !Task.isCancelled {
                do {
                    let (data, _) = try SocketHelpers.receive(socketFd, maxBytes: 2048)
                    let packet = try AudioPacket.parse(data)
                    self.onPacket?(packet)
                } catch {
                    if Task.isCancelled { break }
                    self.onError?(String(describing: error))
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
