#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAME="${MAME:-/usr/games/mame}"
BOOT_IMAGE="$REPO_DIR/bin/kayprocpm2.imd"
BUILD_IMAGE="$REPO_DIR/bin/build.img"

if [ ! -x "$MAME" ]; then
    echo "ERROR: MAME not found at $MAME"
    echo "Install with: sudo apt install mame"
    echo "Or set the MAME environment variable to its path."
    exit 1
fi

if [ ! -f "$BOOT_IMAGE" ]; then
    echo "ERROR: Boot disk image not found at $BOOT_IMAGE"
    echo "Run 'make setup' first (and ensure usr-bin/kayproiv.img exists)."
    exit 1
fi

if [ ! -f "$BUILD_IMAGE" ]; then
    echo "ERROR: Build image not found at $BUILD_IMAGE"
    echo "Run 'make image' to build it first."
    exit 1
fi

# Native resolution is 560x240. Use 1120x480 here for a readable 2x integer scale.
echo "Launching MAME. Press Alt+F4 to close."
exec "$MAME" kayproiv -rompath "$REPO_DIR/bin/roms" -flop1 "$BOOT_IMAGE" -flop2 "$BUILD_IMAGE" \
    -window -nomaximize -resolution 1120x480
