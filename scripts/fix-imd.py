#!/usr/bin/env python3
"""
Fix Kaypro IMD disk images dumped with incorrect cylinder/sector numbering.

Problems corrected:
  - Cylinder IDs doubled (0,2,4..78 → 0,1,2..39): caused by reading a 48TPI
    disk with a 96TPI drive without double-step compensation.
  - Sector IDs 0-based (0-9 / 10-19 → 1-10 / 1-10): MAME's kaypro2x expects
    sectors 1-10 on both heads.

Usage: fix-imd.py <input.imd> <output.imd>
"""
import sys


def fix_imd(in_path, out_path):
    with open(in_path, 'rb') as f:
        data = bytearray(f.read())

    # Find end of header comment (0x1A byte)
    pos = data.index(0x1A) + 1

    track_count = 0
    while pos < len(data):
        if pos + 5 > len(data):
            break

        mode = data[pos]
        cyl  = data[pos + 1]
        head = data[pos + 2]
        nsec = data[pos + 3]
        secsize_code = data[pos + 4]
        secsize = 128 << secsize_code

        has_cyl_map  = bool(head & 0x80)
        has_head_map = bool(head & 0x40)
        head_val     = head & 0x3F

        # Fix 1: halve doubled cylinder IDs
        if cyl % 2 == 0 and cyl // 2 <= 39:
            data[pos + 1] = cyl // 2

        pos += 5

        # Sector ID map
        sec_map_start = pos
        for i in range(nsec):
            sid = data[pos + i]
            # Fix 2: shift 0-based sector IDs to 1-based
            # Head 0: 0-9 → 1-10
            # Head 1: 10-19 → 1-10
            if head_val == 0 and 0 <= sid <= 9:
                data[pos + i] = sid + 1
            elif head_val == 1 and 10 <= sid <= 19:
                data[pos + i] = (sid - 10) + 1
        pos += nsec

        if has_cyl_map:  pos += nsec
        if has_head_map: pos += nsec

        # Skip sector data records
        for _ in range(nsec):
            rec_type = data[pos]; pos += 1
            if rec_type == 0:
                pass
            elif rec_type in (1, 3, 5, 7):
                pos += secsize
            elif rec_type in (2, 4, 6, 8):
                pos += 1

        track_count += 1

    with open(out_path, 'wb') as f:
        f.write(data)

    print(f"Fixed {track_count} tracks → {out_path}")


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.imd> <output.imd>")
        sys.exit(1)
    fix_imd(sys.argv[1], sys.argv[2])
