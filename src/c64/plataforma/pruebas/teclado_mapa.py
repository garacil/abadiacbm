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

"""The two keyboard matrices by key name and the C64 -> CPC map of c64/plataforma/TECLADO.md, written apart
from teclado.s's table (by names and positions, not by key numbers) so the test checks the table against it."""

# the C64 matrix: (column = $DC00 bit, row = $DC01 bit)
C64 = {
    "INST/DEL": (0, 0), "RETURN": (0, 1), "CRSR RIGHT": (0, 2), "F7": (0, 3), "F1": (0, 4), "F3": (0, 5),
    "F5": (0, 6), "CRSR DOWN": (0, 7),
    "3": (1, 0), "W": (1, 1), "A": (1, 2), "4": (1, 3), "Z": (1, 4), "S": (1, 5), "E": (1, 6), "LEFT SHIFT": (1, 7),
    "5": (2, 0), "R": (2, 1), "D": (2, 2), "6": (2, 3), "C": (2, 4), "F": (2, 5), "T": (2, 6), "X": (2, 7),
    "7": (3, 0), "Y": (3, 1), "G": (3, 2), "8": (3, 3), "B": (3, 4), "H": (3, 5), "U": (3, 6), "V": (3, 7),
    "9": (4, 0), "I": (4, 1), "J": (4, 2), "0": (4, 3), "M": (4, 4), "K": (4, 5), "O": (4, 6), "N": (4, 7),
    "+": (5, 0), "P": (5, 1), "L": (5, 2), "-": (5, 3), ".": (5, 4), ":": (5, 5), "@": (5, 6), ",": (5, 7),
    "POUND": (6, 0), "*": (6, 1), ";": (6, 2), "CLR/HOME": (6, 3), "RIGHT SHIFT": (6, 4), "=": (6, 5),
    "UP ARROW": (6, 6), "/": (6, 7),
    "1": (7, 0), "LEFT ARROW": (7, 1), "CTRL": (7, 2), "2": (7, 3), "SPACE": (7, 4), "C=": (7, 5), "Q": (7, 6),
    "RUN/STOP": (7, 7),
}

# the CPC matrix: (row, bit); key number = 8 row + bit
CPC = {
    "CURSOR UP": (0, 0), "CURSOR RIGHT": (0, 1), "CURSOR DOWN": (0, 2), "F9": (0, 3), "F6": (0, 4), "F3": (0, 5),
    "ENTER": (0, 6), "F.": (0, 7),
    "CURSOR LEFT": (1, 0), "COPY": (1, 1), "F7": (1, 2), "F8": (1, 3), "F5": (1, 4), "F1": (1, 5), "F2": (1, 6),
    "F0": (1, 7),
    "CLR": (2, 0), "[": (2, 1), "RETURN": (2, 2), "]": (2, 3), "F4": (2, 4), "SHIFT": (2, 5), "\\": (2, 6),
    "CONTROL": (2, 7),
    "^": (3, 0), "-": (3, 1), "@": (3, 2), "P": (3, 3), ";": (3, 4), ":": (3, 5), "/": (3, 6), ".": (3, 7),
    "0": (4, 0), "9": (4, 1), "O": (4, 2), "I": (4, 3), "L": (4, 4), "K": (4, 5), "M": (4, 6), ",": (4, 7),
    "8": (5, 0), "7": (5, 1), "U": (5, 2), "Y": (5, 3), "H": (5, 4), "J": (5, 5), "N": (5, 6), "SPACE": (5, 7),
    "6": (6, 0), "5": (6, 1), "R": (6, 2), "T": (6, 3), "G": (6, 4), "F": (6, 5), "B": (6, 6), "V": (6, 7),
    "4": (7, 0), "3": (7, 1), "E": (7, 2), "W": (7, 3), "S": (7, 4), "D": (7, 5), "C": (7, 6), "X": (7, 7),
    "1": (8, 0), "2": (8, 1), "ESC": (8, 2), "Q": (8, 3), "TAB": (8, 4), "A": (8, 5), "CAPS LOCK": (8, 6), "Z": (8, 7),
    "JOY UP": (9, 0), "JOY DOWN": (9, 1), "JOY LEFT": (9, 2), "JOY RIGHT": (9, 3), "JOY FIRE 2": (9, 4),
    "JOY FIRE 1": (9, 5), "JOY FIRE 3": (9, 6), "DEL": (9, 7),
}

DIGITOS = "0123456789"
LETRAS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# C64 key -> CPC key (None: nothing); the digits choose the save slot instead
MAPA = {k: k for k in LETRAS}
MAPA.update({k: None for k in DIGITOS})
MAPA.update({
    "INST/DEL": "DEL", "RETURN": "RETURN", "CRSR RIGHT": "CURSOR RIGHT", "CRSR DOWN": "CURSOR DOWN",
    "F1": "F1", "F3": "F3", "F5": "F5", "F7": "F7", "LEFT SHIFT": "SHIFT", "RIGHT SHIFT": "SHIFT",
    "+": None, "-": "-", ".": ".", ":": ":", "@": "@", ",": ",", "POUND": None, "*": None, ";": ";",
    "CLR/HOME": "CLR", "=": None, "UP ARROW": "^", "/": "/", "LEFT ARROW": "TAB", "CTRL": "CONTROL",
    "SPACE": "SPACE", "C=": "COPY", "RUN/STOP": "ESC",
    "A": "CURSOR DOWN", "O": "CURSOR LEFT", "P": "CURSOR RIGHT",    # Q A O P as the cursors (Q: below)
})
assert set(MAPA) == set(C64)

# joystick port 2: bit (up, down, left, right, fire) -> CPC key
JOYSTICK = ["JOY UP", "JOY DOWN", "JOY LEFT", "JOY RIGHT", "JOY FIRE 1"]


def esperado(teclas, joy=0, ranura="1"):
    """the ten CPC rows (active low) and the save slot that plat_teclado_fila must give for these C64 keys down
    and this joystick port 2 value (bits 0-4 up, down, left, right, fire)"""
    filas = [0xFF] * 10
    # rows that read low with no column selected: keys in the columns the joystick pulls low
    fantasma = {C64[t][1] for t in teclas if joy >> C64[t][0] & 1 and C64[t][0] < 5}
    for b in range(5):
        if joy >> b & 1:
            f, bit = CPC[JOYSTICK[b]]
            filas[f] &= ~(1 << bit) & 0xFF
    for t in teclas:
        if C64[t][1] in fantasma:
            continue
        if t in DIGITOS:
            ranura = t
            continue
        if MAPA[t]:
            f, bit = CPC[MAPA[t]]
            filas[f] &= ~(1 << bit) & 0xFF
    if not filas[8] & 0x08 and filas[6] & 0x04:               # Q without R: cursor up (Q + R: the mirror)
        filas[8] |= 0x08
        filas[0] &= 0xFE
    if not filas[2] & 0x20:                                   # SHIFT: cursor down -> up, right -> left
        if not filas[0] & 0x04:
            filas[0] = (filas[0] | 0x04) & 0xFE
        if not filas[0] & 0x02:
            filas[0] |= 0x02
            filas[1] &= 0xFE
    return filas, ranura
