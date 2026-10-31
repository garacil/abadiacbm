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

/* size-measurement shim: the data space at fixed addresses, accessors as macros */
#ifndef ABADIA_H
#define ABADIA_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#define _Noreturn
#define inline
#define __has_include(x) 1
#define ds ((uint8_t *)0x0000)
#define vram ((uint8_t *)0x0000)
#define cs_mem ((uint8_t *)0x0000)
extern uint8_t slots[];
extern const uint8_t *voice_pirata, *voice_ave;
extern size_t voice_pirata_len, voice_ave_len;
#define rb(a) (ds[(uint16_t)(a)])
#define rw(a) (*(uint16_t *)(ds + (uint16_t)(a)))
#define wb(a, v) (ds[(uint16_t)(a)] = (uint8_t)(v))
#define ww(a, v) (*(uint16_t *)(ds + (uint16_t)(a)) = (uint16_t)(v))
extern bool cs_mem_escrito;
#define cs8(a) (cs_mem[(a) & 0x7FFF])
#define cs16(a) (*(uint16_t *)(cs_mem + ((a) & 0x7FFF)))
#define cs8_set(a, v) (cs_mem[(a) & 0x7FFF] = (v))
#define cs16_set(a, v) (*(uint16_t *)(cs_mem + ((a) & 0x7FFF)) = (v))
#define vb(a) (vram[(uint16_t)(a)])
#define vwb(a, v) (vram[(uint16_t)(a)] = (v))
enum { OP_RET = 0xC3, OP_NOP = 0x90 };
#include "direcciones.h"
#include "estado_cs.h"
#include "plat.h"
#include "tipos.h"
#include "funciones.h"
#endif
