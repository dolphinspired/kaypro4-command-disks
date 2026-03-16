#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAME="${MAME:-/usr/games/mame}"
BOOT_SRC="$REPO_DIR/usr-bin/kayproiv.img"
BUILD_IMAGE="$REPO_DIR/bin/build.img"
BOOT_KAY="$REPO_DIR/bin/kayproiv.kay"
BUILD_KAY="$REPO_DIR/bin/build.kay"

if [ ! -x "$MAME" ]; then
    echo "ERROR: MAME not found at $MAME"
    echo "Install with: sudo apt install mame"
    echo "Or set the MAME environment variable to its path."
    exit 1
fi

if [ ! -f "$BOOT_SRC" ]; then
    echo "ERROR: Boot disk image not found at $BOOT_SRC"
    echo "Place kayproiv.img in usr-bin/ first."
    exit 1
fi

if [ ! -f "$BUILD_IMAGE" ]; then
    echo "ERROR: Build image not found at $BUILD_IMAGE"
    echo "Run 'make image' to build it first."
    exit 1
fi

# MAME's Kaypro format handler reads raw sector images via the .kay extension.
# (kaypro2x = 40-track double-sided 5.25" MFM, the Kaypro IV native format.)
# Symlink both images into bin/ with .kay extension so MAME picks up the format.
ln -sf "$BOOT_SRC" "$BOOT_KAY"
ln -sf "$BUILD_IMAGE" "$BUILD_KAY"

# Native resolution is 560x240. Use 1120x480 here for a readable 2x integer scale.
echo "Launching MAME. Press Alt+F4 to close."
exec "$MAME" kayproiv -rompath "$REPO_DIR/bin/roms" -flop1 "$BOOT_KAY" -flop2 "$BUILD_KAY" \
    -window -nomaximize -resolution 1120x480
