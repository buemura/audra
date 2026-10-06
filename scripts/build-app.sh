#!/usr/bin/env bash
# Builds an Apple Silicon, ad-hoc-signed "build/Screen Reader.app".
# xcodebuild (not swift build) is required: it compiles MLX's Metal shaders.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Screen Reader.app"
DERIVED="build/DerivedData"
PRODUCTS="$DERIVED/Build/Products/Release"

xcodebuild build -scheme ScreenReader -configuration Release \
    -destination 'platform=macOS,arch=arm64' -derivedDataPath "$DERIVED" -quiet

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$PRODUCTS/ScreenReader" "$APP/Contents/MacOS/ScreenReader"
cp Support/Info.plist "$APP/Contents/Info.plist"

# Package frameworks: MLX, KokoroSwift, MisakiSwift, eSpeak NG, …
find "$PRODUCTS" "$PRODUCTS/PackageFrameworks" -maxdepth 1 -name '*.framework' -exec cp -R {} "$APP/Contents/Frameworks/" \;
# SwiftPM resource bundles: MLX's Metal library, Kokoro config, Misaki dictionaries, KeyboardShortcuts' localizations.
find "$PRODUCTS" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

codesign --force --deep --sign - "$APP"
echo "Built $APP"
