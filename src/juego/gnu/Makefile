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

# abadia64ks for GNU (SDL2): the game played in a window, with the parchments (../pergamino.c, ../musica.c)
# and the hybrid host (../hibrido.c); `make abadia64ks-puro`: the same with the game in pure C
# (../puro/puro_host.c, no Z80 core).  TRABAJO: the project's data/ (the tape's images, the game's start).
CFLAGS ?= -std=c99 -O2 -Wall -Wno-unused-function
TRABAJO ?= $(abspath ../../../data)
FUENTES = $(filter-out ../hibrido.c, $(wildcard ../*.c)) ../z80/z80.c
PUROS   = $(wildcard ../f_*.c) ../funciones.c ../pergamino.c ../musica.c ../puro/puro_host.c
SDL     = $(shell pkg-config --cflags sdl2)
todo: abadia64ks abadia64ks-puro
abadia64ks: abadia64ks.c ../hibrido.c $(FUENTES) ../*.h
	$(CC) $(CFLAGS) -I.. $(SDL) -DTRABAJO='"$(TRABAJO)"' -o $@ abadia64ks.c $(FUENTES) $(shell pkg-config --libs sdl2) -lm
abadia64ks-puro: abadia64ks.c $(PUROS) ../*.h ../puro/puro_host.h
	$(CC) $(CFLAGS) -I.. $(SDL) -DPURO -DJUEGO_PURO -DTRABAJO='"$(TRABAJO)"' -o $@ abadia64ks.c $(PUROS) $(shell pkg-config --libs sdl2) -lm
clean:
	rm -f abadia64ks abadia64ks-puro
.PHONY: clean todo
