import Foundation

public extension UUID {
    var dotNetBytes: [UInt8] {
        let canonical = withUnsafeBytes(of: uuid) { Array($0) }
        return [
            canonical[3], canonical[2], canonical[1], canonical[0],
            canonical[5], canonical[4],
            canonical[7], canonical[6],
            canonical[8], canonical[9], canonical[10], canonical[11],
            canonical[12], canonical[13], canonical[14], canonical[15]
        ]
    }

    init(dotNetBytes bytes: ArraySlice<UInt8>) throws {
        guard bytes.count == 16 else {
            throw ProtocolError.invalidSessionId
        }

        let b = Array(bytes)
        self.init(uuid: (
            b[3], b[2], b[1], b[0],
            b[5], b[4],
            b[7], b[6],
            b[8], b[9], b[10], b[11],
            b[12], b[13], b[14], b[15]
        ))
    }
}
