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

# Flutter's local release build can leave App.framework changed after the outer
# app received its ad-hoc signature. Re-sign the complete bundle so a copied app
# still passes macOS's structural code-signature validation. This is not Apple
# notarization and does not remove the first-launch Gatekeeper warning.
echo "==> ad-hoc signing and verification"
codesign --force --deep --sign - \
  --entitlements macos/Runner/Release.entitlements "$APP_SRC"
codesign --verify --deep --strict "$APP_SRC"

echo "==> staging"
rm -rf "$DIST" && mkdir -p "$DIST"
STAGE="$(mktemp -d)"
cp -R "$APP_SRC" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
cp THIRD_PARTY_LICENSES.md "$STAGE/Licenses.txt" 2>/dev/null || true

# Unsigned-app open instructions (no Apple Developer ID yet → Gatekeeper blocks
# double-click on first run).
cat > "$STAGE/여는 법.txt" <<'TXT'
Noteez 설치 / 처음 여는 법
===========================

1. Noteez 를 Applications 폴더로 드래그하세요.

2. 처음 실행할 때 (둘 중 하나):
   • Applications 에서 Noteez 우클릭 → "열기" → 다시 "열기"
   • 또는 시스템 설정 → 개인정보 보호 및 보안 → "확인 없이 열기"
   • 또는 터미널:
       xattr -dr com.apple.quarantine /Applications/Noteez.app

   (아직 Apple 공증을 받지 않아 처음 한 번만 필요합니다.)

3. Noteez 는 메뉴바 앱입니다 — 독에 아이콘이 없어요.
   메뉴바의 스티커 아이콘, 또는 단축키로 씁니다:
     ⌘⇧N  새 메모      ⌘⇧Space  빠른 캡처
     ⌘⇧K  검색         ⌘⇧G      전체 보기
TXT

echo "==> hdiutil create"
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

SIZE=$(du -h "$DMG" | cut -f1)
echo "==> done: $DMG ($SIZE)"
codesign -dv "$APP_SRC" 2>&1 | grep -q "adhoc\|Signature" && echo "   (note: app is unsigned/adhoc — Gatekeeper will warn until notarized)" || true
