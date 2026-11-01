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

"""The host's external mode for the certification (c64/certifica): the 6502 side of the whole-game run is the real
C64 build in VICE, driven by vice_cert.py through two FIFOs (SOMBRA6502_EXTERNO=prefix: prefix.out the host writes,
prefix.in it reads).  At the start the converted memory (64 KiB) goes out; each frame the inputs go out (the frame
number, 4 bytes LE; the 10 keyboard rows; the Z80's R) and the C64's RAM comes back (a status byte: 1 a frame, 2 the
ending (plat_final), 0 stuck; bit 7 game_init_new_game ran; then 64 KiB); the comparison is the host's own, without
the checked build's platform mirrors (the C64 has none).  Applied to a private copy of juego/: parche_externo.py DIR"""
import sys
from pathlib import Path
p = Path(sys.argv[1]) / "m6502" / "sombra6502.c"; t = p.read_text()
def rep(old, new):
    global t
    assert t.count(old) == 1, old[:70]
    t = t.replace(old, new)
rep("static int j_excl[64], nj_excl, j_excl_nuevo[16], nj_excl_nuevo, j_retoma, j_es_nueva;",
    "static int j_excl[64], nj_excl, j_excl_nuevo[16], nj_excl_nuevo, j_retoma, j_es_nueva;\n"
    "static FILE *x_out, *x_in;     /* the external mode's FIFOs (c64/certifica) */\n"
    "static void x_lee(void *b, size_t n) { if (fread(b, 1, n, x_in) != n) { fprintf(stderr, \"6502 GAME: the external side closed\\n\"); exit(4); } }\n")
rep("    Regs.SP = 0xFF; Regs.SR = 0x34; Regs.PC = j_inicio;\n}",
    "    Regs.SP = 0xFF; Regs.SR = 0x34; Regs.PC = j_inicio;\n"
    "    if (getenv(\"SOMBRA6502_EXTERNO\")) {\n"
    "        char n[512];\n"
    "        snprintf(n, sizeof n, \"%s.out\", getenv(\"SOMBRA6502_EXTERNO\"));\n"
    "        if (!(x_out = fopen(n, \"wb\"))) { fprintf(stderr, \"cannot open %s\\n\", n); exit(4); }\n"
    "        snprintf(n, sizeof n, \"%s.in\", getenv(\"SOMBRA6502_EXTERNO\"));\n"
    "        if (!(x_in = fopen(n, \"rb\"))) { fprintf(stderr, \"cannot open %s\\n\", n); exit(4); }\n"
    "        fwrite(\"CERT\", 1, 4, x_out); fwrite(Mem, 1, 0x10000, x_out); fflush(x_out);\n"
    "    }\n}")
rep("    e = j_corre();\n",
    "    if (x_out) {\n"
    "        uint8_t c[15], st;\n"
    "        c[0] = (uint8_t)frame; c[1] = (uint8_t)(frame >> 8); c[2] = (uint8_t)(frame >> 16); c[3] = (uint8_t)(frame >> 24);\n"
    "        memcpy(c + 4, pe->teclado, 10); c[14] = r;\n"
    "        fwrite(c, 1, 15, x_out); fflush(x_out);\n"
    "        x_lee(&st, 1); x_lee(Mem, 0x10000);\n"
    "        e = st & 3; if (st & 0x80) j_es_nueva = 1;\n"
    "    }\n"
    "    else e = j_corre();\n")
rep("    {\n        static uint8_t pm[0x800];\n        pon_plataforma(pz, pm);",
    "    if (!x_out) {\n        static uint8_t pm[0x800];\n        pon_plataforma(pz, pm);")
p.write_text(t); print("parche aplicado")
