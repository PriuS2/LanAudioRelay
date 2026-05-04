# LAN Audio Relay

Windows 11용 WPF/.NET 앱과 macOS 14+용 SwiftUI 앱으로, 같은 LAN 안에서 시스템 오디오를 낮은 지연으로 전달합니다.

## Windows Build

```powershell
dotnet restore .\src\LanAudioRelay\LanAudioRelay.csproj
dotnet restore .\tests\LanAudioRelay.Tests\LanAudioRelay.Tests.csproj
dotnet build .\LanAudioRelay.sln --no-restore
dotnet test .\tests\LanAudioRelay.Tests\LanAudioRelay.Tests.csproj --no-restore
```

## Windows Run

```powershell
dotnet run --project .\src\LanAudioRelay\LanAudioRelay.csproj
```

## Windows Publish

```powershell
dotnet publish .\src\LanAudioRelay\LanAudioRelay.csproj -c Release -r win-x64 --self-contained true -o .\dist\LanAudioRelay-win-x64 /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true /p:EnableCompressionInSingleFile=true /p:DebugType=none /p:DebugSymbols=false
```

생성된 실행 파일은 `.\dist\LanAudioRelay-win-x64\LanAudioRelay.exe`입니다.

## macOS

Mac용 SwiftUI 앱은 `mac/LanAudioRelayMac`에 있습니다. Mac + Xcode 환경에서 빌드하세요.

```bash
cd mac/LanAudioRelayMac
swift test
swift build -c release
./Scripts/package-app.sh
```

## 사용 방법

1. 수신 장치에서 앱을 열고 `Receiver` 탭의 `Start Receiver`를 누릅니다.
2. 표시되는 6자리 페어링 코드를 확인합니다.
3. 송신 장치에서 `Sender` 탭의 `Search LAN`을 누르거나 수신 장치의 IP를 직접 입력합니다.
4. 페어링 코드를 입력하고 `Start Streaming`을 누릅니다.

방화벽 알림이 뜨면 같은 사설 네트워크에서 TCP 51360, UDP 51359/51361 통신을 허용해야 합니다.
