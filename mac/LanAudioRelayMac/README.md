# LAN Audio Relay for macOS

Native SwiftUI macOS 14+ app that speaks the same LAN protocol as the Windows `LAN Audio Relay` app.

## Build

From the repository root on a Mac with Xcode 15+:

```bash
cd mac/LanAudioRelayMac
swift test
swift build -c release
./Scripts/package-app.sh
```

The packaged app is written to:

```text
dist/LanAudioRelayMac.app
dist/LanAudioRelayMac.app.zip
```

## Permissions

Mac Sender uses ScreenCaptureKit to capture system audio. The first run may require:

1. Allow Screen Recording for the app in System Settings.
2. Quit and reopen the app after granting permission.
3. Allow local network/firewall prompts for LAN discovery and audio transport.

This v1 build is intentionally unsigned. If macOS blocks it, right-click the app and choose Open.

## Interop Targets

- Windows Sender -> Mac Receiver
- Mac Sender -> Windows Receiver
- Mac Sender -> Mac Receiver

Ports must match the Windows app:

- UDP 51359 discovery
- TCP 51360 control/pairing
- UDP 51361 audio
