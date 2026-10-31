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

# data/llave3: the tracer (the hybrid host with a per-frame trace of the key-3 variables).
J       = ../../juego
CFLAGS  = -std=c99 -O2 -g -Wall -Wno-unused-function -I$(J)
FUENTES = $(filter-out $(J)/hibrido.c, $(wildcard $(J)/*.c)) $(J)/z80/z80.c $(J)/m6502/m6502.c $(J)/m6502/6502.c $(J)/m6502/sombra6502.c
traza: traza.c $(J)/hibrido.c $(FUENTES) $(wildcard $(J)/*.h)
	$(CC) $(CFLAGS) -o $@ traza.c $(FUENTES)
clean:
	rm -f traza
.PHONY: clean
