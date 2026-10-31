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

"""The download of abadia64ks for abbeyofcrime.com: the tape (c64/cinta/abadia64ks.tap), the
disk (c64/disco64/abadia64ks.d64) and the README (c64/video/entrega/README.txt, English and Spanish) in one zip,
deflated, the files' dates fixed (deterministic); --c128: abadia128ks's disk (c64/disco128/abadia128ks.d64) and its
README (entrega/README128.txt); --p500: the P500's disks (c64/discop500/abadia128ks_p500.d80 and .d64) and its README
(entrega/README500.txt).  empaqueta.py OUT.zip [--c128 | --p500]"""
import os, sys, zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
FICHEROS = [("abadia64ks.tap", ROOT / "c64/cinta/abadia64ks.tap"), ("abadia64ks.d64", ROOT / "c64/disco64/abadia64ks.d64"),
            ("README.txt", ROOT / "c64/video/entrega/README.txt")]
if "--p500" in sys.argv:                # abadia128ks on the P500: its two disks and its README (entrega/README500.txt)
    P5 = Path(os.environ.get("DISCOS", ROOT / "c64/discop500"))    # (DISCOS: discop500/construye.sh's, elsewhere)
    FICHEROS = [("abadia128ks_p500.d80", P5 / "abadia128ks_p500.d80"),
                ("abadia128ks_p500.d64", P5 / "abadia128ks_p500.d64"),
                ("README.txt", ROOT / "c64/video/entrega/README500.txt")]
elif "--c128" in sys.argv:              # abadia128ks: its disk and its README (entrega/README128.txt)
    FICHEROS = [("abadia128ks.d64", ROOT / "c64/disco128/abadia128ks.d64"),
                ("README.txt", ROOT / "c64/video/entrega/README128.txt")]
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for nombre, f in FICHEROS:
        info = zipfile.ZipInfo(nombre, date_time=(2026, 10, 30, 12, 0, 0))
        info.compress_type, info.external_attr = zipfile.ZIP_DEFLATED, 0o644 << 16
        z.writestr(info, f.read_bytes(), compresslevel=9)
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None
    for (nombre, f), i in zip(FICHEROS, z.infolist()):
        assert z.read(i) == f.read_bytes()
        print(f"{nombre:20s} {i.file_size:7d} -> {i.compress_size:7d}")
