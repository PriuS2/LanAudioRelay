import LanAudioRelayMacCore
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LAN Audio Relay")
                    .font(.largeTitle.weight(.semibold))
                Text("macOS system audio streaming over local network")
                    .foregroundStyle(.secondary)
            }

            TabView {
                senderTab
                    .tabItem { Text("Sender") }

                receiverTab
                    .tabItem { Text("Receiver") }
            }

            Text("Ports: UDP 51359 discovery, TCP 51360 control, UDP 51361 audio")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .onDisappear {
            viewModel.shutdown()
        }
    }

    private var senderTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Receiver")
                .font(.headline)

            HStack {
                Picker("Receiver", selection: $viewModel.selectedReceiver) {
                    Text("Select receiver").tag(Optional<ReceiverAnnouncement>.none)
                    ForEach(viewModel.receivers) { receiver in
                        Text(receiver.displayName).tag(Optional(receiver))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Button("Search LAN") {
                    viewModel.discoverReceivers()
                }
                .disabled(viewModel.isSenderRunning)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Manual receiver IP")
                        .foregroundStyle(.secondary)
                    TextField("", text: $viewModel.manualReceiverIp)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("Pairing code")
                        .foregroundStyle(.secondary)
                    TextField("", text: $viewModel.senderPairingCode)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                }
            }

            HStack {
                Button("Start Streaming") {
                    viewModel.startSender()
                }
                .disabled(viewModel.isSenderRunning)

                Button("Stop") {
                    viewModel.stopSender()
                }
                .disabled(!viewModel.isSenderRunning)
            }

            Text(viewModel.senderStatus)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading) {
                Text("Input level")
                    .foregroundStyle(.secondary)
                ProgressView(value: viewModel.inputLevel, total: 1)
            }

            Spacer()
        }
        .padding(18)
    }

    private var receiverTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Receiver")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Local IP")
                        .foregroundStyle(.secondary)
                    TextField("", text: $viewModel.receiverLocalAddress)
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                }

                VStack(alignment: .leading) {
                    Text("Pairing code")
                        .foregroundStyle(.secondary)
                    TextField("", text: $viewModel.receiverPairingCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.weight(.semibold))
                        .disabled(true)
                        .frame(width: 220)
                }
            }

            HStack {
                Button("Start Receiver") {
                    viewModel.startReceiver()
                }
                .disabled(viewModel.isReceiverRunning)

                Button("Stop") {
                    viewModel.stopReceiver()
                }
                .disabled(!viewModel.isReceiverRunning)
            }

            HStack(spacing: 28) {
                VStack(alignment: .leading) {
                    Text("Volume")
                        .foregroundStyle(.secondary)
                    Slider(value: $viewModel.receiverVolume, in: 0...1)
                        .frame(width: 360)
                }

                VStack(alignment: .leading) {
                    Text("Buffered frames")
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.receiverBufferFrames)")
                        .font(.title3.weight(.semibold))
                }
            }

            Text(viewModel.receiverStatus)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(18)
    }
}
