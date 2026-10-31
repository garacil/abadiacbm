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

# abadia64ks: the game in pure C, no Z80 core.  `make`: puro, the test program (puro.c on the host
# puro_host.c): the game files of juego/ built with JUEGO_PURO (their hybrid wrappers and checks left out),
# C89 declarations checked in the game code.
CC      = gcc
CFLAGS  = -std=c99 -O2 -g -Wall -Wextra -DJUEGO_PURO -I..
JUEGO   = $(wildcard ../f_*.c) ../funciones.c
OBJ     = $(patsubst ../%.c,%.o,$(JUEGO))
puro: puro.c puro_host.c puro_host.h $(OBJ)
	$(CC) $(CFLAGS) -o $@ puro.c puro_host.c $(OBJ)
%.o: ../%.c $(wildcard ../*.h)
	$(CC) $(CFLAGS) -Wdeclaration-after-statement -c -o $@ $<
clean:
	rm -f puro *.o
.PHONY: clean
