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

/* abadia64ks: the host of the game in pure C (puro_host.c) for GNU programs: the platform (plat_*) of the
 * synchronous mode, and the game run frame by frame with the interface of the hybrid host (hibrido.c), so
 * a front-end can use either: corre_frame runs the game to its next frame point.  No Z80 core. */
#ifndef PURO_HOST_H
#define PURO_HOST_H

#include <stdio.h>
#include "../juego64.h"

/* the machine state the platform keeps: the video (gate array, CRTC) for a front-end to draw */
extern uint8_t paleta[17], modo, crtc[32];
/* a front-end's keys held now, per matrix row (bit set = down), ORed with the --guion keys */
extern uint8_t teclas_vivas[16];
/* a front-end's sound: every AY register write */
extern void (*al_psg)(uint8_t reg, uint8_t v);
/* a front-end's hook at every frame point */
extern void (*en_frame)(void);
/* the frame counter (main-loop iterations and pausa passes) and the 300 Hz interrupts delivered */
extern unsigned frame;
extern unsigned long ticks;

typedef struct { unsigned frame, frames; uint8_t fila, bit; } tecla_t;

/* the game's start state: ds[] from RAM.bin, the frame, the SP and the video state from estado.txt (the
 * game starts at 20BEh) */
void carga_estado(const char *ram_file, const char *estado);
/* the hybrid's wait points: accepted and not read (the waits are in the C code) */
void carga_puntos(const char *p);
/* keys by frame: lines 'FRAME ROW:BIT [FRAMES]' */
void carga_guion(const char *p);
/* the values LD A,R read at 518Ah, recorded by `hibrido --solo nada --registra-r F` */
void carga_aleatorios(const char *p);
/* the tape: a directory for the saved blocks; the image of the tape's ending (cinta/final.bin) */
void puro_cinta(const char *dir);
void puro_final(const char *final_bin);

/* runs the game to its next frame point, whose hash goes to fh (if any; the stack below the SP of the frame
 * point left out, as `hibrido --hash-pila 0xAD`).  1: a frame; 2: the game is at its ending (31CFh, the tape
 * loading of block 2Ah: a front-end shows the ending; corre_frame again goes on as the CPC does); 0: the
 * game has left (the debug exit). */
int corre_frame(FILE *fh);
/* at the next corre_frame the game goes to its 100 % ending, as 3E29h does: the cursor at 8006h, 3EC6h */
void puro_salta_final(void);

#endif
