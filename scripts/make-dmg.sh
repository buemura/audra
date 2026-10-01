#!/usr/bin/env bash
# Builds the app and packages it as build/ScreenReader-<version>.dmg with an Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)"
STAGING="build/dmg"
DMG="build/ScreenReader-$VERSION.dmg"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "build/Screen Reader.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Screen Reader" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"
echo "Created $DMG"
