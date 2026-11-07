#!/usr/bin/env bash
# Captures the App Store listing screenshots (HackDifferentUITests/StoreScreenshots) on an iPhone and an iPad
# simulator, signed in with an App Review code against production.
#
#   REVIEW_CODE=XXXX-XXXX-XXXX-XXXX ios/Scripts/store-screenshots.sh
#
# IPHONE (default "iPhone 17 Pro Max", the 6.9" slot) and IPAD (default "iPad Pro 13-inch (M5)") pick the simulators,
# DEVICES=iphone or DEVICES=ipad runs one, LOCATION=lat,lon sets the simulator's location first (default: Salt Lake
# City, near 801 Labs), and OUT is where the PNGs go (default ~/Desktop/hack-different-screenshots/<iphone|ipad>/).
set -euo pipefail

: "${REVIEW_CODE:?Set REVIEW_CODE to the Hack Different App Review code (console Settings > App Review)}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="${OUT:-$HOME/Desktop/hack-different-screenshots}"
location="${LOCATION:-40.7608,-111.8910}"

# Exported, not passed as arguments: xcodebuild forwards TEST_RUNNER_* to the runner and prints build settings.
export TEST_RUNNER_HACKDIFFERENT_UITEST_REVIEW_CODE="$REVIEW_CODE"
export TEST_RUNNER_HACKDIFFERENT_UITEST_SCREENSHOT_DIR="$out"
if [[ -n "${EVENT:-}" ]]; then export TEST_RUNNER_HACKDIFFERENT_UITEST_EVENT="$EVENT"; fi
if [[ -n "${SPACE:-}" ]]; then export TEST_RUNNER_HACKDIFFERENT_UITEST_SPACE="$SPACE"; fi

udid_for() {
  xcrun simctl list devices available | grep -F "    $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

run_on() {
  local name="$1" udid
  udid="$(udid_for "$name")"
  [[ -n "$udid" ]] || { echo "No available simulator named $name (xcrun simctl list devices)" >&2; return 1; }
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 || true
  xcrun simctl location "$udid" set "$location" || true
  xcrun simctl privacy "$udid" grant location-always com.hackdifferent.app 2>/dev/null || true
  xcodebuild test -project "$repo/HackDifferent.xcodeproj" -scheme "HackDifferent Screenshots" \
    -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:HackDifferentUITests/StoreScreenshots/testListingScreens
}

mkdir -p "$out"
devices="${DEVICES:-iphone ipad}"
if [[ "$devices" == *iphone* ]]; then run_on "${IPHONE:-iPhone 17 Pro Max}"; fi
if [[ "$devices" == *ipad* ]]; then run_on "${IPAD:-iPad Pro 13-inch (M5)}"; fi
echo "Screenshots in $out"
