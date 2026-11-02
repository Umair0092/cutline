#!/bin/bash
# Builds Cutline for macOS and packs it into a DMG in build/dist/.
#
# Signing and notarizing happen when these are set (otherwise the app is
# ad-hoc signed, which runs on this Mac but makes macOS warn elsewhere):
#   CODESIGN_IDENTITY   "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_APPLE_ID     Apple ID email
#   NOTARY_TEAM_ID      10-character team ID
#   NOTARY_PASSWORD     app-specific password for that Apple ID
#
# Run tool/build_ffmpeg_macos.sh and tool/build_whisper_macos.sh first
# (with ARCHS="arm64 x86_64" for a universal app).
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -n 's/^version: \([0-9.]*\).*/\1/p' pubspec.yaml)
flutter build macos --release
built=build/macos/Build/Products/Release/cutline.app
stage=build/dmg
dist=build/dist
rm -rf "$stage" && mkdir -p "$stage" "$dist"
ditto "$built" "$stage/Cutline.app"
app="$stage/Cutline.app"
entitlements=macos/Runner/Release.entitlements

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "Signing with $CODESIGN_IDENTITY"
  sign() {
    codesign --force --timestamp --options runtime \
      --sign "$CODESIGN_IDENTITY" "$@"
  }
  # Inside out: helper tools and frameworks first, then the app.
  find "$app/Contents/Resources/bin" -type f -perm -u+x | while read -r f; do
    sign "$f"
  done
  find "$app/Contents/Frameworks" -depth \( -name "*.dylib" -o -name "*.framework" \) |
    while read -r f; do sign "$f"; done
  sign --entitlements "$entitlements" "$app"
  codesign --verify --deep --strict "$app"
else
  echo "No CODESIGN_IDENTITY: ad-hoc signing (other Macs will warn)."
  codesign --force --deep --sign - "$app"
fi

ln -s /Applications "$stage/Applications"
dmg="$dist/Cutline-$version-macos.dmg"
rm -f "$dmg"
hdiutil create -volname "Cutline $version" -srcfolder "$stage" \
  -ov -format UDZO "$dmg" >/dev/null

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$dmg"
fi
if [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_TEAM_ID:-}" ] &&
  [ -n "${NOTARY_PASSWORD:-}" ]; then
  echo "Notarizing (this takes a few minutes)…"
  xcrun notarytool submit "$dmg" --wait \
    --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD"
  xcrun stapler staple "$dmg"
fi
echo "Made $dmg"
