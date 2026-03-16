#!/usr/bin/env bash
set -e

DRIVE_DIR="tools/runcpm-drive/A/0"
mkdir -p "$DRIVE_DIR"

# Copy all built .COM files into the drive
if [ -d build ]; then
    cp build/*.COM "$DRIVE_DIR/" 2>/dev/null || true
fi

cd tools/runcpm-drive
exec ../runcpm/RunCPM
