#!/bin/sh
# Runs the integration tests on macOS and copies the screenshots they take
# into ./screenshots.
set -e
SCREENSHOTS=1 flutter test integration_test -d macos "$@"
mkdir -p screenshots
cp ~/Library/Containers/com.umair0092.cutline/Data/tmp/cutline_screenshots/*.png screenshots/
echo "Screenshots saved to ./screenshots"
