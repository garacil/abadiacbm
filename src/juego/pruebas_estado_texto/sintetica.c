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

/* Synthetic shadow checks of the estado_texto functions the exploration sessions do not reach (or reach
 * on few paths): the hybrid host's machinery (hibrido.c included) from a RAM image of session 1, frame
 * 3000, with chosen registers and memory.  Every call: the C wrapper and the Z80 original from the same
 * state, compared as the host does. */
#define main hibrido_main
#include "../hibrido.c"
#undef main

static uint8_t base_ram[0x10000];
static z80 base_cpu;
static unsigned long pruebas;

/* key 4Fh (row 9, bit 7) as a function of the number of reads of row 9 in this run */
static unsigned lecturas;
static const char *patron = "";          /* 'p' pressed, '.' released, then the last one stays */
static uint8_t mi_puerto(z80 *z, uint16_t port)
{
    uint8_t v = puerto_in(z, port);
    if ((port >> 8) == 0xF4 && psg_reg == 14 && (fila & 0x0F) == 9 && patron[0]) {
        size_t n = strlen(patron);
        char c = patron[lecturas < n ? lecturas : n - 1];
        ++lecturas;
        if (c == 'p') v &= 0x7F; else v |= 0x80;
    }
    return v;
}

static const traducida_t *busca(const char *nombre)
{
    int g;
    const traducida_t *t;
    for (g = 0; grupos[g]; ++g)
        for (t = grupos[g]; t->nombre; ++t)
            if (!strcmp(t->nombre, nombre)) return t;
    fprintf(stderr, "no %s\n", nombre);
    exit(2);
}

static void desde_base(void) { memcpy(ram, base_ram, sizeof ram); cpu = base_cpu; }

/* the shadow call of `nombre` with the registers in cpu, the return address ret on the stack */
static void sombra(const char *nombre, uint16_t ret)
{
    const traducida_t *t = busca(nombre);
    z80 c0, cz, zz;
    cpu.sp = (uint16_t)(cpu.sp - 2);
    ram[cpu.sp] = (uint8_t)ret;
    ram[(uint16_t)(cpu.sp + 1)] = (uint8_t)(ret >> 8);
    cpu.pc = t->dir;
    c0 = cpu;
    ++llamadas_c;
    ++pruebas;
    memcpy(ram0, ram, sizeof ram);
    sp_entrada = sp_minimo = cpu.sp;
    lecturas = 0;
    t->envoltorio();
    cz = cpu;
    memcpy(ram_c, ram, sizeof ram);
    memcpy(ram, ram0, sizeof ram);
    cpu = c0;
    lecturas = 0;
    corre_z80_hasta_retorno();
    zz = cpu;
    compara(t, &cz, &zz);
}

static void pon_bytes(uint16_t a, const char *hex)
{
    unsigned v;
    while (sscanf(hex, "%2x", &v) == 1) {
        ram[a++] = (uint8_t)v;
        hex += 2;
        while (*hex == ' ') ++hex;
    }
}

static unsigned semilla = 12345;
static unsigned azar(void) { semilla = semilla * 1103515245u + 12345u; return (semilla >> 8) & 0xFFFF; }

int main(void)
{
    const char *T = getenv("ABADIA64_TRABAJO") ? getenv("ABADIA64_TRABAJO") : "/home/german/proyectos/abadia64ks/trabajo";
    char p1[256], p2[256];
    unsigned i, k;
    static const char *expr[] = {
        "05 03 2D C9", "40 F0 40 0F 26 C9", "40 F0 40 3C 2A C9", "07 07 3D 20", "07 08 3D 20",
        "07 08 3E 20", "08 07 3E 20", "07 08 3C 20", "08 07 3C 20", "88 40 05 2B 18",
        "88 AA 3D 05 06 3C 26 CF", "01 02 03 2B 2B C3", "40 40 40 C9 3D C2", "7F CD", "80 81 2D D7",
        "40 FF 40 01 2B 40 00 3D 20", "8B 89 2A 8C 26 9E 2D C9", 0 };
    snprintf(p1, sizeof p1, "%s", getenv("SINTETICA_RAM") ? getenv("SINTETICA_RAM") : "r3000.bin");
    snprintf(p2, sizeof p2, "%s/cpc64/inicio_juego/estado.txt", T);
    carga_estado(p1, p2);
    cpu.sp = 0xBF80;
    cpu.port_in = mi_puerto;
    memcpy(base_ram, ram, sizeof ram);
    base_cpu = cpu;

    desde_base(); sombra("obj_open_left_wing_doors", 0x2179);
    desde_base(); sombra("vid_palette_night", 0x2179);
    desde_base(); sombra("vid_palette_day", 0x2179);
    desde_base(); sombra("vid_palette_black", 0x2179);

    desde_base();                                          /* monks flipped */
    ram[0x2BA5 + 6] = 1; ram[0x2BB4 + 6] = 0; ram[0x2BC3 + 6] = 2; ram[0x2BD2 + 6] = 1;
    sombra("spr_unflip_monk_faces", 0x2179);
    { unsigned d = 0; for (i = 0; i < 0x10000; ++i) d += ram[i] != base_ram[i]; printf("monks: %u bytes changed\n", d); }
    desde_base(); sombra("spr_unflip_monk_faces", 0x2179);

    desde_base();                                          /* a load: taken objects and the lamp */
    ram[0x2B81] |= 0x80;
    ram[0x2B59] |= 0x80; ram[0x2B59 + 10] |= 0x80; ram[0x2B59 + 25] |= 0x80; ram[0x2B59 + 35] |= 0x80;
    ram[0x2B59 + 15] |= 0x80; ram[0x2B59 + 30] |= 0x80;
    ram[0x2940] = 0x84; ram[0x2947] = 0x20; ram[0x294E] = 0x01; ram[0x2955] = 0x00; ram[0x295C] = 0x10;
    sombra("obj_fix_owner_pointers", 0x2179);
    desde_base(); ram[0x2B81] &= 0x7F; sombra("obj_fix_owner_pointers", 0x2179);

    for (k = 0; k < 4; ++k) {                              /* arrival: equal / different */
        desde_base();
        cpu.ix = 0x0054;
        ram[0x0053] = (uint8_t)(k * 3); ram[0x0051] = (uint8_t)(k < 2 ? k * 3 : 7); ram[0x0052] = (uint8_t)(0xFE + k);
        sombra("ai_next_state_on_arrival", 0x2179);
    }

    for (i = 0; expr[i]; ++i) {                            /* the expressions: 3926, RST 08h, RST 10h */
        desde_base(); pon_bytes(0x0060, expr[i]); SET_HL(0x0060); sombra("ai_script_eval", 0x2179);
        desde_base(); pon_bytes(0x0060, expr[i]); sombra("ai_script_test", 0x0060);
        desde_base(); ram[0x005F] = 0x8A; pon_bytes(0x0060, expr[i]); sombra("ai_script_assign", 0x005F);
        desde_base(); ram[0x005F] = (uint8_t)(0x80 + i); pon_bytes(0x0060, expr[i]); sombra("ai_script_assign", 0x005F);
        desde_base(); pon_bytes(0x0060, expr[i]); SET_HL(0x0060); sombra("ai_script_operand", 0x2179);
        desde_base(); cpu.a = (uint8_t)(0x80 + 3 * i); sombra("ai_script_var_ptr", 0x2179);
    }

    for (k = 0; k < 7; ++k) {                              /* the jump table */
        desde_base();
        pon_bytes(0x0070, "11 11 22 22 33 33 00 00 C9");
        cpu.zf = k == 0;
        cpu.c = (uint8_t)(k == 6 ? 0 : k);
        sombra("util_jump_table_inline", 0x0070);
        printf("table k=%u: PC %04X SP %04X\n", k, cpu.pc, cpu.sp);
    }

    for (k = 0; k < 4; ++k) {                              /* the hour update */
        uint16_t rec;
        desde_base();
        rec = (uint16_t)(ram[0x28D9] | ram[0x28DA] << 8);
        ram[rec] = (uint8_t)(ram[rec] & 0xFE);
        ram[0x37E7] = (uint8_t)(k & 1);
        ram[0x28F3] = (uint8_t)(k >> 1);
        sombra("ai_hour_update", 0x2179);
        printf("hour k=%u: [37E7] %02X [28D2] %02X -> %02X\n", k, ram[0x37E7], base_ram[0x28D2], ram[0x28D2]);
    }

    for (k = 0; k < 3; ++k) {                              /* height lists with kinds 0, 6, 7 and clipping */
        desde_base();
        ram[0x354A] = (uint8_t)(0x10 + 4 * k);
        ram[0x354E] = (uint8_t)(0x10 - 3 * k);
        pon_bytes(0x0080, "36 12 14 23  50 08 0C 45  2F 20 0E 05 30  41 0E 1F 33  8D 00 00 40 40"
                          "  12 15 15 11  23 26 08 32  44 09 27 21  1C 10 10 03 02  FF");
        cpu.ix = 0x0080;
        sombra("chr_hbuf_fill_list", 0x2179);
    }

    for (i = 0; i < 20000; ++i) {                          /* the span clip, random */
        desde_base();
        cpu.l = (uint8_t)azar(); cpu.h = (uint8_t)(cpu.l + (azar() % 64) - 32);
        if (i & 1) cpu.h = (uint8_t)azar();
        cpu.d = (uint8_t)(azar() % (i & 2 ? 256 : 40)); cpu.e = (uint8_t)(i & 4 ? 0x18 : azar());
        sombra("util_clip_span", 0x2179);
        if ((i & 7) == 0) { cpu = base_cpu; cpu.h = (uint8_t)azar(); cpu.d = (uint8_t)(azar() % 32); sombra("chr_hbuf_clip_x", 0x2179); }
    }

    for (i = 0; i < 3000; ++i) {                           /* screen addresses, bits, the tile check */
        desde_base(); SET_HL(azar() | 0xC000); sombra("vid_next_line", 0x2179);
        desde_base(); SET_HL(azar()); sombra("vid_xy_to_offset", 0x2179);
        desde_base(); cpu.a = (uint8_t)azar(); cpu.e = (uint8_t)azar(); cpu.cf = azar() & 1; sombra("util_bits_set_or_clear", 0x2179);
        desde_base(); cpu.ix = (uint16_t)(i < 8 ? (const uint16_t[]){ 0, 0xFFFF, 0x8780, 0x877F, 0x8EFF, 0x8F00, 0x8B00, 0x9000 }[i] : azar());
        sombra("spr_tile_ptr_check", 0x2179);
    }

    for (i = 0; i < 256; ++i) {                            /* every character, both masks */
        desde_base(); ram[0x28E8] = (uint8_t)(0x10 + (i & 15) * 2); ram[0x28E9] = (uint8_t)(0x20 + (i & 0x70));
        cpu.a = (uint8_t)i; sombra("txt_draw_char", 0x2179);
        desde_base(); ram[0x28E8] = (uint8_t)(0x3E); ram[0x28E9] = 0xB7;
        cpu.a = (uint8_t)i; sombra("txt_draw_char_inverted", 0x2179);
    }

    desde_base(); SET_HL(0xB580); cpu.b = 0; sombra("txt_skip_words", 0x2179);
    desde_base(); SET_HL(0xB580); cpu.b = 1; sombra("txt_skip_words", 0x2179);

    /* the pause: Del pressed, held, released, pressed again */
    patron = "pp..p";
    desde_base(); llama_z80(0x2D50);
    sombra("sys_check_pause_save_load", 0x2179);
    printf("pause 1: %u reads of row 9, iff1 %d, A %02X ZF %d, [0C07] %02X\n", lecturas, cpu.iff1, cpu.a, cpu.zf, ram[0x0C07]);
    patron = "pppp..pp";
    desde_base(); llama_z80(0x2D50);
    sombra("sys_check_pause_save_load", 0x2179);
    printf("pause 2: %u reads of row 9\n", lecturas);
    patron = "";
    desde_base(); sombra("sys_check_pause_save_load", 0x2179);
    printf("no pause: %u reads\n", lecturas);

    /* a new game, the state blocks */
    desde_base(); sombra("game_init_new_game", 0x2179);
    desde_base(); sombra("game_snapshot_initial_state", 0x2179);
    desde_base(); SET_HL(0x316B); sombra("game_for_each_state_block", 0x2179);
    desde_base(); SET_HL(0x0050); SET_BC(5); sombra("util_clear_bytes", 0x2179);

    printf("%lu synthetic calls, %lu differences\n", pruebas, fallos_c);
    return fallos_c ? 1 : 0;
}
