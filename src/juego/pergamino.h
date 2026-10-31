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

/* The parchments of the CPC 64 KiB version in C (pergamino.c): the introduction (the tape's first stage,
 * block 16h) and the ending (block 2Ah), the same code 6000h-68A8h with their own text, borders and tune,
 * drawn into the CPC screen memory of ds as the Z80 draws it and timed as the Z80 runs: the program keeps
 * the emulated time in Z80 T-states (4 MHz, SkoolKit's timings, those of tools/cpc_carga.py)
 * with the 300 Hz interrupt every 13312 T-states and a 50 Hz frame every 6 interrupts.  Also the tape
 * loader's loading screen (the picture arriving with the game's block). */
#ifndef PERGAMINO_H
#define PERGAMINO_H

#include <stdint.h>

#define PERG_TICK 13312u                  /* T-states between two 300 Hz interrupts (3328 us) */
#define PERG_FRAME (6u * PERG_TICK)       /* a 50 Hz frame */

extern uint64_t perg_t;                   /* emulated time: T-states since perg_reloj */
extern unsigned long perg_ticks;          /* 300 Hz interrupts since then (taken or not) */
extern unsigned long perg_frames;         /* 50 Hz frames since then: perg_ticks / 6 */
extern void (*perg_al_frame)(void);       /* the platform: at every frame, with the screen as it is then */

/* the clock to 0, interrupts enabled or not (the tape loader calls 6000h with them off, and so does the
 * game's 31CFh); the clock of cpc_carga.py --imagen ... --call 6000 --int */
void perg_reloj(int iff);
/* the time runs until T-state t (nothing of the parchment runs: a stage's work outside it) */
void perg_espera(uint64_t t);

/* the stage's image has just been put in ds: the next pergamino() starts the music player from its state */
void pergamino_nuevo(void);
/* CALL 6000h: the parchment, from the stage in ds (6000h-8BFFh), until space is pressed; then the music
 * stops and the screen goes black (every ink black, the screen memory cleared) and it returns */
void pergamino(void);

/* the game's end, 31DAh: CALL 6000h; JR 31DAh for ever (the clock of cpc_carga.py --imagen cinta/final.bin
 * --call 31DA --int) */
void pergamino_final(void);

/* the tape loader after the introduction (0133h-014Bh): mode 0 and the inks of its table at 0103h
 * (00C6h), the CRTC for 32 x 24 characters (01E9h), then the game's block arriving from FFFFh down to
 * 0200h, the picture appearing in the screen memory as its bytes arrive.  `cargador` is the loader's
 * memory (its table at 0103h), `juego` the memory once the block is loaded (cinta/juego.bin: the picture
 * at C000h-FFFFh).  The tape takes minutes; here the 16 KiB of the screen arrive in `ms_pantalla`
 * milliseconds of emulated time and the picture then stays `ms_resto` milliseconds (the rest of the
 * block, 0200h-BFFFh, is the game's, loaded by the platform from its own snapshot). */
void pantalla_de_carga(const uint8_t *cargador, const uint8_t *juego, unsigned ms_pantalla, unsigned ms_resto);

#endif
