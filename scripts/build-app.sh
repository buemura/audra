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
FRAMEWORK_DIRS=("$PRODUCTS")
[ -d "$PRODUCTS/PackageFrameworks" ] && FRAMEWORK_DIRS+=("$PRODUCTS/PackageFrameworks")
find "${FRAMEWORK_DIRS[@]}" -maxdepth 1 -name '*.framework' -exec cp -R {} "$APP/Contents/Frameworks/" \;
# SwiftPM resource bundles: MLX's Metal library, Kokoro config, Misaki dictionaries, KeyboardShortcuts' localizations.
find "$PRODUCTS" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

# License notices: the app's GPL-3.0 license, the third-party notices and the vendored packages' licenses.
mkdir -p "$APP/Contents/Resources/Licenses"
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cp Packages/ESpeakNG/LICENSE "$APP/Contents/Resources/Licenses/eSpeakNG-LICENSE"
cp Packages/KokoroSwift/LICENSE "$APP/Contents/Resources/Licenses/KokoroSwift-LICENSE"

codesign --force --deep --sign - "$APP"
echo "Built $APP"
