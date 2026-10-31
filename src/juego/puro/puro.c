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

/* abadia64ks: the CPC 64 KiB game in pure C, with no Z80 core: the test program.  game_main (f_principal.c,
 * 20BEh) run by the host puro_host.c (the synchronous mode of the hybrid host, see there) from the state
 * the simulator dumped at the game's start (data/cpc64/inicio_juego: ram.bin, estado.txt: PC = 20BEh,
 * SP = C000h, frame 471), frame by frame, writing the per-frame hashes that `hibrido --solo nada
 * --hash-pila 0xAD` writes for the same key script.
 *
 *   puro RAM.bin ESTADO.txt [PUNTOS.txt] --guion KEYS --hasta FRAME [--hashes OUT.tsv] [--ram-final F]
 *        [--r F] [--cinta DIR] [--final F]
 *   --r F      the values of LD A,R at 518Ah recorded by `hibrido --solo nada --registra-r F`
 *   --cinta D  the tape: saved blocks go to D/bloque_II.bin and are loaded from there
 *   --final F  the image of the tape's ending (data/cpc64/cinta/final.bin): block 2Ah
 * (PUNTOS.txt, the hybrid's wait points, is accepted and not read: the waits are in the C code.)  The run
 * ends at FRAME, at the ending (the ending's program is not part of the C game) or at the debug exit. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "puro_host.h"

int main(int argc, char **argv)
{
    const char *hashes = NULL, *ram_final = NULL;
    unsigned hasta = 0;
    FILE *fh = NULL;
    int i = 3, r = 1;
    if (argc < 3) {
        fprintf(stderr, "usage: puro RAM.bin ESTADO.txt [PUNTOS.txt] --guion KEYS --hasta FRAME [--hashes OUT] [--ram-final F] [--r F] [--cinta DIR] [--final F]\n");
        return 2;
    }
    carga_estado(argv[1], argv[2]);
    if (argc > 3 && strncmp(argv[3], "--", 2)) i = 4;
    for (; i < argc; ++i) {
        if (!strcmp(argv[i], "--guion") && i + 1 < argc) carga_guion(argv[++i]);
        else if (!strcmp(argv[i], "--hasta") && i + 1 < argc) hasta = (unsigned)atoi(argv[++i]);
        else if (!strcmp(argv[i], "--hashes") && i + 1 < argc) hashes = argv[++i];
        else if (!strcmp(argv[i], "--ram-final") && i + 1 < argc) ram_final = argv[++i];
        else if (!strcmp(argv[i], "--r") && i + 1 < argc) carga_aleatorios(argv[++i]);
        else if (!strcmp(argv[i], "--cinta") && i + 1 < argc) puro_cinta(argv[++i]);
        else if (!strcmp(argv[i], "--final") && i + 1 < argc) puro_final(argv[++i]);
        else { fprintf(stderr, "unknown option %s\n", argv[i]); return 2; }
    }
    if (hashes) fh = fopen(hashes, "w");
    while (frame < hasta && (r = corre_frame(fh)) == 1) ;
    if (fh) fclose(fh);
    if (ram_final) {
        FILE *f = fopen(ram_final, "wb");
        if (f) { fwrite(ram, 1, 0x10000, f); fclose(f); }
    }
    fprintf(stderr, "frames to %u, %lu interrupts%s\n", frame, ticks,
            r == 2 ? "; the ending: the program loaded from the tape, not part of the C game" :
            r == 0 ? "; the debug exit: the CPC resets" : "");
    return 0;
}
