#!/bin/sh
# Runs tool/screenshots.sh while holding a machine-wide lock, so several
# checkouts (git worktrees) can take real-app screenshots without killing
# each other's app. Usage: tool/shot_locked.sh integration_test/x_test.dart
lock=/tmp/cutline-screenshots.lock
while ! mkdir "$lock" 2>/dev/null; do
  # A lock older than 20 minutes is left over from a crashed run.
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +20 2>/dev/null)" ]; then
    rmdir "$lock" 2>/dev/null
  fi
  sleep 5
done
trap 'rmdir "$lock" 2>/dev/null' EXIT INT TERM
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
"$(dirname "$0")/screenshots.sh" "$@"
