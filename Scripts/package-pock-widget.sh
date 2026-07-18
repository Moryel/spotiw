#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
PRODUCT_NAME="SpotifPockWidget"
BUNDLE_NAME="Spotiw.pock"
SWIFTPM_BUILD_PATH="${SWIFTPM_BUILD_PATH:-$ROOT_DIR/.swiftpm/xcode/swiftpm-build}"
BUILD_DIR="$SWIFTPM_BUILD_PATH/$CONFIGURATION"
BUNDLE_DIR="$BUILD_DIR/$BUNDLE_NAME"
VISIBLE_BUNDLE_DIR="$ROOT_DIR/$BUNDLE_NAME"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
LIBRARY_PATH="$BUILD_DIR/lib$PRODUCT_NAME.dylib"

cd "$ROOT_DIR"
swift build --disable-sandbox --build-path "$SWIFTPM_BUILD_PATH" -c "$CONFIGURATION" --product "$PRODUCT_NAME"

if [ ! -f "$LIBRARY_PATH" ]; then
    echo "error: expected dynamic library at $LIBRARY_PATH" >&2
    exit 1
fi

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
cp "$INFO_PLIST" "$BUNDLE_DIR/Contents/Info.plist"
cp "$LIBRARY_PATH" "$BUNDLE_DIR/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$BUNDLE_DIR/Contents/MacOS/$PRODUCT_NAME"

rm -rf "$VISIBLE_BUNDLE_DIR"
cp -R "$BUNDLE_DIR" "$VISIBLE_BUNDLE_DIR"

echo "Built $BUNDLE_DIR"
echo "Copied $VISIBLE_BUNDLE_DIR"
