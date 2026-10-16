#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
ARCH="$(uname -m)"
if [ -n "${RELEASE_TAG:-}" ] && [ "$RELEASE_TAG" != "v$VERSION" ]; then
  echo "Release tag must match Info.plist version v$VERSION" >&2
  exit 1
fi
# CI and public archives must not use a local development certificate.
EVENT_HORIZON_SIGNING_IDENTITY=- bash scripts/build.sh
APP="$PROJECT_DIR/dist/Focused Break.app"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
lipo -verify_arch "$ARCH" "$APP/Contents/MacOS/EventHorizon"
OUTPUT="$PROJECT_DIR/dist/release"
mkdir -p "$OUTPUT"
NAME="Focused-Break-macOS-$ARCH"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/$NAME.zip"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Focused Break.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname 'Focused Break' -srcfolder "$STAGING" -ov -format UDZO "$OUTPUT/$NAME.dmg"
cd "$OUTPUT"
shasum -a 256 "$NAME.zip" "$NAME.dmg" > "SHA256SUMS-$ARCH.txt"
printf 'Packaged Focused Break %s (%s)\n' "$VERSION" "$ARCH"
