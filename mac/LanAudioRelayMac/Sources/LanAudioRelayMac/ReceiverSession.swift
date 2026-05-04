import Foundation
import LanAudioRelayMacCore

final class ReceiverSession {
    private let lock = NSLock()
    private let playback = MacAudioPlaybackSink()
    private let jitterBuffer = JitterBuffer(targetDepth: 3, maxFrames: 128)
    private let silence = [Int16](repeating: 0, count: AudioConstants.pcmSamplesPerFrame)
    private let receiverId = UUID().uuidString
    private var pairingCode = ""
    private var controlServer: ControlServer?
    private var discoveryResponder: DiscoveryResponder?
    private var mediaReceiver: MediaReceiver?
    private var decoder: OpusFrameDecoder?
    private var activeSessionId: UUID?
    private var playbackTask: Task<Void, Never>?
    private var running = false
    private var hasReceivedAudio = false
    private var playoutStarted = false
    private var lastDecodeErrorStatus = Date.distantPast

    var volume: Float {
        get { playback.volume }
        set { playback.volume = newValue }
    }

    var onStatus: (@Sendable (String) -> Void)?
    var onPairingCode: (@Sendable (String) -> Void)?
    var onBufferFrames: (@Sendable (Int) -> Void)?

    func start() throws {
        lock.lock()
        if running {
            lock.unlock()
            throw NSError(domain: "LanAudioRelayMac", code: 1, userInfo: [NSLocalizedDescriptionKey: "Receiver is already running."])
        }

        running = true
        activeSessionId = nil
        hasReceivedAudio = false
        playoutStarted = false
        pairingCode = Pairing.generateCode()
        decoder = try OpusFrameDecoder()
        jitterBuffer.reset()
        lock.unlock()

        try playback.start()
        onPairingCode?(pairingCode)

        let controlServer = ControlServer { [weak self] in
            self?.currentPairingCode() ?? ""
        }
        controlServer.onPairingAccepted = { [weak self] sessionId, clientName in
            self?.acceptPairing(sessionId: sessionId, clientName: clientName)
        }
        try controlServer.start()
        self.controlServer = controlServer

        let discoveryResponder = DiscoveryResponder(receiverId: receiverId) {
            Host.current().localizedName ?? "Mac"
        }
        try discoveryResponder.start()
        self.discoveryResponder = discoveryResponder

        let mediaReceiver = MediaReceiver()
        mediaReceiver.onPacket = { [weak self] packet in
            self?.receive(packet)
        }
        mediaReceiver.onError = { [weak self] message in
            self?.onStatus?("UDP receive error: \(message)")
        }
        try mediaReceiver.start()
        self.mediaReceiver = mediaReceiver

        playbackTask = Task.detached { [weak self] in
            await self?.playbackLoop()
        }

        onStatus?("Receiver is listening.")
    }

    private func currentPairingCode() -> String {
        lock.lock()
        defer { lock.unlock() }
        return pairingCode
    }

    private func acceptPairing(sessionId: UUID, clientName: String) {
        lock.lock()
        activeSessionId = sessionId
        hasReceivedAudio = false
        playoutStarted = false
        decoder = try? OpusFrameDecoder()
        jitterBuffer.reset()
        lock.unlock()

        playback.clear()
        onStatus?("Paired with \(clientName). Waiting for audio...")
    }

    private func receive(_ packet: AudioPacket) {
        lock.lock()
        let activeSessionId = self.activeSessionId
        lock.unlock()

        guard packet.sessionId == activeSessionId,
              packet.codec == AudioConstants.codecOpus
        else {
            return
        }

        jitterBuffer.push(packet)
        onBufferFrames?(jitterBuffer.bufferedFrameCount)

        lock.lock()
        let firstAudio = !hasReceivedAudio
        hasReceivedAudio = true
        lock.unlock()

        if firstAudio {
            onStatus?("Receiving audio packets. Playing...")
        }
    }

    private func playbackLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(AudioConstants.frameDurationMs) * 1_000_000)

            lock.lock()
            let hasSession = activeSessionId != nil
            let shouldRead = hasSession && hasReceivedAudio
            let shouldPrime = !playoutStarted && jitterBuffer.bufferedFrameCount < 3
            lock.unlock()

            guard shouldRead, !shouldPrime else {
                continue
            }

            if let packet = jitterBuffer.pop() {
                do {
                    lock.lock()
                    let decoder = self.decoder
                    lock.unlock()

                    guard let decoder else {
                        continue
                    }

                    let pcm = try decoder.decode(packet.payload)
                    playback.write(pcm)

                    lock.lock()
                    playoutStarted = true
                    lock.unlock()
                } catch {
                    reportDecodeError(error)
                    playback.write(silence)
                }
            } else {
                playback.write(silence)
            }

            onBufferFrames?(jitterBuffer.bufferedFrameCount)
        }
    }

    private func reportDecodeError(_ error: Error) {
        let now = Date()
        guard now.timeIntervalSince(lastDecodeErrorStatus) > 2 else {
            return
        }
        lastDecodeErrorStatus = now
        onStatus?("Audio decode error: \(error.localizedDescription)")
    }

    func stop() {
        lock.lock()
        running = false
        activeSessionId = nil
        pairingCode = ""
        hasReceivedAudio = false
        playoutStarted = false
        lock.unlock()

        playbackTask?.cancel()
        playbackTask = nil
        mediaReceiver?.stop()
        mediaReceiver = nil
        discoveryResponder?.stop()
        discoveryResponder = nil
        controlServer?.stop()
        controlServer = nil
        playback.stop()
        jitterBuffer.reset()

        onPairingCode?("")
        onBufferFrames?(0)
        onStatus?("Receiver stopped.")
    }
}
