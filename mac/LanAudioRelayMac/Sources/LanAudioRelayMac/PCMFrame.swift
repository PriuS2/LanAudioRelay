import Foundation

struct PCMFrame: Sendable {
    let samples: [Int16]
    let level: Float
}
