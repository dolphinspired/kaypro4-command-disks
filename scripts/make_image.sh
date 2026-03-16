#!/usr/bin/env bash
# Creates bin/build.img — a blank Kaypro 4 CP/M disk containing all compiled
# .COM files. Intended for use as drive B alongside the base kayproiv.mfi.
# Requires bin/kayproiv.mfi to exist — run 'make setup' first.
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MKFS="$REPO_DIR/tools/cpmtools/bin/mkfs.cpm"
CPMCP="$REPO_DIR/tools/cpmtools/bin/cpmcp"
DISKDEFS_DIR="$REPO_DIR/tools/cpmtools/share"
BUILD_IMAGE="$REPO_DIR/bin/build.img"

# 80 tracks × 1 head × 10 sectors × 512 bytes = 409600 bytes
DISK_SIZE=409600

if [ ! -f "$REPO_DIR/bin/kayproiv.mfi" ]; then
    echo "ERROR: Boot image not found at bin/kayproiv.mfi"
    echo "Place kayproiv.img in usr-bin/ and run 'make setup' first."
    exit 1
fi

mkdir -p "$REPO_DIR/bin"

# cpmtools looks for 'diskdefs' in the current directory first, so run from there
cd "$DISKDEFS_DIR"

# Create a blank disk image and format it as kaypro4
dd if=/dev/zero of="$BUILD_IMAGE" bs=1 count=0 seek=$DISK_SIZE 2>/dev/null
"$MKFS" -f kaypro4 "$BUILD_IMAGE"

for f in "$REPO_DIR"/build/*.COM; do
    [ -f "$f" ] || continue
    echo "  Adding $(basename "$f")..."
    "$CPMCP" -f kaypro4 "$BUILD_IMAGE" "$f" "0:$(basename "$f")"
done

echo "Build image ready: $BUILD_IMAGE"
echo "To write to floppy: gw write --drive B --format kaypro.800 $BUILD_IMAGE"

