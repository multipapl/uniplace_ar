#!/usr/bin/env bash
#
# snapshot.sh — render every chrome screen to PNG via the preview harness (no ARKit).
#
# Builds UP_AR for each simulator, then for each screen name launches the app with
# UP_SNAPSHOT_VIEW set (see __SnapshotHarness.swift) and grabs a screenshot.
# Output lands in Tools/snapshots/<device-slug>/.
#
# Usage:
#   Tools/snapshot.sh                          # default devices (iPhone + iPad Air), all views
#   Tools/snapshot.sh music help               # all default devices, only these views
#   Tools/snapshot.sh --device "iPhone 17"     # one device (repeat --device for more)
#   Tools/snapshot.sh --device "iPad Air 11-inch (M4)" gallery_video
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="multipapl.UPAR"
DD="/tmp/upar_dd"
APP="$DD/Build/Products/Debug-iphonesimulator/UP_AR.app"

DEVICES=()
VIEWS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICES+=("$2"); shift 2 ;;
    *)        VIEWS+=("$1"); shift ;;
  esac
done

# Defaults: a SMALL iPhone (worst case for overlaps — matches the iPhone 11 Pro / 12
# test devices) plus the iPad Air (820x1180 pt, identical layout to the iPad Air 4 we
# test on). If it fits on the 11 Pro it fits on bigger phones. Add "iPhone SE
# (3rd generation)" for the absolute smallest (375x667) when stress-testing.
if [ ${#DEVICES[@]} -eq 0 ]; then
  DEVICES=("iPhone 11 Pro" "iPad Air 11-inch (M4)")
fi
if [ ${#VIEWS[@]} -eq 0 ]; then
  VIEWS=(start start_floorpicker loading calibration calibration_found \
         hud hud_locomotion hud_debug menu settings floorpicker help \
         music gallery_video gallery_image)
fi

shoot_device() {
  local device="$1"
  local slug out
  slug="$(echo "$device" | tr ' ' '-' | tr -d '()' | tr 'A-Z' 'a-z')"
  out="$REPO/Tools/snapshots/$slug"
  mkdir -p "$out"

  echo "▸ Building UP_AR for '$device'…"
  xcodebuild build -project "$REPO/UP_AR.xcodeproj" -scheme UP_AR -configuration Debug \
    -destination "platform=iOS Simulator,name=$device" -derivedDataPath "$DD" >/dev/null

  xcrun simctl boot "$device" 2>/dev/null || true
  xcrun simctl bootstatus "$device" >/dev/null 2>&1 || true
  xcrun simctl install "$device" "$APP"

  for v in "${VIEWS[@]}"; do
    xcrun simctl terminate "$device" "$BUNDLE_ID" 2>/dev/null || true
    sleep 0.5
    SIMCTL_CHILD_UP_SNAPSHOT_VIEW="$v" xcrun simctl launch "$device" "$BUNDLE_ID" >/dev/null
    sleep 4
    xcrun simctl io "$device" screenshot "$out/$v.png" >/dev/null 2>&1
    echo "  ✓ $v"
  done

  xcrun simctl terminate "$device" "$BUNDLE_ID" 2>/dev/null || true
  echo "▸ $device → $out"
}

for d in "${DEVICES[@]}"; do
  shoot_device "$d"
done
