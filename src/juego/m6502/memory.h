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

/* abadia64ks: the memory of sim65's 6502 core (6502.c) as a plain 64 KiB array (m6502.c). */
#ifndef MEMORY_H
#define MEMORY_H
#include <stdint.h>
extern uint8_t Mem[0x10000];
extern uint8_t *MemUsados;      /* --usados6502 (hibrido.c): per address, bit 0 read, bit 1 written, bit 2 executed; NULL: off */
static inline void MemWriteByte(uint16_t a, uint8_t v) { if (MemUsados) MemUsados[a] |= 2; Mem[a] = v; }
static inline uint8_t MemReadByte(uint16_t a) { if (MemUsados) MemUsados[a] |= 1; return Mem[a]; }
static inline uint16_t MemReadWord(uint16_t a) { return (uint16_t)(MemReadByte(a) | MemReadByte((uint16_t)(a + 1)) << 8); }
static inline uint16_t MemReadZPWord(uint8_t a) { return (uint16_t)(MemReadByte(a) | MemReadByte((uint8_t)(a + 1)) << 8); }
#endif
