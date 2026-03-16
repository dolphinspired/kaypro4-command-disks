#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DRIVE_DIR="$REPO_DIR/tools/runcpm-drive/A/0"
mkdir -p "$REPO_DIR/tools/runcpm-drive/A"

# Symlink A/0 → build/ so RunCPM always sees the latest compiled binaries.
# Recreate if missing, not a symlink, or pointing to the wrong target (e.g. stale path after repo move).
if [ ! -L "$DRIVE_DIR" ] || [ "$(readlink "$DRIVE_DIR")" != "$REPO_DIR/build" ]; then
    rm -rf "$DRIVE_DIR"
    ln -s "$REPO_DIR/build" "$DRIVE_DIR"
fi

# If already inside the Kaypro terminal window, just run the emulator
if [ -n "$KAYPRO_TERMINAL" ]; then
    cd "$REPO_DIR/tools/runcpm-drive"
    exec ../runcpm/RunCPM
fi

TITLE="Kaypro IV (RunCPM)"
CMD="env KAYPRO_TERMINAL=1 bash $0"

if command -v xterm &>/dev/null; then
    exec xterm -title "$TITLE" -geometry 80x25 -fg '#33ff33' -bg '#000000' -fa 'Monospace' -fs 14 -e $CMD
elif command -v gnome-terminal &>/dev/null; then
    exec gnome-terminal --title="$TITLE" -- env KAYPRO_TERMINAL=1 bash "$0"
else
    echo "No supported terminal found (xterm, gnome-terminal)."
    echo "Launching RunCPM in current terminal."
    KAYPRO_TERMINAL=1 exec bash "$0"
fi
