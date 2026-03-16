# Kaypro IV ROM Capabilities

**Source:** [`rom/81-232.s`](https://github.com/ivanizag/kaypro-disassembly/blob/main/rom/81-232.s)
in the [`ivanizag/kaypro-disassembly`](https://github.com/ivanizag/kaypro-disassembly) community disassembly.
Labeled "Analysis of the Kaypro II ROM / Based on 81-232.rom." The ROM welcome message reads `"Kaypro"` (not
"Kaypro II"), and it adds double-sided double-density disk support over the earlier 81-149c ROM.
Applicability to the Kaypro IV (mainboard 81.240, ROM 81-232-A) is unconfirmed — this is the
closest available disassembly and is treated as a strong reference.

---

## Architecture

The ROM lives in a banked memory region. The BIOS switches it in by setting bit 7 of port `0x1C`,
calls the ROM routine, then switches back to RAM. All real hardware work happens here.

The ROM provides these public entry points at page 0 (called by the BIOS via jump table):

| Address | Entry Point | Description |
|---|---|---|
| `0x00` | `EP_COLD` | Full cold boot |
| `0x03` | `EP_INITDSK` | Reset disk buffers and copy params to upper RAM |
| `0x06` | `EP_INITVID` | Reset video hardware, clear screen |
| `0x09` | `EP_INITDEV` | Initialize all I/O ports |
| `0x0C` | `EP_HOME` | Seek disk to track 0 |
| `0x0F` | `EP_SELDSK` | Select disk drive |
| `0x12` | `EP_SETTRK` | Set track number |
| `0x15` | `EP_SETSEC` | Set sector number |
| `0x18` | `EP_SETDMA` | Set DMA address |
| `0x1B` | `EP_READ` | Read sector |
| `0x1E` | `EP_WRITE` | Write sector |
| `0x21` | `EP_SECTRAN` | Translate logical → physical sector |
| `0x24` | `EP_DISKON` | Turn floppy motor on |
| `0x27` | `EP_DISKOFF` | Turn floppy motor off |
| `0x2A` | `EP_KBDSTAT` | Keyboard status (0x00=no key, 0xFF=key ready) |
| `0x2D` | `EP_KBDIN` | Keyboard input (blocking, returns char in A) |
| `0x30` | `EP_KBDOUT` | Send byte to keyboard port |
| `0x33` | `EP_SIOSTI` | Serial input status (0x00=none, 0xFF=ready) |
| `0x36` | `EP_SIOIN` | Serial input (blocking) |
| `0x39` | `EP_SIOOUT` | Serial output |
| `0x3C` | `EP_LISTST` | Centronics printer ready status |
| `0x3F` | `EP_LIST` | Send byte to Centronics printer port |
| `0x42` | `EP_SERSTO` | Serial output ready status |
| `0x45` | `EP_VIDOUT` | Send character to video display |
| `0x48` | `EP_DELAY` | Delay B × 10ms (calibrated for 4 MHz) |

---

## Sound

### Confirmed: BEL character produces a beep

`EP_VIDOUT` explicitly handles ASCII BEL (`0x07`). It sends the value `0x04` to
the keyboard data port (`io_05_keyboard_data`, port `0x05`) via `EP_KBDOUT`.
The keyboard unit contains a buzzer that responds to this signal.

From the source:
```asm
; Is it a BELL?
LD A,0x7 ; ^G BELL
CP C
JR NZ, EP_VIDOUT_cont
; BELL sends a 4 to the keyboard to beep
LD C,0x4
JP EP_KBDOUT
```

**To produce a beep in C:**
```c
putchar(0x07);  /* BEL — confirmed to work */
```

There is no programmable pitch or duration control. The buzzer is a simple on/off
triggered by the keyboard controller.

---

## Video and Display

### Video RAM (VRAM)

The screen is **memory-mapped**. Character data is stored directly in RAM at:

| Constant | Value | Meaning |
|---|---|---|
| `address_vram` | `0x3000` | Base address of video RAM |
| `console_lines` | `24` | Number of rows |
| `console_columns` | `80` | Number of columns |
| `console_line_length` | `0x80` (128) | Bytes per row in VRAM (80 used, 48 padding) |

**Row address formula:** `row_addr = 0x3000 + row * 0x80`
**Cell address formula:** `cell_addr = 0x3000 + row * 0x80 + col`

**Bit 7 of a VRAM byte controls blinking.** Any character with bit 7 set blinks on
screen. The ROM uses this for the cursor: the character at the cursor position is
stored with bit 7 set (`char | 0x80`). For a space, it writes `'_' | 0x80` to
make a blinking underscore cursor.

The ROM manages a software cursor via variable `console_cursor_position` at `0xFE76`.

### Hardware Scroll Register

Port `0x14` is the scroll register. The ROM writes `0x17` (23) to it on init.
This likely controls where the video chip considers the top line. Hardware-assisted
scrolling may be possible by manipulating this register, but the ROM does all
scrolling in software (LDIR-based line copy).

### Writing to VRAM directly in C

Since VRAM is just RAM, you can write to it directly with a pointer. This bypasses
`EP_VIDOUT` entirely and is the only way to do fast screen updates. The ROM's
cursor will still function correctly as long as you don't disturb the cursor
position variable at `0xFE76`.

```c
#define VRAM_BASE    0x3000
#define VRAM_STRIDE  0x80   /* 128 bytes per row */
#define VRAM_COLS    80
#define VRAM_ROWS    24

/* Write a character to screen at (row, col) without going through BDOS/BIOS */
void vram_put(int row, int col, char c) {
    char *p = (char *)(VRAM_BASE + row * VRAM_STRIDE + col);
    *p = c;
}

/* Read a character from screen (mask off blink bit) */
char vram_get(int row, int col) {
    char *p = (char *)(VRAM_BASE + row * VRAM_STRIDE + col);
    return *p & 0x7F;
}

/* Write a character with blink enabled */
void vram_put_blink(int row, int col, char c) {
    char *p = (char *)(VRAM_BASE + row * VRAM_STRIDE + col);
    *p = c | 0x80;
}
```

> **Caution:** When writing to VRAM directly, keep the padding bytes (columns 80–127
> per row) set to spaces (`0x20`). The ROM's scroll routine copies 80 bytes per line
> but iterates by 128-byte strides — stale data in the padding will not appear but
> should still be clean for safety.

### Console Control Characters (handled by EP_VIDOUT)

Send these via `putchar()`:

| Code | Hex | Effect |
|---|---|---|
| BEL | `0x07` | Keyboard beep |
| BS | `0x08` | Cursor left (no erase) |
| LF | `0x0A` | Cursor down; scroll up if at bottom |
| ^K | `0x0B` | Cursor up |
| ^L | `0x0C` | Cursor right |
| CR | `0x0D` | Cursor to column 0 |
| ^W | `0x17` | Erase from cursor to end of screen |
| ^X | `0x18` | Erase from cursor to end of line |
| SUB / ^Z | `0x1A` | Clear entire screen, cursor to home |
| ESC | `0x1B` | Begin escape sequence |
| ^] | `0x1E` | Cursor to home (top-left) |

### Escape Sequences (handled by EP_VIDOUT)

All escape sequences begin with ESC (`0x1B`):

| Sequence | Effect |
|---|---|
| `ESC = <row+0x20> <col+0x20>` | Move cursor to absolute position |
| `ESC A` | ASCII mode (default) |
| `ESC G` | Greek mode (see below) |
| `ESC E` | Insert blank line at cursor, scroll down |
| `ESC R` | Delete line at cursor, scroll up |

**Cursor positioning** example — move to row 5, column 10:
```c
putchar(0x1B);
putchar('=');
putchar(5  + 0x20);   /* row offset */
putchar(10 + 0x20);   /* col offset */
```

### Greek / Alternate Character Mode

`ESC G` switches the ROM to "greek mode." In this mode, any lowercase ASCII
character (`'a'`–`'z'` and beyond, >= 0x61) has its lower 5 bits taken:
`c & 0x1F`, mapping it to VRAM values `0x01`–`0x1F`. The video hardware renders
these as alternate/special glyphs (likely greek letters or box-drawing characters
— exact glyphs depend on the character ROM in the CRT chip, not documented here).

`ESC A` restores ASCII mode.

```c
putchar(0x1B); putchar('G'); /* Greek mode */
putchar('a');                /* outputs glyph for 0x01 */
putchar('b');                /* outputs glyph for 0x02 */
putchar(0x1B); putchar('A'); /* back to ASCII */
```

### What Is NOT Present: Pixel Graphics

**The pixel graphics commands documented in the Kaypro User's Guide Addendum
(March 1984) — ESC `*`, ESC space, ESC `L`, ESC `D` for pixel/line drawing, and
ESC `B`/`C` for attributes like inverse video and blinking — do not exist in this
ROM.** The addendum describes the Kaypro 4 (Arabic numeral, 1984 model), which has
a different video subsystem. The Kaypro IV (1983) has no pixel-addressable graphics
in its ROM.

---

## Keyboard

### Hardware

The keyboard communicates via a Z80 SIO chip (Serial I/O), configured on init as:
- Port `0x05`: keyboard data (R/W)
- Port `0x07`: keyboard control/status
- Port `0x0C`: keyboard baud rate (set to 300 baud, CLK/32)

The keyboard is a serial device at the hardware level. The SIO chip handles
framing; software reads bytes from port `0x05`.

### Key Translation in the ROM

The ROM translates raw keyboard scan codes to normalized values before returning
them to the BIOS. The mapping covers arrow keys (raw `0xF1`–`0xF4`) and numeric
keypad keys:

| Raw scan code | Normalized value | Key |
|---|---|---|
| `0xF1` | `0x80` | Up arrow |
| `0xF2` | `0x81` | Down arrow |
| `0xF3` | `0x82` | Left arrow |
| `0xF4` | `0x83` | Right arrow |
| `0xB1` | `0x84` | Keypad 0 |
| `0xC0` | `0x85` | Keypad 1 |
| `0xC1` | `0x86` | Keypad 2 |
| `0xC2` | `0x87` | Keypad 3 |
| `0xD0` | `0x88` | Keypad 4 |
| `0xD1` | `0x89` | Keypad 5 |
| `0xD2` | `0x8A` | Keypad 6 |
| `0xE1` | `0x8B` | Keypad 7 |
| `0xE2` | `0x8C` | Keypad 8 |
| `0xE3` | `0x8D` | Keypad 9 |
| `0xE4` | `0x8E` | Keypad - |
| `0xD3` | `0x8F` | Keypad , |
| `0xC3` | `0x90` | Keypad \ |
| `0xB2` | `0x91` | Keypad Enter |

The normalized values `0x80`–`0x91` are then further mapped by the BIOS to control
characters or digit characters (see `docs/bios-capabilities.md`).

All other keys return their raw scan code. Normal ASCII keys return standard ASCII.

### Keyboard Status

Non-blocking key check: `EP_KBDSTAT` reads bit 0 of port `0x07`.
- Returns `0xFF` if a key is ready, `0x00` otherwise.
- In C: use BDOS function 11 (`bdos(11, 0)`) which calls through to `CONST` → `EP_KBDSTAT`.

### Keyboard Bell Output

`EP_KBDOUT` writes a byte to the keyboard data port. Sending `0x04` triggers the
keyboard buzzer. This is the only known path for producing audio on the Kaypro IV.

---

## Serial I/O

The serial port uses Z80 SIO channel A:
- Port `0x04`: serial data (R/W)
- Port `0x06`: serial control/status
- Port `0x00`: baud rate (write only, values `0x0`–`0xF`)

The BIOS initializes it to 300 baud. Baud rate constants from the Kaypro Addendum:

| Hex value | Baud rate |
|---|---|
| `0x00` | 50 |
| `0x01` | 75 |
| `0x02` | 110 |
| `0x03` | 134.5 |
| `0x04` | 150 |
| `0x05` | 300 (default) |
| `0x06` | 600 |
| `0x07` | 1200 |
| `0x08` | 1800 |
| `0x09` | 2000 |
| `0x0A` | 2400 |
| `0x0B` | 3600 |
| `0x0C` | 4800 |
| `0x0D` | 7200 |
| `0x0E` | 9600 |
| `0x0F` | 19200 |

The BIOS does not route standard console I/O to the serial port by default (IOBYTE
console bits = CRT). To use the serial port, either change the IOBYTE or call
`EP_SIOIN`/`EP_SIOOUT` directly via port I/O.

---

## Delay / Timing

`EP_DELAY` provides a simple busy-wait timer:
- Register B = number of 10ms intervals (1–256; 0 is treated as 256)
- Calibrated for 4 MHz Z80 clock
- Maximum delay: 256 × 10ms = 2.56 seconds per call

The ROM calls this directly (500ms motor spin-up delay on disk motor on).
Not directly callable from C without inline assembly or a helper, but the
loop structure can be replicated:

```c
/* Approximate 10ms busy-wait at 4MHz Z80 */
void delay_10ms(void) {
    volatile int i;
    for (i = 0; i < 0x686; i++);  /* matches ROM inner loop count */
}
```

---

## I/O Port Summary (ROM perspective)

| Port (hex) | Name | Direction | Function |
|---|---|---|---|
| `0x00` | Serial baud rate | W | Set RS-232C baud (0–F) |
| `0x04` | Serial data | R/W | Z80 SIO-A data |
| `0x05` | Keyboard data | R/W | Z80 SIO-B data; write `0x04` for beep |
| `0x06` | Serial control | R/W | Z80 SIO-A control; bit 0=RX ready, bit 2=TX ready |
| `0x07` | Keyboard control | R/W | Z80 SIO-B control; bit 0=key ready |
| `0x08` | Parallel data | W | Centronics printer data |
| `0x09` | Parallel control (PIO-1A) | R/W | Centronics output mode |
| `0x0B` | Parallel B control (PIO-1B) | R/W | Centronics input mode (ready/strobe) |
| `0x0C` | Keyboard baud rate | W | Clock generator for keyboard SIO |
| `0x10` | FDC status/command | R/W | Floppy disk controller |
| `0x11` | FDC track | R/W | Floppy disk track register |
| `0x12` | FDC sector | R/W | Floppy disk sector register |
| `0x13` | FDC data | R/W | Floppy disk data register |
| `0x14` | Scroll register | W | Video hardware scroll position |
| `0x1C` | System bits (PIO-2A) | R/W | Drive select, motor, density, bank, Centronics strobe/ready |
| `0x1D` | System bits control | W | PIO-2A mode/direction configuration |

### System Port `0x1C` Bit Map (from ROM source)

| Bit | Name | Description |
|---|---|---|
| 0 | `drive_a` | Select drive A (0 = selected) |
| 1 | `drive_b` | Select drive B (0 = selected) |
| 2 | `side_2` | Select disk side 2 |
| 3 | `centronicsReady` | Centronics printer ready (input) |
| 4 | `centronicsStrobe` | Centronics strobe pulse (output) |
| 5 | `double_density_neg` | Double density mode (0 = DD, 1 = SD) |
| 6 | `motors_neg` | Floppy motor (0 = on, 1 = off) |
| 7 | `bank` | ROM bank select (1 = ROM active, 0 = RAM) |

---

## Summary: What We Can Use

| Capability | Available | Method |
|---|---|---|
| Text output | Yes | `printf`/`putchar` → EP_VIDOUT |
| Direct VRAM write | Yes | Pointer to `0x3000`; stride 128 bytes |
| Blinking characters | Yes | Set bit 7 in VRAM byte |
| Clear screen | Yes | `putchar(0x1A)` |
| Cursor positioning | Yes | `ESC = <row+32> <col+32>` |
| Erase to EOL | Yes | `putchar(0x18)` |
| Erase to EOS | Yes | `putchar(0x17)` |
| Insert/delete line | Yes | `ESC E` / `ESC R` |
| Greek/alternate glyphs | Yes | `ESC G` / `ESC A` |
| Pixel graphics | **No** | Not in this ROM (4/84-only feature) |
| Attribute escape sequences | **No** | Not in this ROM (4/84-only feature) |
| Keyboard input (blocking) | Yes | `getchar()` → EP_KBDIN |
| Keyboard non-blocking poll | Yes | BDOS function 11 → EP_KBDSTAT |
| Arrow keys | Yes | Mapped to `^K`/`^J`/`^H`/`^L` by BIOS |
| Numeric keypad | Yes | Mapped to digit chars by BIOS |
| Sound / beep | Yes | `putchar(0x07)` → keyboard buzzer |
| Programmable sound | **No** | Buzzer only; no pitch or duration control |
| Serial I/O | Yes | Via IOBYTE change or direct port access |
| Delay/timing | Yes | `EP_DELAY` (not directly from C; replicate loop) |
| Real-time clock | **No** | 4/84-only hardware |
