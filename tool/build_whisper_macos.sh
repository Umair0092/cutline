#!/bin/bash
# Builds whisper.cpp's command-line tool (MIT licence) for macOS into
# third_party/whisper/macos/whisper-cli. Static, with the Metal shaders
# embedded, so it's one self-contained file.
#
#   tool/build_whisper_macos.sh                         # this Mac's arch
#   ARCHS="arm64 x86_64" tool/build_whisper_macos.sh    # universal
set -euo pipefail

TAG=v1.9.5
COMMIT=d1be6fde11ac6e0407606b4e42fe72d34add8037
MIN_MACOS=12.0
ARCHS=${ARCHS:-$(uname -m)}

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CACHE="$ROOT/third_party/.cache"
SRC="$CACHE/whisper.cpp"
OUT="$ROOT/third_party/whisper/macos"
mkdir -p "$CACHE" "$OUT"

if [ ! -d "$SRC/.git" ]; then
  git clone --quiet --depth 1 --branch "$TAG" https://github.com/ggml-org/whisper.cpp.git "$SRC"
fi
actual=$(git -C "$SRC" rev-parse HEAD)
if [ "$actual" != "$COMMIT" ]; then
  echo "whisper.cpp $TAG is at $actual, expected $COMMIT" >&2
  exit 1
fi

built=()
for arch in $ARCHS; do
  dir="$CACHE/whisper-build-$arch"
  cmake -S "$SRC" -B "$dir" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MIN_MACOS" \
    -DBUILD_SHARED_LIBS=OFF \
    -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON \
    -DGGML_NATIVE=OFF \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF
  cmake --build "$dir" --config Release -j "$(sysctl -n hw.ncpu)" --target whisper-cli
  built+=("$dir/bin/whisper-cli")
done

lipo -create "${built[@]}" -output "$OUT/whisper-cli"
cp "$SRC/LICENSE" "$OUT/LICENSE.txt"
if otool -L "$OUT/whisper-cli" | grep -vE ':$|/System/Library/|/usr/lib/'; then
  echo "whisper-cli links to non-system libraries" >&2
  exit 1
fi
lipo -info "$OUT/whisper-cli"
