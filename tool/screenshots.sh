#!/bin/sh
# Runs the integration tests on macOS. Each test can save screenshots of the
# real app window into ./screenshots.
set -e
SCREENSHOT_DIR="$PWD/screenshots" flutter test integration_test -d macos "$@"
echo "Screenshots saved to ./screenshots"
