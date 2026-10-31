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

"""obj_drop_object's orientation quirk as the PC has it, for abadia128ks (milestone H10, the full game).  The original
reads the dropped object's orientation at (height << 8) | the low byte of the holder's record + 1 (1000:5765 MOV
BH,AL): on the PC DS:hhF5 for Guillermo (record BAF4h) and DS:hh22 for the abbot (BB21h), heights 00h-23h.  Most of
those bytes never change once the game has started (taken from the PC's data space at its first frame, PC_DUMP; one,
DS:0F22 the PC speaker's envelope, read by the abbot at height 0Fh, changes with the sound: its most frequent value);
those inside a graphic the game mirrors in place take one of two values: as loaded, or mirrored (each line's bytes in
reverse order through spr_flip_table, 1000:3028), chosen by that graphic's mirror state on the C128: Guillermo's
frames by his flip state (record +6), Adso's by his, the door leaf by obj_door_gfx_flipped (set: as loaded; the PC's
dumps show the leaf loaded mirrored), a face block by cabezas128.s's parity par_c[k].  Checked against every frame of PC_DUMP.  Out: the ca65 tables (OUT.inc).

    orienta128.py PC_DUMP OUT.inc
"""
import os, re, sys
PC = "/home/german/Proyectos/abadia/c"
dump, out = sys.argv[1], sys.argv[2]
pcs = {}
for l in open(os.path.join(PC, "include", "direcciones.h")):
    m = re.match(r"#define (\w+)\s+0x([0-9A-F]+)u", l)
    if m and not m.group(1).endswith("_SIZE"): pcs[m.group(1)] = int(m.group(2), 16)
f = open(dump, "rb")
d1 = f.read(0x10000)                                     # the first frame
ds0 = open("/home/german/Proyectos/abadia/trabajo/re/disco/programa.bin", "rb").read()[0x8000:0x18000]   # as loaded
flip = d1[pcs["SPR_FLIP_TABLE"]:pcs["SPR_FLIP_TABLE"] + 256]
# the graphics mirrored in place: (start, width, lines, selector); selectors 1 Guillermo, 2 Adso, 3 doors, 4 + k face k
BLOQUES = [(pcs["SPR_GUILLERMO_GFX_W5"], 5, 0xAE, 1), (pcs["SPR_GUILLERMO_GFX_W4"], 4, 0x21, 1),
           (pcs["SPR_ADSO_GFX_W5"], 5, 0x5F, 2), (pcs["SPR_ADSO_GFX_W4"], 4, 0x5A, 2),
           (pcs["OBJ_DOOR_GFX"], 6, 40, 3)] + [(pcs["SPR_GFX_FACES"] + 100 * k, 5, 20, 4 + k) for k in range(7)]
def valores(a):
    for b, w, n, sel in BLOQUES:
        if b <= a < b + w * n:
            r, c = divmod(a - b, w)
            return sel, ds0[a], flip[ds0[b + r * w + (w - 1 - c)]]
    return 0, d1[a], d1[a]
tablas = {}
for nom, lo in (("guillermo", 0xF5), ("abad", 0x22)):
    tablas[nom] = [valores((h << 8) | lo) for h in range(0x24)]
# a byte outside the mirrored graphics that still changes (DS:0F22, snd_env_start, the PC speaker's envelope: the
# abbot at height 0Fh): its most frequent value over the dump
import collections
n = os.path.getsize(dump) // 0x10000
cuenta = {(nom, h): collections.Counter() for nom in tablas for h in range(0x24)}
f.seek(0)
for fr in range(n):
    m = f.read(0x10000)
    for nom, lo in (("guillermo", 0xF5), ("abad", 0x22)):
        for h in range(0x24):
            if tablas[nom][h][0] == 0: cuenta[(nom, h)][m[(h << 8) | lo]] += 1
for (nom, h), c in cuenta.items():
    if len(c) > 1:
        v = c.most_common(1)[0][0]
        tablas[nom][h] = (0, v, v)
        print(f"{nom} height {h:02X}: varies {dict(c)} (not a mirrored graphic): {v:02X} taken")
# the check: every frame of the dump, the predicted byte against the PC's
G6, A6, PUERTA = pcs["CHR_GUILLERMO"] + 6, pcs["CHR_ADSO"] + 6, pcs["OBJ_DOOR_GFX_FLIPPED"]
caras_vistas, malos = set(), []
f.seek(0)
for fr in range(n):
    m = f.read(0x10000)
    for nom, lo in (("guillermo", 0xF5), ("abad", 0x22)):
        for h, (sel, v0, v1) in enumerate(tablas[nom]):
            real = m[(h << 8) | lo]
            if sel == 0: pred = v0
            elif sel == 1: pred = v1 if m[G6] & 1 else v0
            elif sel == 2: pred = v1 if m[A6] & 1 else v0
            elif sel == 3: pred = v0 if m[PUERTA] else v1     # (the leaf as loaded is the mirrored one: flag set)
            else:
                caras_vistas.add(real); pred = real if real in (v0, v1) else None   # (the faces' parity is the C128's own)
            if pred != real: malos.append((fr + 1, nom, h, real, pred))
if malos:
    print(f"{len(malos)} predictions wrong, first: {malos[:5]}")
nota = "; the 6502 picks the second value when the graphic is mirrored"
with open(out, "w") as o:
    o.write("; made by c64/certifica/pc/orienta128.py (do not edit): obj_drop_object's orientation quirk as the PC has\n"
            "; it (abadia128ks, the full game): per height 00h-23h the byte at DS:hhF5 (Guillermo) / DS:hh22 (the abbot)\n"
            "; as loaded (or the first frame's, selector 0), mirrored, and the selector (0 none, 1 Guillermo's frames,\n"
            "; 2 Adso's, 3 the door leaf, 4 + k face block k)" + nota + "\n")
    for nom in ("guillermo", "abad"):
        for k, col in ((1, "lo"), (2, "esp")):
            o.write(f"lb_or128_{nom}_{col}:\n        .byte   " + ", ".join(f"${t[k]:02X}" for t in tablas[nom]) + "\n")
        o.write(f"lb_or128_{nom}_sel:\n        .byte   " + ", ".join(f"{t[0]}" for t in tablas[nom]) + "\n")
print(f"{n} frames checked, {len(malos)} wrong; tables in {out}")
