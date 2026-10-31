#!/usr/bin/env python3
# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
#
# Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

"""The C128's boot sector on a D64 image (abadia128ks, c64/disco128/NOTAS.md): track 1 sector 0 as the C128's
KERNAL BOOT_CALL reads it ("Mapping the Commodore 128", $F890): "CBM", the address and block for more boot sectors
and their count (none: 0, 0, 0), the message it prints after BOOTING, a zero, the name of the program it loads into
block 0 at the program's own address ("M", the menu at $1300), a zero, then the code it calls in bank 15 (JMP $1300).
The sector is marked used in the BAM (track 18 sector 0: four bytes a track from byte 4, the free count then the
bitmap, bit set = free; checked on an image c1541 formatted), so the files c1541 writes afterwards never take it.

    arranque128.py IMAGE.d64            (a freshly formatted image; changed in place)"""
import sys

PISTA18 = 17 * 21 * 256                                 # tracks 1-17 have 21 sectors of 256 bytes


def sector_arranque():
    s = b"CBM" + bytes([0, 0, 0, 0]) + b"ABADIA DEL CRIMEN" + b"\x00" + b"M" + b"\x00" + bytes([0x4C, 0x00, 0x13])
    assert len(s) <= 256
    return s + bytes(256 - len(s))


def main():
    f = sys.argv[1]
    d = bytearray(open(f, "rb").read())
    assert len(d) == 174848, "not a 35-track D64"
    assert d[0:256] == bytes(256), "track 1 sector 0 is not empty"
    bam = PISTA18 + 4                                   # track 1's entry
    assert d[bam:bam + 4] == bytes([0x15, 0xFF, 0xFF, 0x1F]), "track 1 is not all free"
    d[0:256] = sector_arranque()
    d[bam] -= 1                                         # sector 0 used
    d[bam + 1] &= 0xFE
    open(f, "wb").write(d)
    print(f"{f}: boot sector written (BOOTING ABADIA DEL CRIMEN, then the program M)")


if __name__ == "__main__":
    main()
