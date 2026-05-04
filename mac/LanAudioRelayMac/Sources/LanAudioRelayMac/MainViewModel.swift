import Foundation
import LanAudioRelayMacCore
import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
    @Published var receivers: [ReceiverAnnouncement] = []
    @Published var selectedReceiver: ReceiverAnnouncement?
    @Published var manualReceiverIp = ""
    @Published var senderPairingCode = ""
    @Published var senderStatus = "Choose a receiver, enter its pairing code, then start streaming."
    @Published var receiverStatus = "Start the receiver on the Mac that should play audio."
    @Published var receiverLocalAddress = LocalNetworkInfo.ipv4Summary()
    @Published var receiverPairingCode = ""
    @Published var inputLevel: Double = 0
    @Published var receiverBufferFrames = 0
    @Published var receiverVolume: Double = 0.85 {
        didSet {
            receiverSession?.volume = Float(receiverVolume)
        }
    }
    @Published var isSenderRunning = false
    @Published var isReceiverRunning = false

    private let discoveryClient = DiscoveryClient()
    private var senderSession: SenderSession?
    private var receiverSession: ReceiverSession?

    func discoverReceivers() {
        Task {
            senderStatus = "Searching receivers on the LAN..."
            let found = await discoveryClient.discover(timeout: 2)
            receivers = found
            selectedReceiver = found.first
            senderStatus = found.isEmpty
                ? "No receiver found. Start Receiver on another PC or enter its IP manually."
                : "Found \(found.count) receiver(s)."
        }
    }

    func startSender() {
        let host = manualReceiverIp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? selectedReceiver?.ipAddress
            : manualReceiverIp.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let host, !host.isEmpty else {
            senderStatus = "Enter a receiver IPv4 address or select a discovered receiver."
            return
        }

        let code = senderPairingCode.filter(\.isNumber)
        guard code.count == 6 else {
            senderStatus = "Enter the 6-digit pairing code shown on the receiver."
            return
        }

        let session = SenderSession()
        session.onStatus = { [weak self] message in
            Task { @MainActor in self?.senderStatus = message }
        }
        session.onInputLevel = { [weak self] level in
            Task { @MainActor in self?.inputLevel = Double(level) }
        }
        senderSession = session

        Task {
            do {
                try await session.start(receiverHost: host, pairingCode: code)
                isSenderRunning = true
            } catch {
                senderStatus = "Failed to start sender: \(error.localizedDescription)"
                await session.stop()
                senderSession = nil
                isSenderRunning = false
            }
        }
    }

    func stopSender() {
        guard let session = senderSession else {
            return
        }

        Task {
            await session.stop()
            senderSession = nil
            inputLevel = 0
            isSenderRunning = false
        }
    }

    func startReceiver() {
        let session = ReceiverSession()
        session.volume = Float(receiverVolume)
        session.onStatus = { [weak self] message in
            Task { @MainActor in self?.receiverStatus = message }
        }
        session.onPairingCode = { [weak self] code in
            Task { @MainActor in self?.receiverPairingCode = code }
        }
        session.onBufferFrames = { [weak self] frames in
            Task { @MainActor in self?.receiverBufferFrames = frames }
        }

        do {
            receiverLocalAddress = LocalNetworkInfo.ipv4Summary()
            try session.start()
            receiverSession = session
            isReceiverRunning = true
        } catch {
            receiverStatus = "Failed to start receiver: \(error.localizedDescription)"
            session.stop()
            receiverSession = nil
            isReceiverRunning = false
        }
    }

    func stopReceiver() {
        receiverSession?.stop()
        receiverSession = nil
        isReceiverRunning = false
    }

    func shutdown() {
        stopSender()
        stopReceiver()
    }
}
