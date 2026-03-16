#!/usr/bin/env bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$REPO_DIR/tools"
mkdir -p "$TOOLS_DIR"

# --- Z88DK ---
if [ ! -f "$TOOLS_DIR/z88dk/bin/zcc" ]; then
    echo "==> Building Z88DK (this takes 10-20 minutes)..."
    if [ ! -d "$TOOLS_DIR/z88dk" ]; then
        git clone --recursive --depth=1 https://github.com/z88dk/z88dk.git "$TOOLS_DIR/z88dk"
    fi
    cd "$TOOLS_DIR/z88dk"
    ZCCCFG="$TOOLS_DIR/z88dk/lib/config" ./build.sh
    cd "$REPO_DIR"
else
    echo "==> Z88DK already installed, skipping."
fi

# --- RunCPM ---
if [ ! -f "$TOOLS_DIR/runcpm/RunCPM" ]; then
    echo "==> Building RunCPM..."
    if [ ! -d "$TOOLS_DIR/runcpm-src" ]; then
        git clone --depth=1 https://github.com/MockbaTheBorg/RunCPM.git "$TOOLS_DIR/runcpm-src"
    fi
    cd "$TOOLS_DIR/runcpm-src"
    # This patch to RunCPM changes the raw input of the Backspace key so that it
    # works as expected. Without this patch, pressing Backspace just produces "?"
    # in the terminal.
    patch -p1 < "$REPO_DIR/patches/runcpm-backspace.patch"
    cd RunCPM
    make -f Makefile.posix
    mkdir -p "$TOOLS_DIR/runcpm"
    cp RunCPM "$TOOLS_DIR/runcpm/"
    cd "$REPO_DIR"
else
    echo "==> RunCPM already installed, skipping."
fi

# --- Z80Pack (cpmsim) ---
if [ ! -f "$TOOLS_DIR/z80pack/cpmsim/cpmsim" ]; then
    echo "==> Building Z80Pack..."
    if [ ! -d "$TOOLS_DIR/z80pack" ]; then
        git clone --depth=1 https://github.com/udo-munk/z80pack.git "$TOOLS_DIR/z80pack"
    fi
    cd "$TOOLS_DIR/z80pack/cpmsim/srcsim"
    make
    cd "$REPO_DIR"
else
    echo "==> Z80Pack already installed, skipping."
fi

# --- cpmtools ---
if [ ! -f "$TOOLS_DIR/cpmtools/bin/cpmcp" ]; then
    echo "==> Building cpmtools..."
    if [ ! -d "$TOOLS_DIR/cpmtools-src" ]; then
        git clone --depth=1 https://github.com/lipro-cpm4l/cpmtools.git "$TOOLS_DIR/cpmtools-src"
    fi
    cd "$TOOLS_DIR/cpmtools-src"
    ./configure --prefix="$TOOLS_DIR/cpmtools"
    make && make install
    cd "$REPO_DIR"
else
    echo "==> cpmtools already installed, skipping."
fi

# --- MAME ---
if command -v mame &>/dev/null; then
    echo "==> MAME already installed, skipping."
else
    echo "==> MAME not found. Install it with:"
    echo "      sudo apt install mame"
    echo "    Then re-run this script to verify."
fi

# --- Boot disk image ---
USR_BIN_DIR="$REPO_DIR/usr-bin"
BOOT_SRC="$USR_BIN_DIR/kayproiv.img"

if [ -f "$BOOT_SRC" ]; then
    echo "==> Boot image found."
else
    echo "==> Boot image not ready. Place kayproiv.img in usr-bin/ and re-run setup."
    echo "    See: https://archive.org/details/kaypro-disk-cpm-2.2-and-s-basic"
fi

# --- MAME ROM zip ---
BIN_ROMS_DIR="$REPO_DIR/bin/roms"
ROM_ZIP="$BIN_ROMS_DIR/kayproiv.zip"
ROM_FILES=(81-232.u47 81-146.u43 m5l8049.bin)
MISSING_ROMS=()

for rom in "${ROM_FILES[@]}"; do
    [ -f "$USR_BIN_DIR/$rom" ] || MISSING_ROMS+=("$rom")
done

if [ ${#MISSING_ROMS[@]} -eq 0 ]; then
    echo "==> Packaging MAME ROMs into $ROM_ZIP..."
    mkdir -p "$BIN_ROMS_DIR"
    cd "$USR_BIN_DIR"
    zip -j "$ROM_ZIP" "${ROM_FILES[@]}"
    cd "$REPO_DIR"
    echo "==> MAME ROMs ready."
else
    echo "==> MAME ROMs not ready. Place the following files in usr-bin/ and re-run setup:"
    for rom in "${MISSING_ROMS[@]}"; do
        echo "      usr-bin/$rom"
    done
    echo "    See: http://www.retroarchive.org/maslin/roms/kaypro/index.html"
fi

echo "==> Setup complete."
