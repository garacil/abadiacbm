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

/* abadia64ks: the counters sim65's 6502 core (6502.c) updates. */
#ifndef PERIPHERALS_H
#define PERIPHERALS_H
#include <stdint.h>
typedef struct { uint64_t ClockCycles, CpuInstructions, IrqEvents, NmiEvents; } CounterPeripheral;
typedef struct { CounterPeripheral Counter; } PeripheralsType;
extern PeripheralsType Peripherals;
#endif
