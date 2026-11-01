#!/bin/bash
# Builds an LGPL FFmpeg (ffmpeg + ffprobe) for macOS into
# third_party/ffmpeg/macos/. GPL and non-free parts are off, nothing is
# picked up from Homebrew, and H.264/HEVC encoding uses Apple's
# VideoToolbox, so the result links only to system frameworks.
#
#   tool/build_ffmpeg_macos.sh            # this Mac's architecture
#   ARCHS="arm64 x86_64" tool/build_ffmpeg_macos.sh   # universal binary
set -euo pipefail

VERSION=9.0.2
SHA256=8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e
MIN_MACOS=12.0
ARCHS=${ARCHS:-$(uname -m)}

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CACHE="$ROOT/third_party/.cache"
OUT="$ROOT/third_party/ffmpeg/macos"
TARBALL="$CACHE/ffmpeg-$VERSION.tar.xz"
mkdir -p "$CACHE" "$OUT"

if [ ! -f "$TARBALL" ]; then
  curl -fL --retry 3 "https://ffmpeg.org/releases/ffmpeg-$VERSION.tar.xz" -o "$TARBALL.tmp"
  mv "$TARBALL.tmp" "$TARBALL"
fi
echo "$SHA256  $TARBALL" | shasum -a 256 -c -

JOBS=$(sysctl -n hw.ncpu)
built=()
for arch in $ARCHS; do
  src="$CACHE/build-$arch"
  rm -rf "$src" && mkdir -p "$src"
  tar -xf "$TARBALL" -C "$src" --strip-components 1
  cross=()
  if [ "$arch" != "$(uname -m)" ]; then
    cross=(--enable-cross-compile --target-os=darwin --arch="$arch")
  fi
  (
    cd "$src"
    ./configure \
      --prefix="$src/install" \
      --cc="clang -arch $arch" \
      ${cross[@]+"${cross[@]}"} \
      --extra-cflags="-mmacosx-version-min=$MIN_MACOS" \
      --extra-ldflags="-mmacosx-version-min=$MIN_MACOS" \
      --disable-gpl --disable-nonfree \
      --disable-autodetect \
      --enable-videotoolbox --enable-audiotoolbox --enable-zlib \
      --disable-network --disable-ffplay --disable-doc --disable-debug \
      --enable-static --disable-shared
    make -j"$JOBS"
    make install
  )
  built+=("$src/install/bin")
done

for tool in ffmpeg ffprobe; do
  inputs=()
  for dir in "${built[@]}"; do inputs+=("$dir/$tool"); done
  lipo -create "${inputs[@]}" -output "$OUT/$tool"
done

# Fail if anything outside the OS slipped in.
if otool -L "$OUT/ffmpeg" | tail -n +2 | grep -vE '/System/Library/|/usr/lib/'; then
  echo "ffmpeg links to non-system libraries" >&2
  exit 1
fi
"$OUT/ffmpeg" -hide_banner -version | head -1
lipo -info "$OUT/ffmpeg"
