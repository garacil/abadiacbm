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

"""The key-3 manoeuvre on the Caprice32 (/home/german/retro/amstrad/computer, doc/control_fifo.md): the
original game with real CPC timing (the 300 Hz interrupt when the CRTC gives it, not at the hybrid host's wait
points), on Xvfb :99.  Caprice32 cannot hold keys from outside frame by frame, so the key script goes inside
the CPC: the unchanged start state data/puro/estados/ram_d2h4.bin with three patches in memory the run
never uses (checked with `hibrido --accesos --cobertura`: no read, write or instruction there):
  * 217Ah LD A,(2B87h) -> CALL 01C0h: LD A,(2B87h) and the game frame counter at 01F0h + 1 (as
    tools/cpc_velocidad.py), once per main-loop iteration;
  * 2D77h IN A,(C) / LD B,A of sys_read_keyboard -> CALL 3200h (inyecta.asm, in the tape code 31E8h-344Bh):
    the rows 0 and 1 ANDed with the script's keys of the current game frame;
  * 323Dh: the script as a table (game frame, row 0 mask, row 1 mask) from guion_llave3.txt.
The game frame of hybrid frame F is F - 471 (estado.txt starts at frame 471; the hybrid counts a frame at
2179h, the main loop's head, one instruction before 217Ah).

    caprice_llave3.py comprueba    the patched start state in the hybrid host with no key script: its trace
                                   must equal the scripted run's (so the table gives the game the same keys)
    caprice_llave3.py corre [N]    Caprice32: the patched state as .sna, run until game frame N (850), pictures
                                   at the frames of ../fotos.txt, then the result (Adso's objects, key 3's record)
"""
import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
L = os.path.dirname(AQUI)
P = os.path.dirname(os.path.dirname(L))
T = os.path.join(P, 'data')
sys.path.insert(0, os.path.join(P, 'tools'))
sys.path.insert(0, L)
import cpc_velocidad as cv                            # noqa: E402  (sna, lee_estado, Cap)
from piloto import lee_traza                          # noqa: E402

BASE = 471
CUENTA, PARCHE, INYECTA, TABLA = 0x01F0, 0x01C0, 0x3200, 0x323D


def guion(path):
    k = []
    for linea in open(path):
        linea = linea.split('#')[0].split()
        if len(linea) >= 2:
            r, b = (int(v) for v in linea[1].split(':'))
            k.append((int(linea[0]), r, b, int(linea[2]) if len(linea) > 2 else 15))
    return k


def tabla(teclas, hasta):
    """(game frame, row 0 AND mask, row 1 AND mask) where the keys change, from game frame 0"""
    filas = []
    antes = None
    for f in range(BASE, hasta + 1):
        m = [0xFF, 0xFF]
        for fr, r, b, n in teclas:
            if fr <= f < fr + n and r < 2:
                m[r] &= ~(1 << b) & 0xFF
        if m != antes:
            filas.append((f - BASE, m[0], m[1]))
            antes = m
    out = bytearray()
    for c, m0, m1 in filas:
        out += bytes([c & 255, c >> 8, m0, m1])
    out += bytes([0xFF, 0xFF, 0xFF, 0xFF])
    return out


def imagen(hasta=1400):
    ram = bytearray(open(os.path.join(T, 'puro/estados/ram_d2h4.bin'), 'rb').read())
    assert ram[0x217A:0x217D] == bytes([0x3A, 0x87, 0x2B])          # LD A,(2B87h)
    assert ram[0x2D77:0x2D7A] == bytes([0xED, 0x78, 0x47])          # IN A,(C) / LD B,A
    ram[0x217A:0x217D] = bytes([0xCD, PARCHE & 255, PARCHE >> 8])
    ram[PARCHE:PARCHE + 13] = bytes([0x3A, 0x87, 0x2B, 0xE5, 0x2A, CUENTA & 255, CUENTA >> 8, 0x23,
                                     0x22, CUENTA & 255, CUENTA >> 8, 0xE1, 0xC9])
    ram[CUENTA:CUENTA + 2] = b'\0\0'
    ram[0x2D77:0x2D7A] = bytes([0xCD, INYECTA & 255, INYECTA >> 8])
    subprocess.run(['z80asm', '-o', os.path.join(AQUI, 'inyecta.bin'), os.path.join(AQUI, 'inyecta.asm')],
                   check=True)
    cod = open(os.path.join(AQUI, 'inyecta.bin'), 'rb').read()
    assert len(cod) == TABLA - INYECTA
    t = tabla(guion(os.path.join(L, 'guion_llave3.txt')), hasta)
    assert TABLA + len(t) <= 0x344C, 'the table does not fit in the tape code'
    ram[INYECTA:INYECTA + len(cod)] = cod
    ram[TABLA:TABLA + len(t)] = t
    return bytes(ram), len(t) // 4


def comprueba():
    ram, n = imagen()
    img = os.path.join(AQUI, 'ram_d2h4_parcheada.bin')
    open(img, 'wb').write(ram)
    vacio = os.path.join(AQUI, 'sin_teclas.txt')
    open(vacio, 'w').write('# no keys: the patched game reads its own table\n')
    tr = os.path.join(AQUI, 'traza_parcheada.tsv')
    subprocess.run([os.path.join(L, 'traza'), tr, img, os.path.join(T, 'cpc64/inicio_juego/estado.txt'),
                    os.path.join(T, 'sincrono/puntos64.txt'), '--guion', vacio, '--hasta', '1300', '--limite',
                    '50000000', '--solo', 'nada'], check=True)
    a = lee_traza(tr)
    b = lee_traza(os.path.join(L, 'resultados/traza_original.tsv'))
    campos = ('G', 'A', 'M', 'objA', 'Mrsd', 'key3', 'day', 'hour')
    malos = [f for f in sorted(a) if f in b and any(a[f][c] != b[f][c] for c in campos)]
    print('table: %d entries; patched run against the scripted run, frames %d-%d: %s'
          % (n, min(a), max(a), 'identical positions, objects, key 3, Malachi' if not malos else
             'DIFFERENT from frame %d' % malos[0]))
    return not malos


def corre(hasta):
    ram, n = imagen()
    out = os.path.join(AQUI, 'resultados')
    os.makedirs(out, exist_ok=True)
    e = cv.lee_estado(os.path.join(T, 'cpc64/inicio_juego/estado.txt'))
    sna = os.path.join(out, 'ram_d2h4_parcheada.sna')
    cv.sna(ram, e, sna)
    fotos = [int(v) - BASE for v in open(os.path.join(L, 'fotos.txt')).read().split() if not v.startswith('#')
             and v.strip().isdigit()]
    c = cv.Cap(os.path.join(out, 'cap32.sock'), os.path.join(out, 'cap32.log'))
    try:
        c.orden('loadsnap %s' % sna)
        c.orden('resume')
        pend = sorted(fotos)
        lecturas = []
        k = 0
        while True:
            vf, cuenta = c.lectura(out, k)
            k += 1
            lecturas.append((vf, cuenta))
            while pend and cuenta >= pend[0]:
                c.orden('screenshot %s' % os.path.join(out, 'cpc_%06d.png' % (pend[0] + BASE)))
                print('picture at game frame %d (hybrid frame %d): the first reading at or past it is %d'
                      % (pend[0], pend[0] + BASE, cuenta))
                pend.pop(0)
            if cuenta >= hasta:
                break
        c.orden('pause')
        pk = os.path.join(out, 'final.txt')
        if os.path.exists(pk):
            os.unlink(pk)
        c.orden('peek 0x2940 0x10 %s' % pk)
        p1 = c.espera_fichero(pk)
        pk2 = os.path.join(out, 'final2.txt')
        if os.path.exists(pk2):
            os.unlink(pk2)
        c.orden('peek 0x2B77 5 %s' % pk2)
        p2 = c.espera_fichero(pk2)
        pk3 = os.path.join(out, 'final3.txt')
        if os.path.exists(pk3):
            os.unlink(pk3)
        c.orden('peek 0x2B87 0x2D %s' % pk3)
        p3 = c.espera_fichero(pk3)
        with open(os.path.join(out, 'medidas.tsv'), 'w') as f:
            f.write('emulated_video_frame\tgame_frame\n')
            for vf, cuenta in lecturas:
                f.write('%d\t%d\n' % (vf, cuenta))
        print('at game frame %d (hybrid frame %d):' % (cuenta, cuenta + BASE))
        print('  2940-294F (Guillermo objects .. Adso holder):', p1.strip())
        print('  2B77 key 3:', p2.strip())
        print('  2B87 Guillermo, 2B96 Adso, 2BA5 Malachi records:', p3.strip())
    finally:
        c.cierra()
        for f in os.listdir(out):                    # the readings' files of cpc_velocidad.Cap.lectura
            if (f.startswith('st') or f.startswith('pk')) and f.endswith('.txt'):
                os.unlink(os.path.join(out, f))


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'comprueba':
        sys.exit(0 if comprueba() else 1)
    elif len(sys.argv) > 1 and sys.argv[1] == 'corre':
        corre(int(sys.argv[2]) if len(sys.argv) > 2 else 850)
    else:
        sys.exit(__doc__)
