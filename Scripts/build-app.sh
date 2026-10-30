#!/bin/sh
# Builds Spotiw.app.
#   sh Scripts/build-app.sh            build for this Mac
#   sh Scripts/build-app.sh install    build, copy to /Applications and start it
#   sh Scripts/build-app.sh release    universal (Apple Silicon + Intel) build and build/Spotiw.zip
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
BUILD_PATH="${BUILD_PATH:-$ROOT_DIR/.build}"
APP_DIR="$ROOT_DIR/build/Spotiw.app"
MODE="${1:-}"

cd "$ROOT_DIR"

# prints the path of the built binary for one architecture (or the host one)
build_binary() {
    if [ -n "${1:-}" ]; then
        # The command line tools ship the Swift back-deployment libraries for arm64 only.
        # Spotiw uses neither concurrency nor parameter packs, so Intel builds skip them.
        EXTRA=""
        if [ "$1" = "x86_64" ]; then
            EXTRA="-Xswiftc -runtime-compatibility-version -Xswiftc none"
        fi
        # shellcheck disable=SC2086
        # separate build folders: both architectures would otherwise write the same output path
        swift build -c "$CONFIGURATION" --build-path "$BUILD_PATH/$1" --product Spotiw --arch "$1" $EXTRA >&2
        # shellcheck disable=SC2086
        echo "$(swift build -c "$CONFIGURATION" --build-path "$BUILD_PATH/$1" --arch "$1" $EXTRA --show-bin-path)/Spotiw"
    else
        swift build -c "$CONFIGURATION" --build-path "$BUILD_PATH" --product Spotiw >&2
        echo "$(swift build -c "$CONFIGURATION" --build-path "$BUILD_PATH" --show-bin-path)/Spotiw"
    fi
}

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ "$MODE" = "release" ]; then
    # Touch Bar Macs from 2016-2019 are Intel, the 13" M1/M2 models are Apple Silicon
    ARM_BIN="$(build_binary arm64)"
    INTEL_BIN="$(build_binary x86_64)"
    lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$APP_DIR/Contents/MacOS/Spotiw"
else
    cp "$(build_binary)" "$APP_DIR/Contents/MacOS/Spotiw"
fi

# ad-hoc signature so macOS remembers the Automation (Spotify) permission;
# codesign refuses Finder / iCloud extended attributes, so strip them first
xattr -cr "$APP_DIR"
codesign --force --sign - "$APP_DIR"
echo "Built $APP_DIR"

case "$MODE" in
    install)
        pkill -x Spotiw 2>/dev/null || true
        rm -rf /Applications/Spotiw.app
        cp -R "$APP_DIR" /Applications/Spotiw.app
        open /Applications/Spotiw.app
        echo "Installed /Applications/Spotiw.app"
        ;;
    release)
        rm -f "$ROOT_DIR/build/Spotiw.zip"
        ditto -c -k --keepParent "$APP_DIR" "$ROOT_DIR/build/Spotiw.zip"
        echo "Packed $ROOT_DIR/build/Spotiw.zip"
        ;;
esac
