#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUNDLE_NAME="Spotiw.pock"
SOURCE_BUNDLE="$ROOT_DIR/$BUNDLE_NAME"
TARGET_DIR="${HOME}/Library/Application Support/Pock/Widgets"
TARGET_BUNDLE="$TARGET_DIR/$BUNDLE_NAME"

if [ ! -d "$SOURCE_BUNDLE" ]; then
    echo "error: expected widget bundle at $SOURCE_BUNDLE" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_BUNDLE"
cp -R "$SOURCE_BUNDLE" "$TARGET_BUNDLE"

chmod -R u+rw "$TARGET_BUNDLE"

echo "Installed $TARGET_BUNDLE"
