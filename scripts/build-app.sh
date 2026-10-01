#!/usr/bin/env bash
# Builds a universal, ad-hoc-signed "build/Screen Reader.app".
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Screen Reader.app"
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)

swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ScreenReader" "$APP/Contents/MacOS/ScreenReader"
cp Support/Info.plist "$APP/Contents/Info.plist"

# SwiftPM resource bundles (e.g. KeyboardShortcuts' localizations) must ship inside the app.
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

codesign --force --deep --sign - "$APP"
echo "Built $APP"
