# Kaypro IV BIOS Capabilities

**Source:** [`bios/bios_22f_IV.s`](https://github.com/ivanizag/kaypro-disassembly/blob/main/bios/bios_22f_IV.s)
in the [`ivanizag/kaypro-disassembly`](https://github.com/ivanizag/kaypro-disassembly) community disassembly.
This is a disassembly derived from disk image `K4836765` in the Don Maslin Retroarchive collection,
not official Kaypro source. Version string confirmed: `KAYPRO IV 64k CP/M vers 2.2`.

---

## Architecture: BIOS as a ROM Wrapper

The Kaypro IV BIOS is a thin routing layer. Almost all real hardware work is
delegated to routines in the onboard ROM. The BIOS switches to the ROM bank
(setting bit 7 of port `0x1C`), calls the ROM routine, then restores RAM bank.

The ROM entry points the BIOS uses:

| Constant | Address | Function |
|---|---|---|
| `ROM_INITDSK` | `0x03` | Initialize disk |
| `ROM_HOME` | `0x0c` | Seek to track 0 |
| `ROM_SELDSK` | `0x0f` | Select disk drive |
| `ROM_SETTRK` | `0x12` | Set track |
| `ROM_SETSEC` | `0x15` | Set sector |
| `ROM_SETDMA` | `0x18` | Set DMA address |
| `ROM_READ` | `0x1b` | Read sector |
| `ROM_WRITE` | `0x1e` | Write sector |
| `ROM_SECTRAN` | `0x21` | Sector translate |
| `ROM_KBDSTAT` | `0x2a` | Keyboard status (non-blocking) |
| `ROM_KBDIN` | `0x2d` | Keyboard input (blocking) |
| `ROM_SIOSTI` | `0x33` | Serial I/O status |
| `ROM_SIOIN` | `0x36` | Serial I/O input |
| `ROM_SIOOUT` | `0x39` | Serial I/O output |
| `ROM_LISTST` | `0x3c` | List device status |
| `ROM_LIST` | `0x3f` | List device output (parallel printer) |
| `ROM_SERSTO` | `0x42` | Serial output status |
| `ROM_VIDOUT` | `0x45` | Video/console output |

**Implication for C programming:** all console I/O from C (via Z88DK's `putchar`,
`printf`, `getchar`, etc.) flows through BDOS → BIOS → ROM. For full detail on
what the ROM does with those calls, see `docs/rom-capabilities.md`.

---

## Graphics

### How it works

All console output goes through `CONOUT` in the BIOS, which routes to `ROM_VIDOUT`
(ROM address `0x45`) when the IOBYTE console is set to CRT (the default). The BIOS
itself writes `0x1A` (clear screen) to the console on boot, confirming `ROM_VIDOUT`
handles terminal control characters.

For the full list of control characters and escape sequences the ROM supports,
see `docs/rom-capabilities.md`.

### Key confirmed capabilities

- **`0x1A`** — clear screen, cursor to home (confirmed in BIOS boot sequence)
- **`ESC = <row+32> <col+32>`** — absolute cursor positioning
- **`ESC E` / `ESC R`** — insert / delete line
- **`ESC G` / `ESC A`** — Greek alternate character mode / ASCII mode
- **Direct VRAM write** — video RAM is at `0x3000`, stride 128 bytes per row, 80 columns

### No pixel graphics on the Kaypro IV

**The pixel graphics commands from the Kaypro User's Guide Addendum (ESC `*`, ESC
`L`, ESC `D` for pixels/lines, ESC `B`/`C` for inverse/blink attributes) do not
exist in this ROM.** Those commands are specific to the Kaypro 4 (Arabic numeral,
1984 model). The `docs/reference-documents.md` graphics section does not apply to
this machine. The ROM confirms: only cursor control, erase, line insert/delete, and
Greek mode are supported via escape sequences.

---

## Sound

**The Kaypro IV has a keyboard buzzer, accessible via ASCII BEL. Confirmed in ROM source.**

The BIOS itself has no sound handling, but `ROM_VIDOUT` explicitly checks for
BEL (`0x07`) and sends `0x04` to the keyboard data port (`0x05`), which triggers
the buzzer in the keyboard unit. There is no pitch or duration control — it is a
simple fixed-tone beep.

```c
putchar(0x07);  /* BEL — confirmed to produce a beep via keyboard buzzer */
```

---

## User Input

### Keyboard

`CONIN` in the BIOS calls `ROM_KBDIN` (`0x2d`) to get a keypress, then applies
its own post-processing for extended keys. `CONST` calls `ROM_KBDSTAT` (`0x2a`)
for a non-blocking status check (returns 0 = no key, non-zero = key waiting).

In C via Z88DK:
- `getchar()` → blocking keyboard read (CONIN → ROM_KBDIN)
- `kbhit()` or BDOS function 11 → non-blocking status check (CONST → ROM_KBDSTAT)

### Arrow Key Mapping

The ROM returns values `0x80–0x83` for the four arrow keys. The BIOS maps these
to control characters before returning them to the caller:

| Key | ROM value | Mapped to | ASCII name |
|---|---|---|---|
| Up | `0x80` | `0x0B` | ^K |
| Down | `0x81` | `0x0A` | ^J (LF) |
| Left | `0x82` | `0x08` | ^H (Backspace) |
| Right | `0x83` | `0x0C` | ^L |

These mappings are stored in BIOS RAM and can be reconfigured by `CONFIG.COM`.

### Numeric Keypad Mapping

The ROM returns `0x84–0x91` for the 16 keypad keys. The BIOS maps them to
character strings via a table in BIOS RAM (also reconfigurable by `CONFIG.COM`):

| Keys | Default output |
|---|---|
| 0 1 2 3 | `0` `1` `2` `3` |
| 4 5 6 7 | `4` `5` `6` `7` |
| 8 9 - , | `8` `9` `-` `,` |
| \ Enter . | `\` CR `.` |

### Serial Input

When the IOBYTE console is set to TTY (serial), `CONIN` routes to `ROM_SIOIN`
(`0x36`) instead of `ROM_KBDIN`. The arrow/keypad remapping does **not** apply to
serial input.

---

## IOBYTE: Console Device Routing

The BIOS uses the CP/M IOBYTE at address `0x0003` to route I/O. The default
is `0x81` — console to CRT, list device to parallel printer.

| IOBYTE bits | Device | Values |
|---|---|---|
| Bits 0–1 | Console | `00`=TTY (serial), `01`=CRT (keyboard+video) |
| Bits 6–7 | List | `00`=TTY, `01`=CRT, `10`=parallel printer, `11`=serial |

For all normal C programs, leave the IOBYTE at its default. Do not change it
unless you need to redirect I/O to the serial port.

---

## Disk Motor Idle Timeout

`CONST` (the non-blocking key check) increments an internal counter on every
call. Every 256 calls it calls `DISKOFF`, which sets bit 6 of port `0x1C` to
turn the floppy motor off. This is transparent to application code but means
that frequently calling `kbhit()` in a tight loop will keep the disk motor
managed automatically.

---

## Summary: What We Can Use

| Capability | Available | How |
|---|---|---|
| Text output | Yes | `printf`, `putchar` → ROM_VIDOUT |
| Screen clear | Yes | `putchar(0x1A)` |
| Cursor positioning | Yes | `ESC = <row+32> <col+32>` |
| Erase to EOL / EOS | Yes | `putchar(0x18)` / `putchar(0x17)` |
| Insert / delete line | Yes | `ESC E` / `ESC R` |
| Greek alternate glyphs | Yes | `ESC G` to enable, `ESC A` to disable |
| Direct VRAM write | Yes | Pointer to `0x3000`; see `rom-capabilities.md` |
| Pixel graphics | **No** | Not in this ROM; 4/84-only |
| Inverse video / blink attributes | **No** | Not in this ROM; 4/84-only |
| Keyboard input (blocking) | Yes | `getchar()` |
| Keyboard status (non-blocking) | Yes | BDOS function 11 |
| Arrow keys | Yes | Mapped to ^K/^J/^H/^L by BIOS |
| Numeric keypad | Yes | Mapped to digit characters by default |
| Serial I/O | Yes | Requires IOBYTE change or direct port access |
| Sound / beep | Yes | `putchar(0x07)` → keyboard buzzer (confirmed) |
| Programmable sound | **No** | Fixed tone only; no pitch or duration control |
| RTC / real-time clock | **No** | 4/84-only hardware; not present on IV |
