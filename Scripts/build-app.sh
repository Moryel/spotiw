#!/bin/sh
# Builds Spotiw.app. Pass "install" to copy it to /Applications and start it.
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_PATH="${BUILD_PATH:-$ROOT_DIR/.build}"
APP_DIR="$ROOT_DIR/build/Spotiw.app"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --build-path "$BUILD_PATH" --product Spotiw
BIN_DIR="$(swift build -c "$CONFIGURATION" --build-path "$BUILD_PATH" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BIN_DIR/Spotiw" "$APP_DIR/Contents/MacOS/Spotiw"
# ad-hoc signature so macOS remembers the Automation (Spotify) permission
codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR"

if [ "${1:-}" = "install" ]; then
    pkill -x Spotiw 2>/dev/null || true
    rm -rf /Applications/Spotiw.app
    cp -R "$APP_DIR" /Applications/Spotiw.app
    open /Applications/Spotiw.app
    echo "Installed /Applications/Spotiw.app"
fi
