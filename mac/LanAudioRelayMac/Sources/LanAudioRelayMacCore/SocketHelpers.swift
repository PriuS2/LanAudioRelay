import Darwin
import Foundation

enum SocketHelpers {
    static func makeUDPSocket(reuseAddress: Bool = false, broadcast: Bool = false) throws -> Int32 {
        let socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFd >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        if reuseAddress {
            var yes: Int32 = 1
            setsockopt(socketFd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        }

        if broadcast {
            var yes: Int32 = 1
            setsockopt(socketFd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        }

        return socketFd
    }

    static func bind(_ socketFd: Int32, port: UInt16) throws {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_ANY.bigEndian)

        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard result == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }

    static func endpoint(host: String, port: UInt16) throws -> sockaddr_in {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian

        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            throw POSIXError(.EADDRNOTAVAIL)
        }

        return address
    }

    static func send(_ socketFd: Int32, data: Data, to endpoint: sockaddr_in) throws {
        var endpoint = endpoint
        let result = data.withUnsafeBytes { dataBuffer in
            withUnsafePointer(to: &endpoint) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(
                        socketFd,
                        dataBuffer.baseAddress,
                        data.count,
                        0,
                        $0,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }

        guard result >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }

    static func receive(_ socketFd: Int32, maxBytes: Int = 4096) throws -> (Data, sockaddr_in) {
        var buffer = [UInt8](repeating: 0, count: maxBytes)
        let bufferCount = buffer.count
        var remote = sockaddr_in()
        var remoteLength = socklen_t(MemoryLayout<sockaddr_in>.size)

        let read = buffer.withUnsafeMutableBytes { bufferPointer in
            withUnsafeMutablePointer(to: &remote) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { remotePointer in
                    recvfrom(socketFd, bufferPointer.baseAddress, bufferCount, 0, remotePointer, &remoteLength)
                }
            }
        }

        guard read >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        return (Data(buffer.prefix(read)), remote)
    }

    static func ipString(from address: sockaddr_in) -> String {
        var address = address.sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        _ = buffer.withUnsafeMutableBufferPointer { pointer in
            inet_ntop(AF_INET, &address, pointer.baseAddress, socklen_t(INET_ADDRSTRLEN))
        }
        return String(cString: buffer)
    }
}
