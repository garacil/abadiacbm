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

/* abadia64ks: the glue of sim65's 6502 core for the hybrid host. */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include "m6502.h"
#include "peripherals.h"
#include "error.h"

uint8_t Mem[0x10000];
uint8_t *MemUsados;
PeripheralsType Peripherals;
int (*m6502_trampa)(uint16_t pc);

void Error(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt); fputs("6502: ", stderr); vfprintf(stderr, fmt, ap); fputc('\n', stderr); va_end(ap);
    exit(3);
}

void Warning(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt); fputs("6502: ", stderr); vfprintf(stderr, fmt, ap); fputc('\n', stderr); va_end(ap);
}

void m6502_init(void)
{
    CPU = CPU_6502;
    Regs.SR = 0x30; Regs.SP = 0xFF;
}

/* a return address FFFFh is pushed (the RTS goes to 0000h: FFFF + 1) and the core runs until PC = 0000h
 * with SP back where it was */
unsigned long m6502_llama(uint16_t dir, uint8_t a, uint8_t x, uint8_t y, unsigned long max)
{
    uint8_t sp0 = Regs.SP;
    uint64_t c0 = Peripherals.Counter.ClockCycles;
    Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
    Mem[0x0100 | Regs.SP] = 0xFF; Regs.SP--;
    Regs.PC = dir; Regs.AC = a; Regs.XR = x; Regs.YR = y;
    while (!(Regs.PC == 0x0000 && Regs.SP == sp0)) {
        if (Mem[Regs.PC] == 0x02 && m6502_trampa) {
            if (!m6502_trampa(Regs.PC)) return 0;
            continue;
        }
        ExecuteInsn();
        if (Peripherals.Counter.ClockCycles - c0 > max) return 0;
    }
    return (unsigned long)(Peripherals.Counter.ClockCycles - c0);
}

unsigned long m6502_llama_hasta(uint16_t dir, uint8_t a, uint16_t ret, uint16_t lo, uint16_t hi, uint16_t alt, unsigned long max)
{
    uint8_t sp0 = Regs.SP;
    uint64_t c0 = Peripherals.Counter.ClockCycles;
    Mem[0x0100 | Regs.SP] = (uint8_t)(ret >> 8); Regs.SP--;
    Mem[0x0100 | Regs.SP] = (uint8_t)ret; Regs.SP--;
    Regs.PC = dir; Regs.AC = a;
    while (!(Regs.SP == sp0 && ((Regs.PC >= lo && Regs.PC < hi) || (alt && Regs.PC == alt)))) {
        if (Mem[Regs.PC] == 0x02 && m6502_trampa) {
            if (!m6502_trampa(Regs.PC)) return 0;
            continue;
        }
        ExecuteInsn();
        if (Peripherals.Counter.ClockCycles - c0 > max) return 0;
    }
    return (unsigned long)(Peripherals.Counter.ClockCycles - c0);
}
