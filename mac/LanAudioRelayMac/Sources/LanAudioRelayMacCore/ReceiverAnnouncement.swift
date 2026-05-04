import Foundation

public struct ReceiverAnnouncement: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let hostName: String
    public let ipAddress: String
    public let controlPort: Int
    public let protocolVersion: Int

    public var displayName: String {
        "\(name) (\(ipAddress))"
    }
}
