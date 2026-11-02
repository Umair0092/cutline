#!/bin/sh
# Makes the macOS and Windows app icons from the logo in
# lib/ui/splash_screen.dart. Needs ffmpeg and macOS's sips.
set -e
out=build/icons
ICON_DIR="$PWD/$out" flutter test tool/icons/make_icons_test.dart
set_dir=macos/Runner/Assets.xcassets/AppIcon.appiconset
for s in 16 32 64 128 256 512 1024; do
  sips -s format png -z $s $s "$out/macos-1024.png" --out "$set_dir/app_icon_$s.png" >/dev/null
done
# Windows .ico with the sizes Explorer and the taskbar ask for.
for s in 16 24 32 48 64 128 256; do
  sips -s format png -z $s $s "$out/full-1024.png" --out "$out/win-$s.png" >/dev/null
done
ffmpeg -loglevel error -y \
  -i "$out/win-16.png" -i "$out/win-24.png" -i "$out/win-32.png" \
  -i "$out/win-48.png" -i "$out/win-64.png" -i "$out/win-128.png" \
  -i "$out/win-256.png" \
  -map 0 -map 1 -map 2 -map 3 -map 4 -map 5 -map 6 -c png \
  windows/runner/resources/app_icon.ico
mkdir -p docs/images
sips -s format png -z 256 256 "$out/full-1024.png" --out docs/images/icon.png >/dev/null
echo "Icons updated."
