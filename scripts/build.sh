#!/bin/bash
# Builds build/SpotifyMini.app.
#   SIGN_ID       codesigning identity; ad-hoc signature by default
#   ARCHS         space-separated architectures, e.g. "arm64 x86_64"; host architecture by default
#   VERSION       CFBundleShortVersionString, e.g. 1.2.0; Info.plist value by default
#   BUILD_NUMBER  CFBundleVersion; Info.plist value by default
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH_FLAGS=()
for arch in ${ARCHS:-}; do
    ARCH_FLAGS+=(--arch "$arch")
done
# Bash 3.2 treats an empty array as unbound under `set -u`.
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/SpotifyMini"

APP=build/SpotifyMini.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SpotifyMini"
cp Resources/Info.plist "$APP/Contents/Info.plist"

PLIST="$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
fi

codesign --force --sign "${SIGN_ID:--}" --options runtime \
    --entitlements Resources/SpotifyMini.entitlements "$APP"

echo "Built $APP"
