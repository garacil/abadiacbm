/*
 * abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
 *
 * Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
 * Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
 * implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see
 * <https://www.gnu.org/licenses/>.
 */

/* abadia64ks, c64/optimizacion/interrupcion/pruebas: the memory of sim65's core (juego/m6502/6502.c) as a plain
 * array, as juego/m6502/memory.h, with a hook on every write (psg.c logs the SID writes).  prueba.sh compiles a
 * copy of the core with this header in its place. */
#ifndef MEMORY_H
#define MEMORY_H
#include <stdint.h>
extern uint8_t Mem[0x10000];
extern void (*mem_al_escribir)(uint16_t a, uint8_t v);
static inline void MemWriteByte(uint16_t a, uint8_t v) { Mem[a] = v; if (mem_al_escribir) mem_al_escribir(a, v); }
static inline uint8_t MemReadByte(uint16_t a) { return Mem[a]; }
static inline uint16_t MemReadWord(uint16_t a) { return (uint16_t)(Mem[a] | Mem[(uint16_t)(a + 1)] << 8); }
static inline uint16_t MemReadZPWord(uint8_t a) { return (uint16_t)(Mem[a] | Mem[(uint8_t)(a + 1)] << 8); }
#endif
