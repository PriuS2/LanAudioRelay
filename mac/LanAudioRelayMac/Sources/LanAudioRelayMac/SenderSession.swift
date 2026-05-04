import Foundation
import LanAudioRelayMacCore

final class SenderSession {
    private let controlClient = ControlClient()
    private let capture = MacSystemAudioCapture()
    private let lock = NSLock()
    private var encoder: OpusFrameEncoder?
    private var mediaSender: MediaSender?
    private var sessionId: UUID?
    private var sequence: UInt32 = 0
    private var timestamp: UInt64 = 0
    private var running = false

    var onStatus: (@Sendable (String) -> Void)?
    var onInputLevel: (@Sendable (Float) -> Void)?

    init() {
        capture.onFrame = { [weak self] frame in
            self?.send(frame)
        }
        capture.onError = { [weak self] message in
            self?.onStatus?("Capture error: \(message)")
        }
    }

    func start(receiverHost: String, pairingCode: String) async throws {
        lock.lock()
        if running {
            lock.unlock()
            throw NSError(domain: "LanAudioRelayMac", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sender is already running."])
        }
        running = true
        lock.unlock()

        do {
            onStatus?("Pairing with receiver...")
            let session = try await controlClient.connectAndPair(host: receiverHost, pairingCode: pairingCode)
            let encoder = try OpusFrameEncoder()
            let sender = try MediaSender(host: session.receiverHost, port: UInt16(session.mediaPort))

            lock.lock()
            self.encoder = encoder
            self.mediaSender = sender
            self.sessionId = session.sessionId
            self.sequence = 0
            self.timestamp = 0
            lock.unlock()

            try await capture.start()
            onStatus?("Streaming to \(receiverHost):\(session.mediaPort)")
        } catch {
            await stop()
            throw error
        }
    }

    private func send(_ frame: PCMFrame) {
        lock.lock()
        guard running,
              let encoder,
              let mediaSender,
              let sessionId
        else {
            lock.unlock()
            return
        }

        let sequence = self.sequence
        let timestamp = self.timestamp
        self.sequence &+= 1
        self.timestamp &+= UInt64(AudioConstants.samplesPerFrame)
        lock.unlock()

        do {
            let payload = try encoder.encode(frame.samples)
            let packet = AudioPacket(
                sessionId: sessionId,
                sequence: sequence,
                timestamp: timestamp,
                codec: AudioConstants.codecOpus,
                payload: payload
            )
            try mediaSender.send(packet)
            onInputLevel?(frame.level)
        } catch {
            onStatus?("Send error: \(error.localizedDescription)")
        }
    }

    func stop() async {
        lock.lock()
        running = false
        encoder = nil
        mediaSender = nil
        sessionId = nil
        lock.unlock()

        await capture.stop()
        onInputLevel?(0)
        onStatus?("Sender stopped.")
    }
}
