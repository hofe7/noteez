#!/usr/bin/env bash
# Build a release Noteez.app and package it into a drag-to-install DMG.
#
# Uses Flutter, codesign and hdiutil. The bundled app is ad-hoc signed;
# this script does not perform Developer ID signing or Apple notarization.
# Usage: tool/make_dmg.sh
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

# Flutter's local release build can leave App.framework changed after the outer
# app received its ad-hoc signature. Re-sign the complete bundle so a copied app
# still passes macOS's structural code-signature validation. This is not Apple
# notarization and does not remove the first-launch Gatekeeper warning.
echo "==> ad-hoc signing and verification"
codesign --force --deep --sign - \
  --entitlements macos/Runner/Release.entitlements "$APP_SRC"
codesign --verify --deep --strict "$APP_SRC"

echo "==> staging"
mkdir -p "$DIST"
rm -f "$DMG"
STAGE="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT
cp -R "$APP_SRC" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$STAGE/Licenses"
cp LICENSE "$STAGE/Licenses/Noteez.txt"
cp THIRD_PARTY_LICENSES.md "$STAGE/Licenses/Third-Party.md"

cp docs/install-guide-ko.txt "$STAGE/여는 법.txt"

echo "==> hdiutil create"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
cleanup
trap - EXIT

SIZE=$(du -h "$DMG" | cut -f1)
echo "==> done: $DMG ($SIZE)"
codesign -dv "$APP_SRC" 2>&1 | grep -q "adhoc\|Signature" && echo "   (note: app is unsigned/adhoc — Gatekeeper will warn until notarized)" || true
