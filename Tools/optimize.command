#!/bin/zsh
# Double-clickable wrapper: optimize newly-synced USDZ layers into ASTC .reality / copy geometry.
# Lives next to optimize_assets.py; runs it and leaves the window open on finish.
cd "$(dirname "$0")"
./optimize_assets.py "$@"
status=$?
echo
echo "[exit $status] press any key to close..."
read -k1 -s
