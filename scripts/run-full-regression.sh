#!/bin/sh
# Run the complete PDF Pages regression suite (unit + UI).
set -e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
XCODEBUILD="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
SCHEME="pdfpagearranger"

cd "$ROOT"

if [ ! -x "$XCODEBUILD" ]; then
  echo "run-full-regression: Xcode not found at $XCODEBUILD" >&2
  exit 1
fi

resolve_destination() {
  if [ -n "${REGRESSION_DESTINATION:-}" ]; then
    printf '%s\n' "$REGRESSION_DESTINATION"
    return
  fi

  # Prefer common simulator names; fall back so CI/local machines without iPhone 17 still run.
  for name in "iPhone 17" "iPhone 16" "iPhone 15" "iPhone 14"; do
    if xcrun simctl list devices available 2>/dev/null | grep -F "$name (" >/dev/null 2>&1; then
      printf 'platform=iOS Simulator,name=%s\n' "$name"
      return
    fi
  done

  printf 'platform=iOS Simulator,name=iPhone 17\n'
}

DESTINATION="$(resolve_destination)"
echo "run-full-regression: running complete PDF Pages regression suite..."
echo "run-full-regression: destination=$DESTINATION"
"$XCODEBUILD" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  test

echo "run-full-regression: all regression tests passed."
