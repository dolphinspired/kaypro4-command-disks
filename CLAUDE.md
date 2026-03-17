# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
make setup      # First-time setup: clone and build all tools into tools/ (~10-20 min for Z88DK)
make            # Compile all src/*.c → build/*.COM and bundle into bin/build.img
make test       # Compile then run automated tests via RunCPM
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

**Accurate emulation** (MAME): Boots from an actual Kaypro IV disk image. Requires a bootable `usr-bin/kayproiv.img` (not in repo — must be dumped from a physical disk or sourced elsewhere). `scripts/make-image.sh` creates `bin/build.img` with compiled `.COM` files. `launch-mame.sh` passes both images directly to MAME as `-flop1`/`-flop2`. The boot image must be converted to MFI first: `floptool flopconvert kaypro2x mfi usr-bin/kayproiv.img bin/kayproiv.mfi`, then pass `bin/kayproiv.mfi` as `-flop1`. MAME's `kayproiv` driver does not accept `.img` — supported extensions are `.mfi .dfi .hfe .mfm .td0 .imd .d77 .d88 .1dd .cqm .cqi .dsk .kay`.

> **TODO — boot disk**: The `usr-bin/kayproiv.img` images tested so far have a dead boot sector (`JR $` at offset 0) and do not boot in MAME. A proper bootable Kaypro IV disk image is needed. Best source: dump a known-good physical disk using Greaseweazle (see Deploy below), or find `kiv-22.imd` (SHA1: `d4b5a6a0a0038fc12aa39a7dd17006f1c71198df`) from the MAME software list.

**Deploy** (greaseweazle): Correct format string is `kaypro.dsdd.40` (verified from [Greaseweazle diskdefs](https://github.com/keirf/greaseweazle/blob/master/src/greaseweazle/data/diskdefs_kaypro.cfg)).
- Read physical disk: `gw read --drive A --format kaypro.dsdd.40 kayproiv-boot.imd`
- Write to physical disk: `gw write --drive A --format kaypro.dsdd.40 bin/build.img`

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

- **cpmtools diskdefs**: Use format name `kpiv` — this is the Kaypro IV entry in the upstream diskdefs (comment has a typo: "Kayro IV"). The diskdefs file at `tools/cpmtools/share/diskdefs` must match the upstream exactly: `https://raw.githubusercontent.com/lipro-cpm4l/cpmtools/refs/heads/cpm4l/cpmtools-2.21/diskdefs`
- **MAME floppy format**: `.img` is NOT in MAME's accepted format list for `kayproiv`. Use MFI: `floptool flopconvert kaypro2x mfi usr-bin/kayproiv.img bin/kayproiv.mfi`, then pass `bin/kayproiv.mfi` to `-flop1`. The Kaypro IV uses 40-track DSDD disks; 40 cylinders × 2 heads × 10 sectors × 512 bytes = 409,600 bytes.
- **RunCPM test automation**: Works for programs that read from stdin normally. Raw terminal / curses programs will not work with this approach and need an `expect` script.
- **Z88DK `ZCCCFG`**: Must be set to `tools/z88dk/lib/config` at both build time (setup.sh) and compile time (Makefile). Without it, zcc cannot find its configuration.
- **`tools/` is gitignored**: Running `make setup` on a fresh clone rebuilds everything from source.
- **`usr-bin/` vs `bin/`**: `usr-bin/` holds user-supplied files (disk image + ROM files) that are gitignored. `bin/` holds all generated files (also gitignored). `make setup` copies `usr-bin/kayproiv.img` → `bin/kayproiv.img` for MAME to use.

## ROM dumps

Kaypro chip ROM dumps can be downloaded [here](http://www.retroarchive.org/maslin/roms/kaypro/index.html).
