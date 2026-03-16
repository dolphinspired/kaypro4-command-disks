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

echo "==> Setup complete."
