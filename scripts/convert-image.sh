#!/usr/bin/env bash
# Converts a disk image from usr-bin/ to MFI format in bin/.
# Detects input format automatically.
# Usage: convert-image.sh <filename>   (filename only, not a path)
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$1" ]; then
    echo "Usage: $0 <filename>"
    echo "  <filename> must exist in usr-bin/"
    exit 1
fi

INPUT="$REPO_DIR/usr-bin/$1"
BASENAME="${1%.*}"
OUTPUT="$REPO_DIR/bin/${BASENAME}.mfi"

if [ ! -f "$INPUT" ]; then
    echo "ERROR: File not found: $INPUT"
    exit 1
fi

mkdir -p "$REPO_DIR/bin"

echo "Converting $1 → bin/${BASENAME}.mfi..."
floptool flopconvert auto mfi "$INPUT" "$OUTPUT"
echo "Done: $OUTPUT"
