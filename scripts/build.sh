#!/bin/bash
# Builds build/SpotifyMini.app. Set SIGN_ID to a codesigning identity; ad-hoc signature by default.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/SpotifyMini"

APP=build/SpotifyMini.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SpotifyMini"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --sign "${SIGN_ID:--}" --options runtime \
    --entitlements Resources/SpotifyMini.entitlements "$APP"

echo "Built $APP"
