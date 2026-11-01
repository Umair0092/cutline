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
if [ ! -f test_media/speech.mp4 ] && command -v say >/dev/null; then
  say -v Samantha -o test_media/speech.aiff "Hello and welcome to my channel. \
Today we are talking about deadlines. Um, let me restart. Okay. Deadlines \
are important because they keep projects moving. Thanks for watching."
  ffmpeg -loglevel error -y -f lavfi -i "testsrc2=size=1280x720:rate=30" \
    -i test_media/speech.aiff -c:v libx264 -pix_fmt yuv420p -c:a aac \
    -shortest test_media/speech.mp4
fi
export SCREENSHOT_DIR="$PWD/screenshots" SAMPLE_VIDEO="$PWD/test_media/sample.mp4"
export SPEECH_VIDEO="$PWD/test_media/speech.mp4"
# Optional: put ggml-base.bin in test_media to run the real transcription test.
[ -f test_media/ggml-base.bin ] && export WHISPER_MODEL="$PWD/test_media/ggml-base.bin"
files="$*"
[ -z "$files" ] && files=$(ls integration_test/*_test.dart)
for f in $files; do
  # The previous run's app can linger and block the next launch.
  pkill -x cutline 2>/dev/null || true
  # A launch occasionally hangs; give each file 10 minutes at most.
  perl -e 'alarm shift; exec @ARGV' 600 flutter test "$f" -d macos
done
echo "Screenshots saved to ./screenshots"
