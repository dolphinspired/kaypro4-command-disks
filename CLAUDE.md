# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make setup      # First-time setup: clone and build all tools into tools/ (~10-20 min for Z88DK)
make            # Compile all src/*.c → build/*.COM
make test       # Compile then run automated tests via RunCPM
make image      # Compile then bundle .COM files into bin/build.img
make clean      # Delete build/ and bin/
```

To run a program interactively in RunCPM:
```bash
mkdir -p tools/runcpm-drive/A/0
cp build/FOO.COM tools/runcpm-drive/A/0/
cd tools/runcpm-drive && ../runcpm/RunCPM
```

## Target Machine

**Kaypro IV** (Roman numeral, 1983 model — also called 4/83)
- CP/M version: 2.2f
- Mainboard: 81.240
- ROM/BIOS revision: 81-232-A

**IMPORTANT — naming distinction:** The Kaypro IV (Roman numeral, 1983) and the Kaypro 4 (Arabic numeral, 1984 / "4/84") are meaningfully different machines with different hardware capabilities. Do not conflate them. Any documentation, hardware reference, or online resource that refers to the "Kaypro 4" or "4/84" may describe hardware (e.g. real-time clock, internal modem, second serial port) that is absent on the Kaypro IV. Always verify which model a source applies to.

## Architecture

The pipeline has four stages: **compile → emulate (fast) → emulate (accurate) → deploy**.

**Compile** (`src/` → `build/`): Z88DK's `zcc` uses `+cpm -subtype=kaypro84` — `+kaypro` does not exist as a top-level target. The `kaypro84` subtype (vs `kaypro83` for the Kaypro II) sets 80×25 console and links the Kaypro 4 graphics lib. Output filenames must be uppercase `.COM` (CP/M convention); the Makefile handles this via the pattern rule.

> **TODO — verify Z88DK subtype:** The `kaypro84` subtype name suggests the 1984 model. It is unclear whether this is the correct subtype for the Kaypro IV (1983). Compare `kaypro83` vs `kaypro84` Z88DK behavior to confirm the right target.

**Fast emulation** (RunCPM): Treats a directory tree as CP/M drives — `tools/runcpm-drive/A/0/` maps to drive A. The test runner in `test/run_tests.sh` automates this by feeding stdin to RunCPM (program name from `input.txt` then `^C` to quit). RunCPM is an interactive shell, not a single-program launcher. The test runner strips noise by: removing ANSI escape codes, stripping `\r` (RunCPM uses CRLF), collapsing backspace-based echo sequences (`_\b \bX` → `X`), and extracting only lines between the first `A0>` prompt line and the next one. `expected.txt` should match this cleaned output. Also: `fgets` in CP/M programs receives `\r\n` line endings — always strip with `strcspn(name, "\r\n")`, not just `"\n"`.

**Accurate emulation** (MAME): Boots from an actual Kaypro IV disk image. Requires `usr-bin/kayproiv.img` sourced from Archive.org (not in repo) — `make setup` converts it to `bin/kayproiv.mfi`. `scripts/make_image.sh` creates `bin/build.img` with compiled `.COM` files; `launch-mame.sh` converts that to MFI and launches MAME.

**Deploy** (greaseweazle): `gw write --drive A --format kaypro.800 bin/kayproiv.img` — format string may need verification against installed gw version.

## Adding a Test Case

Create `test/cases/<progname>/` with two files:
- `input.txt` — first line is the CP/M command to run (e.g. `HELLO`), subsequent lines are stdin to the program
- `expected.txt` — expected stdout (after RunCPM banner/prompt are stripped)

The test runner upcases the directory name to find the matching `.COM` in `build/`.

## Reference Docs

Summaries of researched hardware and software capabilities are in `docs/`:

- `docs/reference-documents.md` — overview of source PDFs consulted: CP/M intro guide and Kaypro addendum (WARNING: addendum covers the 4/84, not the IV — verify before applying)
- `docs/bios-capabilities.md` — BIOS function table, I/O port map, and ROM call conventions for the Kaypro IV; derived from community disassembly of `bios_22f_IV.s`
- `docs/rom-capabilities.md` — ROM entry points, video/keyboard/serial routines, and disk bootstrap; derived from community disassembly of `81-232.s` (confirmed closest match to ROM 81-232-A, but applicability unverified)
- `docs/capability-exploration.md` — platform constraints, available Z88DK APIs, and notes from hands-on capability testing programs

## Known Gotchas

- **cpmtools diskdefs**: `kaypro4` may not be in the default diskdefs file. If `cpmcp` fails, add this entry to `tools/cpmtools/share/diskdefs`:
  ```
  diskdef kaypro4
    seclen 512
    tracks 80
    sectrk 10
    heads 1
    blocksize 2048
    maxdir 64
    skew 0
    boottrk 2
    os 2.2
  end
  ```
- **MAME floppy format**: MAME cannot auto-detect raw Kaypro sector images. `launch-mame.sh` converts them to MFI via `floptool` (from `mame-tools` package). The Kaypro IV uses single-sided disks — format is `kaypro2x` (80-track SS), matching the 409,600-byte boot image from Archive.org.
- **RunCPM test automation**: Works for programs that read from stdin normally. Raw terminal / curses programs will not work with this approach and need an `expect` script.
- **Z88DK `ZCCCFG`**: Must be set to `tools/z88dk/lib/config` at both build time (setup.sh) and compile time (Makefile). Without it, zcc cannot find its configuration.
- **`tools/` is gitignored**: Running `make setup` on a fresh clone rebuilds everything from source.
- **`usr-bin/` vs `bin/`**: `usr-bin/` holds user-supplied files (disk image + ROM files) that are gitignored. `bin/` holds all generated files (also gitignored). Only `setup.sh` reads from `usr-bin/`; emulators always use `bin/`. After `make clean`, run `make setup` before `make image` to repopulate `bin/kayproiv.mfi`.

## ROM dumps

Kaypro chip ROM dumps can be downloaded [here](http://www.retroarchive.org/maslin/roms/kaypro/index.html).
