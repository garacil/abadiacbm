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

/* The platform layer: the parts of the PC the original program uses (PIT, speaker, keyboard,
 * PIC, CGA, BIOS video/disk/keyboard services, interrupt vectors), emulated exactly like the
 * synchronous mode of the emulator tools/pcemu.py, plus the window, sound and
 * keyboard of the host (SDL2) or a headless verification run driven by a script.
 *
 * Time.  The clock counts microseconds of the original machine.  It advances only where the
 * original program waits (data/re/sincrono/puntos.txt):
 *   plat_wait()        one interrupt: the next key event if it is due before the next timer tick,
 *                      else a timer tick (the clock moves to it, the next one is one PIT0 period later,
 *                      period = divisor * 1000000 / 1193182 us rounded down, at least 1);
 *   plat_delay(n, k)   a delay loop of n passes (0 = 65536) of k us: every interrupt due within
 *                      n * k us, then the clock moves to the end (nothing for n <= 1).
 * Each interrupt calls the handler installed in the vector table: a game function (segment
 * 1000, kind `isr` in the interfaces) or the BIOS default. */
#ifndef PLAT_H
#define PLAT_H

#include <stdbool.h>
#include <stdint.h>

void plat_wait(void);
void plat_delay(uint32_t n, uint32_t k_us);
void plat_frame(void);                  /* call at the top of every main-loop iteration (1000:1FC3) */
uint32_t plat_clock(void);

void plat_out(uint16_t port, uint8_t value);
uint8_t plat_in(uint16_t port);

typedef struct { uint16_t ax, bx, cx, dx, es; bool cf; } bios_regs;
void plat_int10(bios_regs *r);          /* video: AH=00 mode, 02/03 cursor, 09/0A/0E text, 0B palette, 0F state */
void plat_int13(bios_regs *r);          /* disk: AH=00 reset, 02 read, 03 write (ES:BX in segment 2800 or 1800) */
bool plat_int16_get(uint16_t *ax);      /* keyboard AH=00 without waiting: false when the BIOS buffer is empty */
uint16_t plat_bios_memory_kb(void);     /* word [0:0413] */

void plat_set_vector(uint8_t n, uint16_t off, uint16_t seg);
uint16_t plat_vector_off(uint8_t n);
uint16_t plat_vector_seg(uint8_t n);
_Noreturn void plat_reboot(void);       /* JMP FFFF:0000 */

/* Start-up and the run itself (main.c). */
void plat_init(int argc, char **argv);
void plat_hw_state(uint8_t out[19]);    /* the hardware part of the canonical state (pcemu.py hw_state) */
size_t plat_state(uint8_t *out);        /* canonical state (pcemu.py state()); out NULL = size only */

/* Host side (plat_sdl.c), called by plat.c. */
void host_init(void);
void host_poll(void);                   /* keyboard and window events -> plat_key() */
void host_present(void);                /* show vram with the CGA registers */
void host_sound(uint32_t clock, uint8_t port61, uint8_t pit2_mode, uint32_t pit2_div, bool pit2_written);
void host_pace(uint32_t clock);         /* sleep so that the clock follows real time */
void host_quit(void);
void plat_key(uint8_t scancode);        /* a key event from the host (make code, or break with bit 7) */
void plat_cga_rgb(uint8_t *rgb);   /* the screen as the CGA shows it */

#endif
