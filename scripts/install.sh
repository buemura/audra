#!/usr/bin/env bash
# Installs the latest Audra release into /Applications:
#   curl -fsSL https://raw.githubusercontent.com/buemura/audra/main/scripts/install.sh | bash
# Set AUDRA_VERSION=0.1.0 to install a specific release.
# curl doesn't quarantine what it downloads, so Gatekeeper doesn't block the first launch.
set -euo pipefail

REPO="buemura/audra"
DEST="/Applications/Audra.app"

if [ "$(uname -s)" != "Darwin" ] || [ "$(uname -m)" != "arm64" ]; then
    echo "Audra needs macOS on Apple Silicon." >&2
    exit 1
fi

if [ -n "${AUDRA_VERSION:-}" ]; then
    TAG="v${AUDRA_VERSION#v}"
else
    TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"
    [ -n "$TAG" ] || { echo "Couldn't find the latest Audra release." >&2; exit 1; }
fi
VERSION="${TAG#v}"
BASE="https://github.com/$REPO/releases/download/$TAG"
DMG_NAME="Audra-$VERSION.dmg"

TMP="$(mktemp -d)"
MOUNT="$TMP/mount"
cleanup() {
    hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "Downloading Audra $VERSION…"
curl -fL --progress-bar "$BASE/$DMG_NAME" -o "$TMP/$DMG_NAME"
curl -fsSL "$BASE/$DMG_NAME.sha256" -o "$TMP/$DMG_NAME.sha256"
(cd "$TMP" && shasum -a 256 -c "$DMG_NAME.sha256" >/dev/null) \
    || { echo "Checksum mismatch; aborting." >&2; exit 1; }

mkdir -p "$MOUNT"
hdiutil attach "$TMP/$DMG_NAME" -nobrowse -readonly -quiet -mountpoint "$MOUNT"

# Quit a running copy and wait for it to exit before replacing it.
pkill -x Audra 2>/dev/null || true
while pgrep -x Audra >/dev/null; do sleep 0.1; done

SUDO=""
[ -w /Applications ] || SUDO="sudo"
$SUDO rm -rf "$DEST"
$SUDO ditto "$MOUNT/Audra.app" "$DEST"
$SUDO xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "Installed Audra $VERSION to $DEST"
echo "If reading stops working after an update, re-grant Accessibility access:"
echo "  tccutil reset Accessibility com.buemura.Audra"
open "$DEST"
