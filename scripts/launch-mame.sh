#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAME="${MAME:-/usr/games/mame}"
MFI_IMAGE="$REPO_DIR/bin/kayproiv.mfi"
BUILD_IMAGE="$REPO_DIR/bin/build.img"
MFI_BUILD="$REPO_DIR/bin/build.mfi"

if [ ! -x "$MAME" ]; then
    echo "ERROR: MAME not found at $MAME"
    echo "Install with: sudo apt install mame"
    echo "Or set the MAME environment variable to its path."
    exit 1
fi

if [ ! -f "$MFI_IMAGE" ]; then
    echo "ERROR: Boot disk image not found at $MFI_IMAGE"
    echo "Place kayproiv.img in usr-bin/ and run 'make setup' first."
    exit 1
fi

if [ ! -f "$BUILD_IMAGE" ]; then
    echo "ERROR: Build image not found at $BUILD_IMAGE"
    echo "Run 'make image' to build it first."
    exit 1
fi

# MAME can't auto-detect raw Kaypro sector images; convert build image to MFI.
# kaypro2x = 80-track single-sided 5.25" DSDD, matching the Kaypro IV format.
# (Boot image was already converted to MFI during 'make setup'.)
floptool flopconvert kaypro2x mfi "$BUILD_IMAGE" "$MFI_BUILD"

# Native resolution is 560x240. Use 1120x480 here for a readable 2x integer scale.
echo "Launching MAME. Press Alt+F4 to close."
exec "$MAME" kayproiv -rompath "$REPO_DIR/bin/roms" -flop1 "$MFI_IMAGE" -flop2 "$MFI_BUILD" \
    -window -nomaximize -resolution 1120x480
