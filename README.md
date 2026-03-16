# Kaypro IV C Development Toolchain

> **Experimental.** This toolchain is a work in progress. Expect there might be some incorrect assumptions or misleading directions while we're working through the process.

An experimental pipeline for writing C programs, compiling to CP/M `.COM` binaries, and deploying to a physical **Kaypro IV**  via 5.25" floppy disk.

> **Important:** This project targets the **Kaypro IV (1983)** (Roman numeral, 1983), also sold as the "4/83". It is _not_ compatible with the Kaypro 4 (Arabic numeral, 1984 / "4/84"), which has different hardware. Documentation, ROMs, and disk images for the 1984 model will not work correctly here.

## Prerequisites

```bash
sudo apt install build-essential libncurses-dev libboost-dev git
```

You'll also need greaseweazle installed for floppy writing, and a CP/M 2.2 boot image (see [usr-bin README](usr-bin/README.md)).

## First-time setup

```bash
make setup
```

Clones and builds all tools (Z88DK, RunCPM, Z80Pack, cpmtools) into `tools/`. Z88DK takes 10–20 minutes.

## Workflow

## Programs

| Program | Description |
|---------|-------------|
| `HELLO.COM` | Prompts for your name and prints a greeting |
| `RAND.COM` | Generates a lucky number in a user-specified range. Seeds from keyboard-timing entropy XOR the Z80 R register. Run as `RAND` interactively, or `RAND <seed>` to specify a seed. |

**1. Write your program** in `src/`. See `src/hello.c` for an example.

**2. Compile:**
```bash
make
```
Produces `build/PROGNAME.COM` for each `src/progname.c`.

**3. Test in emulation:**
```bash
make test
```
Runs each program in RunCPM and diffs output against `test/cases/<progname>/expected.txt`.

For interactive testing, run RunCPM directly:
```bash
mkdir -p tools/runcpm-drive/A/0
cp build/HELLO.COM tools/runcpm-drive/A/0/
cd tools/runcpm-drive && ../runcpm/RunCPM
```

**4. Validate on accurate hardware emulation (optional):**
```bash
make launch-mame
```
Launches MAME with the Kaypro IV driver in a windowed 1120×480 display (2× integer scale of the native 560×240). Press **Alt+F4** to close.

```bash
make image
tools/z80pack/cpmsim/cpmsim -d bin/kayproiv.img
```

**5. Write to floppy:**
(UNTESTED)

```bash
make image
gw write --drive A --format kaypro.800 bin/kayproiv.img
```

## Boot Image and ROM Files

`make image` and `make launch-mame` require user-supplied files. See `usr-bin/README.md` for instructions on where to obtain them. After placing them in `usr-bin/`, run `make setup` to copy them into `bin/`.
