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

# abadia64ks: the game.  `make hibrido`: the hybrid host (Z80 core + C functions), see hibrido.c; it
# also carries the 6502 core and the 6502 checks (m6502/, `--6502 DIR`).
CC      = gcc
CFLAGS  = -std=c99 -O2 -g -Wall -Wextra
FUENTES = $(filter-out hibrido.c, $(wildcard *.c))
M6502   = m6502/m6502.c m6502/6502.c m6502/sombra6502.c
hibrido: hibrido.c $(FUENTES) juego.h $(wildcard *.h) z80/z80.c z80/z80.h $(M6502) $(wildcard m6502/*.h)
	$(CC) $(CFLAGS) -o $@ hibrido.c $(FUENTES) z80/z80.c $(M6502)
clean:
	rm -f hibrido
.PHONY: clean
