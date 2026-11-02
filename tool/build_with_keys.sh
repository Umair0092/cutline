#!/bin/sh
# Builds a personal copy of Cutline with your API keys built in, so it
# doesn't ask for them. Put them in keys.env (never committed):
#   GROQ_API_KEY=gsk_...
#   GIPHY_API_KEY=...
# Anyone with the built app can dig the keys out: keep these builds to
# yourself.
#   tool/build_with_keys.sh apk      # Android, then: adb install -r ...
#   tool/build_with_keys.sh macos
set -e
cd "$(dirname "$0")/.."
[ -f keys.env ] || { echo "keys.env is missing (see the comment at the top)."; exit 1; }
flutter build "${1:-apk}" --release --dart-define-from-file=keys.env
