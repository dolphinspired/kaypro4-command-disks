#!/usr/bin/env bash
# Compile CP/M .c source files to uppercase .COM binaries for the Kaypro 4.
# ZCCCFG and PATH must be set by the caller (Makefile exports them).
set -euo pipefail

compile_file() {
    local src="$1"
    local base
    # Strip the directory and .c extension, then uppercase — CP/M requires uppercase .COM names.
    base=$(basename "$src" .c | tr '[:lower:]' '[:upper:]')
    local out="build/${base}.COM"
    mkdir -p build
    # +cpm targets CP/M 2.2; kaypro84 sets 80x25 console and links the Kaypro 4 graphics lib.
    # -Cl-L passes a -L (library search path) flag through to the C linker.
    # ZCCCFG points to z88dk/lib/config, so stripping /lib/config gives us the z88dk root,
    # and libsrc/ under that is where the compiled standard libraries live.
    zcc +cpm -subtype=kaypro84 -create-app -Cl-L"${ZCCCFG%/lib/config}/libsrc" -o "$out" "$src"
    # zcc leaves behind a lowercase .com and a .dsk alongside the output — remove them.
    rm -f "${out%.COM}.com" "${out%.COM}.dsk"
}

build_targets() {
    local srcs=("$@")
    if [ ${#srcs[@]} -eq 0 ]; then
        if [ -z "${SRC_DIR:-}" ]; then
            echo "ERROR: no source files given and SRC_DIR is not set" >&2
            exit 1
        fi
        # No args given — glob all .c files in SRC_DIR.
        srcs=("${SRC_DIR}"/*.c)
    fi
    for src in "${srcs[@]}"; do
        compile_file "$src"
    done
}

build_targets "$@"
