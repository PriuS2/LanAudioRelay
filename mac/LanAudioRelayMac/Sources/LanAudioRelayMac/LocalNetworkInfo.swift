import Darwin
import Foundation

enum LocalNetworkInfo {
    static func ipv4Summary() -> String {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return "No LAN IPv4 address found"
        }
        defer { freeifaddrs(interfaces) }

        var addresses: [String] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET)
            else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                let ip = String(cString: hostname)
                if ip != "127.0.0.1", !addresses.contains(ip) {
                    addresses.append(ip)
                }
            }
        }

        return addresses.isEmpty ? "No LAN IPv4 address found" : addresses.joined(separator: ", ")
    }
}
