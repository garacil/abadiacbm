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

/* abadia64ks: the 6502 core of the hybrid host (sim65's, see README.md).  Mem[] is the 6502's 64 KiB
 * (the C64 memory map of the game); m6502_llama runs a routine until its RTS. */
#ifndef M6502_H
#define M6502_H
#include <stdint.h>
#include "6502.h"
extern uint8_t Mem[0x10000];
void m6502_init(void);
/* JSR dir with A, X, Y as given; returns the cycles it took (its RTS reached), or 0 after `max` cycles */
unsigned long m6502_llama(uint16_t dir, uint8_t a, uint8_t x, uint8_t y, unsigned long max);
/* a trap: when the 6502 is about to execute the opcode 02h (JAM, never in real code), this is called
 * with the address of the 02h byte instead (sombra6502.c: a stub that stands for an untranslated
 * function); it must leave the CPU as after the trapped routine's RTS.  0: stop the run (failure). */
extern int (*m6502_trampa)(uint16_t pc);
/* JSR dir with the return address `ret` pushed instead (a routine that reads the bytes after its call: they are
 * at ret + 1); runs until its return leaves SP where it was and PC in [lo, hi); cycles, or 0 after `max` */
unsigned long m6502_llama_hasta(uint16_t dir, uint8_t a, uint16_t ret, uint16_t lo, uint16_t hi, uint16_t alt, unsigned long max);
/* (alt, if not 0: also stop when SP is back with PC = alt: a routine that drops its return address and jumps) */
#endif
