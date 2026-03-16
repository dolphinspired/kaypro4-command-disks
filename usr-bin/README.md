# usr-bin

Place the following user-supplied files in this directory before running `make setup`.
These files are not included in the repo and must be obtained separately.

---

## kayproiv.img — Kaypro IV CP/M 2.2 boot disk image

A raw sector image of the Kaypro IV CP/M 2.2 boot floppy (409,600 bytes).

**Source:** https://archive.org/details/kaypro-disk-cpm-2.2-and-s-basic

Download the raw Kaypro 4 disk image and save it here as `kayproiv.img`.

---

## ROM files — Kaypro IV BIOS/firmware chips

Three ROM dumps are required for MAME emulation:

| File | Chip | Description |
|------|------|-------------|
| `81-232.u47` | Z80 BIOS ROM | Main system BIOS |
| `81-146.u43` | Video/character ROM | Character generator |
| `m5l8049.bin` | Keyboard controller | Keyboard MCU firmware |

**Source:** http://www.retroarchive.org/maslin/roms/kaypro/index.html

Download the Kaypro IV ROM dumps and place the three files listed above in this directory.

---

After placing all files here, run `make setup` to package them into `bin/` for use by the emulators.
