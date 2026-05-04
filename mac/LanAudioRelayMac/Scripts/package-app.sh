#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/LanAudioRelayMac.app"
EXEC="$ROOT/.build/release/LanAudioRelayMac"

if [[ ! -x "$EXEC" ]]; then
  swift build -c release --package-path "$ROOT"
fi

rm -rf "$APP" "$APP.zip"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$EXEC" "$APP/Contents/MacOS/LanAudioRelayMac"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/LanAudioRelayMac"

cd "$ROOT/dist"
ditto -c -k --keepParent "LanAudioRelayMac.app" "LanAudioRelayMac.app.zip"

echo "$APP"
