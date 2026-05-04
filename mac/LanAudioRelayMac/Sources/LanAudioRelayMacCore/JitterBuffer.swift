import Foundation

public final class JitterBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [UInt32: AudioPacket] = [:]
    private let targetDepth: Int
    private let maxFrames: Int
    private var started = false
    private var expectedSequence: UInt32 = 0

    public private(set) var missingFrames: Int64 = 0

    public init(targetDepth: Int = 3, maxFrames: Int = 128) {
        precondition(targetDepth >= 1)
        precondition(maxFrames > targetDepth)
        self.targetDepth = targetDepth
        self.maxFrames = maxFrames
    }

    public var bufferedFrameCount: Int {
        lock.withLock { frames.count }
    }

    public func reset() {
        lock.withLock {
            frames.removeAll()
            started = false
            expectedSequence = 0
            missingFrames = 0
        }
    }

    public func push(_ packet: AudioPacket) {
        lock.withLock {
            if started && packet.sequence < expectedSequence {
                return
            }

            frames[packet.sequence] = packet

            while frames.count > maxFrames, let first = frames.keys.min() {
                frames.removeValue(forKey: first)
            }
        }
    }

    public func pop() -> AudioPacket? {
        lock.withLock {
            if !started {
                guard frames.count >= targetDepth, let first = frames.keys.min() else {
                    return nil
                }
                expectedSequence = first
                started = true
            }

            if let packet = frames.removeValue(forKey: expectedSequence) {
                expectedSequence &+= 1
                return packet
            }

            if frames.isEmpty {
                started = false
                return nil
            }

            missingFrames += 1
            expectedSequence &+= 1
            return nil
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
