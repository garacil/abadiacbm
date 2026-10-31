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

/* Forced shadow checks of the group camino for the paths the 8 exploration sessions never take
 * (route to another floor, the FE/FD/FC destinations, no candidate, the camera room near): the hybrid
 * host runs a session up to a frame (its own arguments), then, from that state, many deterministic
 * pseudo-random set-ups (a monk moved to a place of the abbey, candidate targets taken from the
 * places tables and the characters, other floors) call the translated functions through the same
 * shadow check as the sessions (llamada_traducida: C and Z80 from the same state, all the RAM, SP, PC
 * and the declared results compared).
 *   forzado RAM.bin ESTADO.txt PUNTOS.txt --guion KEYS.txt --hasta FRAME [--pruebas N] [--semilla S] */
#define main hibrido_main
#include "../hibrido.c"
#undef main
#include "../datos_camino.h"

void ai_plan_route(uint16_t chr, uint16_t places, uint16_t sp);

/* 03AC ai_plan_route is a label (JP from the drivers): checked here as a function of its own */
static void w_03AC(void) { uint16_t sp = cpu.sp; ai_plan_route(cpu.iy, cpu.ix, sp); cpu.sp = sp; z80_ret(); }
static const traducida_t t_03AC = { 0x03AC, "ai_plan_route", w_03AC, sin_resultados };

static uint32_t semilla = 12345;
static unsigned azar(unsigned n) { semilla = semilla * 1103515245u + 12345u; return (unsigned)((semilla >> 16) % n); }

static const uint16_t monjes[5] = { D64_CHR_ADSO, D64_CHR_MALACHI, D64_CHR_ABBOT, D64_CHR_BERENGAR, D64_CHR_SEVERIN };
static const uint16_t sitios[5] = { D64_AI_ADSO_PLACES, D64_AI_MALACHI_PLACES, D64_AI_ABBOT_PLACES, D64_AI_BERENGAR_PLACES, D64_AI_SEVERIN_PLACES };
static const uint8_t nsitios[5] = { 3, 9, 10, 7, 5 };

/* a random place of the abbey (x, y, orient<<6 | z): a place of a monk's table or a character's position */
static void un_sitio(uint8_t *s)
{
    unsigned k = azar(6);
    uint16_t p;
    if (k == 5) {
        p = (uint16_t)(D64_CHR_GUILLERMO + 15 * azar(6) + 2);
        s[0] = rb(p); s[1] = rb((uint16_t)(p + 1)); s[2] = (uint8_t)(rb((uint16_t)(p + 2)) | azar(4) << 6);
        return;
    }
    p = (uint16_t)(sitios[k] + 3 * azar(nsitios[k]));
    s[0] = rb(p); s[1] = rb((uint16_t)(p + 1)); s[2] = rb((uint16_t)(p + 2));
}

static void llama(const traducida_t *t, uint16_t entrada)
{
    cpu.sp = (uint16_t)(cpu.sp - 2);
    ww(cpu.sp, 0x2179);                       /* a return address: back to the main loop */
    cpu.pc = entrada;
    llamada_traducida(t);
}

int main(int argc, char **argv)
{
    static uint8_t ram_s[0x10000];
    z80 cpu_s;
    const traducida_t *find = buscada(0x05FA), *plan = &t_03AC, *grid = buscada(0x082F);
    unsigned pruebas = 3000, i, j, n, cuentas[6] = { 0, 0, 0, 0, 0, 0 };
    int k, a = 1;
    for (k = 1; k < argc; ++k) {
        if (!strcmp(argv[k], "--pruebas") && k + 1 < argc) { pruebas = (unsigned)atoi(argv[++k]); continue; }
        if (!strcmp(argv[k], "--semilla") && k + 1 < argc) { semilla = (uint32_t)atoi(argv[++k]); continue; }
        argv[a++] = argv[k];
    }
    hibrido_main(a, argv);                    /* the session up to --hasta */
    memcpy(ram_s, ram, sizeof ram);
    cpu_s = cpu;
    fallos_c = 0;
    for (i = 0; i < pruebas; ++i) {
        unsigned m = azar(5), cual = azar(6);
        uint16_t chr = monjes[m];
        uint8_t s[3];
        memcpy(ram, ram_s, sizeof ram);
        cpu = cpu_s;
        if (azar(3)) {                        /* the monk moved to a place of the abbey */
            un_sitio(s);
            wb((uint16_t)(chr + 2), s[0]); wb((uint16_t)(chr + 3), s[1]); wb((uint16_t)(chr + 4), (uint8_t)(s[2] & 0x3F));
            wb((uint16_t)(chr + 1), (uint8_t)azar(4));
        }
        wb(D64_CHR_PATH_FOUND_NOW, 0);
        wb(D64_CHR_GUILLERMO_ANIM_COPY, (uint8_t)(azar(8) ? 0 : 1));
        cpu.iy = chr;
        if (cual == 5) {                      /* chr_path_find from a room with stairs down to the ground floor */
            static const uint16_t enlaces[2] = { D64_CHR_ROOM_LINKS_FLOOR1, D64_CHR_ROOM_LINKS_FLOOR2 };
            static const uint8_t bases[2] = { 0x0B, 0x16 };
            uint8_t salas[256];
            unsigned piso = azar(2), ns = 0, r;
            for (r = 0; r < 256 && enlaces[piso] + r < D64_CHR_ROOM_LINKS + D64_CHR_ROOM_LINKS_SIZE; ++r)
                if (rb((uint16_t)(enlaces[piso] + r)) & 0x20) salas[ns++] = (uint8_t)r;
            if (ns) {
                r = salas[azar(ns)];
                wb((uint16_t)(chr + 2), (uint8_t)((r & 0x0F) << 4 | (2 + azar(12))));
                wb((uint16_t)(chr + 3), (uint8_t)((r & 0xF0) | (2 + azar(12))));
                wb((uint16_t)(chr + 4), (uint8_t)(bases[piso] + azar(3)));
            }
            do un_sitio(s); while ((s[2] & 0x3F) >= 0x0D);
            wb(D64_CHR_PATH_ALTERNATIVES, s[0]);
            wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 1), s[1]);
            wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 2), s[2]);
            wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3), 0xFF);
            ww(D64_CHR_PATH_ALT_PTR, D64_CHR_PATH_ALTERNATIVES);
            cpu.ix = D64_CHR_PATH_ALTERNATIVES;
            llama(find, 0x05FA);
            cuentas[0]++;
            continue;
        }
        if (cual == 0) {                      /* chr_path_find towards 1-4 candidates */
            n = 1 + azar(4);
            for (j = 0; j < n; ++j) {
                un_sitio(s);
                wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3 * j), s[0]);
                wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3 * j + 1), s[1]);
                wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3 * j + 2), s[2]);
            }
            wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3 * n), 0xFF);
            ww(D64_CHR_PATH_ALT_PTR, D64_CHR_PATH_ALTERNATIVES);
            cpu.ix = D64_CHR_PATH_ALTERNATIVES;
            llama(find, 0x05FA);
        } else if (cual == 1) {               /* ai_plan_route with any destination */
            uint16_t places = sitios[m];
            unsigned d = azar(4 + nsitios[m]);
            wb((uint16_t)(places - 1), (uint8_t)(d < 4 ? 0xFC + d : d - 4));   /* FC..FF or a place */
            if (azar(4)) wb((uint16_t)(chr + 9), (uint8_t)(rb((uint16_t)(chr + 9)) | 0x80));
            wb(D64_AI_NO_ROUTE, (uint8_t)(azar(8) ? 0 : 1));
            cpu.ix = places;
            llama(plan, 0x03AC);
        } else if (cual == 2) {               /* the grid of the search */
            llama(grid, 0x082F);
        } else if (cual == 3) {               /* the grid for a monk near Guillermo, on any floor */
            static const uint8_t pisos[3] = { 0x00, 0x0B, 0x16 };
            wb((uint16_t)(chr + 2), (uint8_t)(rb(D64_CHR_GUILLERMO + 2) + azar(41) - 20));
            wb((uint16_t)(chr + 3), (uint8_t)(rb(D64_CHR_GUILLERMO + 3) + azar(41) - 20));
            wb((uint16_t)(chr + 4), (uint8_t)(pisos[azar(3)] + azar(4)));
            llama(grid, 0x082F);
        } else {                              /* ai_plan_route to a place in Guillermo's room */
            uint16_t places = sitios[m];
            unsigned d = azar(nsitios[m]);
            uint16_t p = (uint16_t)(places + 3 * d);
            wb((uint16_t)(places - 1), (uint8_t)d);
            if (azar(3) == 0) {               /* or the book there (FD), high: all its neighbours may fail */
                wb((uint16_t)(places - 1), 0xFD);
                p = (uint16_t)(D64_OBJ_OBJECTS + 2);
            }
            wb(p, (uint8_t)(rb(D64_CHR_GUILLERMO + 2) + azar(17) - 8));
            wb((uint16_t)(p + 1), (uint8_t)(rb(D64_CHR_GUILLERMO + 3) + azar(17) - 8));
            wb((uint16_t)(p + 2), (uint8_t)((p == D64_OBJ_OBJECTS + 2 ? 0 : azar(4) << 6) | (rb(D64_CHR_GUILLERMO + 4) + azar(8))));
            wb((uint16_t)(chr + 9), (uint8_t)(rb((uint16_t)(chr + 9)) | 0x80));
            wb(D64_AI_NO_ROUTE, 0);
            cpu.ix = places;
            llama(plan, 0x03AC);
        }
        cuentas[cual]++;
    }
    fprintf(stderr, "forced: %u chr_path_find, %u ai_plan_route, %u chr_path_build_grid; %lu differences\n",
            cuentas[0], cuentas[1] + cuentas[4], cuentas[2] + cuentas[3], fallos_c);
    if (salida_cobertura) {
        FILE *f = fopen(salida_cobertura, "w");
        unsigned c;
        for (c = 0; c < 0x10000; ++c) if (cubierto[c]) fprintf(f, "%04X\n", c);
        fclose(f);
    }
    return fallos_c ? 1 : 0;
}
