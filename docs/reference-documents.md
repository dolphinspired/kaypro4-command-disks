# Reference Documents

## Target Machine

**Kaypro IV** (Roman numeral, 1983 / "4/83") — CP/M 2.2f, mainboard 81.240, ROM 81-232-A

**Critical naming distinction:** The **Kaypro IV** (Roman numeral, 1983) and the **Kaypro 4**
(Arabic numeral, 1984 / "4/84") are different machines. The 4/84 added hardware absent on the IV:
real-time clock, internal modem, cooling fan. Any source that says "Kaypro 4 only" does not apply
to our machine.

## Source PDFs

| Title | Author | Date | Notes | File |
|---|---|---|---|---|
| An Introduction to CP/M Features and Facilities | Digital Research | 1976 (v1.3) | Generic CP/M 2.2 — fully applicable | `CPM_1.3_An_Introduction_to_CPM_Features_and_Facilities_1976.pdf` |
| Addendum to the User's Guide for Your Kaypro Computer | Kaypro Corporation | March 20, 1984 | Written for the 4/84. Sections on pixel graphics, RTC, modem, and character attributes do **not** apply to the IV. CP/M info, CONFIG, keyboard, and memory warning are applicable. I/O port assignments have been superseded by the ROM source. | `KayproUsersGuideAddendum032084.pdf` |

---

## CP/M 1.3 — An Introduction to CP/M Features and Facilities

### Architecture

CP/M is divided into four logical areas:

- **BIOS** — Basic I/O system; hardware-specific, patched per machine
- **BDOS** — Basic disk operating system; file management
- **CCP** — Console command processor; user shell
- **TPA** — Transient program area; where `.COM` programs are loaded and run

A running program can overlay CCP/BDOS/BIOS memory as data space. At exit, programs jump to the
warm-start bootstrap to reload CP/M from disk.

### BDOS File Operations

| Operation | Function |
|---|---|
| SEARCH | Find a file by name |
| OPEN | Open a file |
| CLOSE | Close a file |
| RENAME | Rename a file |
| READ | Read a 128-byte record |
| WRITE | Write a 128-byte record |
| SELECT | Select a disk drive |

File size limit: 240 records of 128 bytes each per file. Up to 64 files per disk in standard CP/M.

### CCP Built-in Commands

| Command | Function |
|---|---|
| ERA afn | Erase files matching pattern |
| DIR afn | List files matching pattern |
| REN ufn1=ufn2 | Rename file |
| SAVE n ufn | Save n×256 bytes from TPA to disk |
| TYPE ufn | Print file contents to console |

### CCP Transient Commands

| Command | Function |
|---|---|
| STAT | Show free disk space |
| ASM | 8080 macro assembler |
| LOAD | Load Intel hex file → .COM |
| PIP | Peripheral Interchange Program (file copy/concat) |
| ED | Context text editor |
| SYSGEN | Create new bootable CP/M diskette |
| SUBMIT | Batch command file processing |
| DUMP | Hex dump of file |

### File Naming

Format: `PPPPPPPP.SSS` (8-char primary name, 3-char extension). Wildcards: `?` matches any single
character, `*` is shorthand for `????????`. The CCP uppercases all input.

### Line Editing at the CCP Prompt

| Key | Effect |
|---|---|
| Rubout/Del | Delete last character |
| Ctrl-U | Delete entire line |
| Ctrl-E | Physical line break (line not sent until CR) |
| Ctrl-C | Warm reboot CP/M |
| Ctrl-Z | End of input (used in PIP and ED) |

### CP/M I/O Device Names (for PIP)

| Device | Description |
|---|---|
| CON: | Current console |
| TTY: | Teletype device (serial) |
| CRT: | CRT display |
| LST: | Listing device (printer) |
| PUN: | Paper tape punch |
| RDR: | Paper tape reader |

---

## Kaypro IV Hardware Reference

*Sources: Kaypro User's Guide Addendum (March 1984) and ROM disassembly (`rom/81-232.s`).
Where the two conflict, the ROM source takes precedence as it is specific to the IV.*

### I/O Port Address Map

Derived from the ROM source (`rom/81-232.s`), which is authoritative for the Kaypro IV.

| Port (hex) | Name | Dir | Function |
|---|---|---|---|
| `0x00` | Serial baud rate | W | Set RS-232C baud rate (0x0–0xF) |
| `0x04` | Serial data | R/W | Z80 SIO-A data register |
| `0x05` | Keyboard data | R/W | Z80 SIO-B data; write `0x04` to beep |
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
| `0x14` | Scroll register | W | Video hardware scroll position (init value: `0x17`) |
| `0x1C` | System bits (PIO-2A) | R/W | Drive select, motor, density, ROM bank, Centronics strobe/ready |
| `0x1D` | System bits control | W | PIO-2A mode/direction configuration |

### System Port `0x1C` Bit Map

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

### Keyboard

- Port `0x05`: keyboard data (Z80 SIO-B); write `0x04` to trigger keyboard buzzer (beep)
- Port `0x07`: keyboard control/status; bit 0 = key ready
- In normal C programs: keyboard access goes through BDOS console functions (`getchar`, `scanf`, etc.)
- Non-blocking check: BDOS function 11

### CONFIG Utility

`CONFIG.COM` allows reconfiguration without rebooting:

- Change IOBYTE (maps logical CP/M devices to physical hardware)
- Redefine cursor/arrow keys
- Redefine numeric keypad (each key: up to 4-character string)
- Set write-safe flag
- Change serial printer baud rate

### Memory Space Warning

These programs leave residual state in sensitive memory areas that can conflict with other
software. Always press the hardware reset button after using them:

- `MFDISK.COM`
- `XSUB.COM`
- `RAMDISK.COM`
- `MSDOS.COM`
