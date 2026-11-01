#!/bin/sh
# Runs the integration tests on macOS, one file per app launch. Each test can
# save screenshots of the real app window into ./screenshots. Needs ffmpeg to
# make the sample video.
set -e
mkdir -p test_media
if [ ! -f test_media/sample.mp4 ]; then
  ffmpeg -loglevel error -y \
    -f lavfi -i "testsrc2=size=1280x720:rate=30:duration=20" \
    -f lavfi -i "sine=frequency=440:duration=20" \
    -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest test_media/sample.mp4
fi
export SCREENSHOT_DIR="$PWD/screenshots" SAMPLE_VIDEO="$PWD/test_media/sample.mp4"
files="$*"
[ -z "$files" ] && files=$(ls integration_test/*_test.dart)
for f in $files; do
  # The previous run's app can linger and block the next launch.
  pkill -x cutline 2>/dev/null || true
  flutter test "$f" -d macos
done
echo "Screenshots saved to ./screenshots"
