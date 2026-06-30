#!/bin/sh
# Run the complete PDF Pages regression suite (unit + UI).
set -e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
SCHEME="pdfpagearranger"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

cd "$ROOT"

if [ ! -x "$XCODEBUILD" ]; then
  echo "run-full-regression: Xcode not found at $XCODEBUILD" >&2
  exit 1
fi

echo "run-full-regression: running complete PDF Pages regression suite..."
"$XCODEBUILD" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  test

echo "run-full-regression: all regression tests passed."
