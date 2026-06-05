#!/usr/bin/env bash
# Build a release Noteez.app and package it into a drag-to-install DMG.
#
# Dependency-free (uses only flutter + hdiutil + osascript). Produces an
# UNSIGNED dmg — fine for local/side distribution. For public release, sign
# + notarize the .app BEFORE running this (see THIRD_PARTY_LICENSES.md / A-3b
# notes). Usage:  tool/make_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Noteez"
VOL="$APP_NAME"
DIST="dist"
APP_SRC="build/macos/Build/Products/Release/noteez.app"
DMG="$DIST/$APP_NAME.dmg"

echo "==> flutter build macos --release"
flutter build macos --release

if [[ ! -d "$APP_SRC" ]]; then
  echo "build output not found: $APP_SRC" >&2; exit 1
fi

echo "==> staging"
rm -rf "$DIST" && mkdir -p "$DIST"
STAGE="$(mktemp -d)"
cp -R "$APP_SRC" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
cp THIRD_PARTY_LICENSES.md "$STAGE/Licenses.txt" 2>/dev/null || true

echo "==> hdiutil create"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

SIZE=$(du -h "$DMG" | cut -f1)
echo "==> done: $DMG ($SIZE)"
codesign -dv "$APP_SRC" 2>&1 | grep -q "adhoc\|Signature" && echo "   (note: app is unsigned/adhoc — Gatekeeper will warn until notarized)" || true
