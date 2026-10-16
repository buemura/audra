#!/usr/bin/env bash
# Builds the app and packages it as build/Audra-<version>.dmg: a fixed window with a background arrow
# telling the user to drag Audra onto the Applications shortcut.
# Laying out the window drives Finder via AppleScript, so the first run asks for Automation permission.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)"
VOLNAME="Audra"
STAGING="build/dmg"
RW_DMG="build/Audra-rw.dmg"
DMG="build/Audra-$VERSION.dmg"
MOUNT="/Volumes/$VOLNAME"

rm -rf "$STAGING" "$RW_DMG" "$DMG"
mkdir -p "$STAGING/.background"
cp -R "build/Audra.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Background at 1x and 2x, combined into one TIFF so Retina screens get the sharp version.
swift scripts/dmg-background.swift "build/dmg-background.png" 1
swift scripts/dmg-background.swift "build/dmg-background@2x.png" 2
tiffutil -cathidpicheck "build/dmg-background.png" "build/dmg-background@2x.png" \
    -out "$STAGING/.background/background.tiff" 2>/dev/null

# A writable image to lay out, converted to a compressed read-only one afterwards.
[ -d "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet -force
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -ov -format UDRW -fs HFS+ "$RW_DMG" >/dev/null
hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen -quiet

osascript <<EOF
tell application "Finder"
    tell disk "$VOLNAME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "Audra.app" of container window to {170, 180}
        set position of item "Applications" of container window to {470, 180}
        close
        open
        delay 1
        -- Finder can restore a remembered size when the window reopens; set it again.
        set the bounds of container window to {200, 120, 840, 520}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

chmod -Rf go-w "$MOUNT" || true
sync
hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -rf "$STAGING" "$RW_DMG"
echo "Created $DMG"
