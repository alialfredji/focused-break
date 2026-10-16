#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
OUTPUT_DIR="$PROJECT_DIR/dist"
if [ "${1:-}" = "--preview" ]; then
  OUTPUT_DIR="$PROJECT_DIR/dist/gravity-preview"
  APP="$OUTPUT_DIR/Focused Break Preview.app"
else
  APP="$OUTPUT_DIR/Focused Break.app"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/EventHorizon" "$APP/Contents/MacOS/EventHorizon"
cp "$PROJECT_DIR/Info.plist" "$APP/Contents/Info.plist"
if [ "${1:-}" = "--preview" ]; then
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName Focused Break Preview' "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Focused Break Preview' "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.alialfredji.event-horizon.preview' "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.6.0' "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 6' "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleURLTypes:0:CFBundleURLSchemes:0 eventhorizonpreview' "$APP/Contents/Info.plist"
fi
# App launches load resources from Contents/Resources; swift run uses Bundle.module.
cp "$PROJECT_DIR/Sources/EventHorizon/BlackHole.metal" "$APP/Contents/Resources/BlackHole.metal"
cp "$PROJECT_DIR/Sources/EventHorizon/HaveABreak.gif" "$APP/Contents/Resources/HaveABreak.gif"
swift "$PROJECT_DIR/scripts/MakeIcon.swift" "$OUTPUT_DIR/AppIcon.iconset"
iconutil -c icns "$OUTPUT_DIR/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
SIGNING_IDENTITY="${EVENT_HORIZON_SIGNING_IDENTITY:--}"
if [ "$SIGNING_IDENTITY" = "-" ] && [ -f "$PROJECT_DIR/.signing-identity" ]; then
  SIGNING_IDENTITY="$(cat "$PROJECT_DIR/.signing-identity")"
fi
codesign --force --deep --sign "$SIGNING_IDENTITY" --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
printf '\nBuilt: %s\n' "$APP"
