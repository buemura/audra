#!/usr/bin/env bash
# Builds the DMG and publishes it as GitHub release v<CFBundleShortVersionString>.
# Bump the version in Support/Info.plist and commit before running. Needs the gh CLI.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Support/Info.plist)"
TAG="v$VERSION"
DMG="build/Audra-$VERSION.dmg"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "Commit your changes first." >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Tag $TAG already exists; bump CFBundleShortVersionString in Support/Info.plist." >&2
    exit 1
fi

./scripts/make-dmg.sh
(cd build && shasum -a 256 "Audra-$VERSION.dmg" > "Audra-$VERSION.dmg.sha256")

git tag -a "$TAG" -m "Audra $VERSION"
git push origin "$TAG"
gh release create "$TAG" "$DMG" "$DMG.sha256" --title "Audra $VERSION" --generate-notes
echo "Released $TAG"
