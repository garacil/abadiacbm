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

/* abadia64ks, group logica_a: the functions of the CPC 64 KiB addresses 3AAF-4C45 translated to C, with
 * their wrappers and result checks for the hybrid host (table traducidas_logica_a).  Each function cites
 * its 64K address and the PC rebuild's function it corresponds to (c/src); the 64K code is the
 * reference.  Data names: datos_logica_a.h. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "juego64.h"
#include "datos_logica_a.h"

/* ==== registers of the wrappers and their checks ==================================================== */

#ifndef JUEGO_PURO  /* the hybrid host */
#define R_A   0x0001u
#define R_F   0x0002u            /* every flag */
#define R_B   0x0004u
#define R_C   0x0008u
#define R_D   0x0010u
#define R_E   0x0020u
#define R_H   0x0040u
#define R_L   0x0080u
#define R_IX  0x0100u
#define R_IY  0x0200u
#define R_ZF  0x0400u
#define R_CF  0x0800u
#define R_BC  (R_B | R_C)
#define R_DE  (R_D | R_E)
#define R_HL  (R_H | R_L)
#define R_TODOS (R_A | R_F | R_BC | R_DE | R_HL | R_IX | R_IY)

static uint8_t banderas(const z80 *z)
{
    return (uint8_t)(z->sf << 7 | z->zf << 6 | z->yf << 5 | z->hf << 4 | z->xf << 3 | z->pf << 2 | z->nf << 1 | z->cf);
}

/* the registers m of s back into the CPU (what the Z80 function preserves) */
static void repone(const z80 *s, unsigned m)
{
    if (m & R_A) cpu.a = s->a;
    if (m & R_F) {
        cpu.sf = s->sf; cpu.zf = s->zf; cpu.yf = s->yf; cpu.hf = s->hf;
        cpu.xf = s->xf; cpu.pf = s->pf; cpu.nf = s->nf; cpu.cf = s->cf;
    }
    if (m & R_ZF) cpu.zf = s->zf;
    if (m & R_CF) cpu.cf = s->cf;
    if (m & R_B) cpu.b = s->b;
    if (m & R_C) cpu.c = s->c;
    if (m & R_D) cpu.d = s->d;
    if (m & R_E) cpu.e = s->e;
    if (m & R_H) cpu.h = s->h;
    if (m & R_L) cpu.l = s->l;
    if (m & R_IX) cpu.ix = s->ix;
    if (m & R_IY) cpu.iy = s->iy;
}

static int dif8(const char *nombre, unsigned c, unsigned z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %02X Z80 %02X", nombre, c, z);
    return 0;
}

static int dif16(const char *nombre, unsigned c, unsigned z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %04X Z80 %04X", nombre, c, z);
    return 0;
}

/* the registers m of the C run (cz) and the Z80 run (zz) */
static int compara_regs(const z80 *cz, const z80 *zz, char *msg, size_t n, unsigned m)
{
    int ok = 1;
    if (m & R_A) ok &= dif8("A", cz->a, zz->a, msg, n);
    if (m & R_F) ok &= dif8("F", banderas(cz), banderas(zz), msg, n);
    if (m & R_ZF) ok &= dif8("ZF", cz->zf, zz->zf, msg, n);
    if (m & R_CF) ok &= dif8("CF", cz->cf, zz->cf, msg, n);
    if (m & R_B) ok &= dif8("B", cz->b, zz->b, msg, n);
    if (m & R_C) ok &= dif8("C", cz->c, zz->c, msg, n);
    if (m & R_D) ok &= dif8("D", cz->d, zz->d, msg, n);
    if (m & R_E) ok &= dif8("E", cz->e, zz->e, msg, n);
    if (m & R_H) ok &= dif8("H", cz->h, zz->h, msg, n);
    if (m & R_L) ok &= dif8("L", cz->l, zz->l, msg, n);
    if (m & R_IX) ok &= dif16("IX", cz->ix, zz->ix, msg, n);
    if (m & R_IY) ok &= dif16("IY", cz->iy, zz->iy, msg, n);
    return ok;
}

#define CHEQUEO(nombre, m) \
    static int nombre(const z80 *cz, const z80 *zz, char *msg, size_t n) { return compara_regs(cz, zz, msg, n, (m)); }

static uint8_t paridad_par(uint8_t v)
{
    v ^= (uint8_t)(v >> 4); v ^= (uint8_t)(v >> 2); v ^= (uint8_t)(v >> 1);
    return (uint8_t)!(v & 1);
}

/* the flags of AND (h = 1), OR / XOR (h = 0) with result r */
static void banderas_logicas(uint8_t r, uint8_t h)
{
    cpu.sf = r >> 7; cpu.zf = r == 0; cpu.yf = (r >> 5) & 1; cpu.hf = h; cpu.xf = (r >> 3) & 1;
    cpu.pf = paridad_par(r); cpu.nf = 0; cpu.cf = 0;
}

/* the return of a function with inline data that pops its return address and pushes it back advanced:
 * the CALL's slot holds the address past the data, PC = that address, the slot popped */
static void retorna_a(uint16_t pc)
{
    ww(cpu.sp, pc);
    cpu.pc = pc;
    cpu.sp = (uint16_t)(cpu.sp + 2);
}

/* EXX (the scaffolding of the Z80 calls of the functions that use the shadow registers) */
static void exx(void)
{
    uint8_t t;
    t = cpu.b; cpu.b = cpu.b_; cpu.b_ = t;
    t = cpu.c; cpu.c = cpu.c_; cpu.c_ = t;
    t = cpu.d; cpu.d = cpu.d_; cpu.d_ = t;
    t = cpu.e; cpu.e = cpu.e_; cpu.e_ = t;
    t = cpu.h; cpu.h = cpu.h_; cpu.h_ = t;
    t = cpu.l; cpu.l = cpu.l_; cpu.l_ = t;
}
#endif

/* the C call of chr_apply_step as the Z80 code uses it (CALL 2539): x += [hl], y += [hl+1] of the
 * character chr; the HL it leaves (hl + 1) */
static uint16_t apply_step(uint16_t chr, uint16_t hl)
{
    (void)chr_apply_step(chr, hl);
    return (uint16_t)(hl + 1);
}

/* ==== 3AAF-3B3A: the spiral wipe ===================================================================== */

/* 3B2A vid_spiral_put (PC 1000:5E4B): writes v at the screen byte of (row H, byte column L) (3778) and at
 * the same place of the next pixel line (3558).  In: A = v, HL = yx.  Every register and flag preserved. */
void vid_spiral_put(uint8_t v, uint16_t yx)
{
    uint16_t p = vid_xy_to_offset(yx);                      /* 3B2E CALL 3778 */
    wscr(p, v);                                             /* 3B31 */
    p = vid_next_line(p);                                   /* 3B33 CALL 3558 */
    wscr(p, v);                                             /* 3B37 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3B2A(void)
{
    z80 s = cpu;
    vid_spiral_put(cpu.a, HL);
    repone(&s, R_TODOS);
    z80_ret();
}
CHEQUEO(r_3B2A, R_TODOS)
#endif

/* 3AC3 vid_spiral_pass (PC 1000:5DD8): a square spiral of bytes from (0,0) inwards over the play area:
 * 20h turns right / down (2 rows per step) / left / up, with the side lengths in vid_spiral_sides
 * (3AAB..3AAE, set to 3F 4F 3F 4E, each shrinking by 2 per turn, the first one by 1 on the first turn);
 * the byte drawn starts at 0 and is XORed with e after every turn; one last byte at the end.  Side
 * counts use DJNZ (0 would mean 256).  In: E.  Out: HL = the last position (yx), A = 0 (ZF = 1, the flags
 * of XOR E), B = 0, IX = 3AABh; C, DE preserved. */
uint16_t vid_spiral_pass(uint8_t e)
{
    uint8_t l = 0, h = 0, a = 0, turn, c;
    wb(D64_VID_SPIRAL_SIDES, 0x3F);                         /* 3ACA-3AD6 */
    wb(D64_VID_SPIRAL_SIDES + 1, 0x4F);
    wb(D64_VID_SPIRAL_SIDES + 2, 0x3F);
    wb(D64_VID_SPIRAL_SIDES + 3, 0x4E);
    for (turn = 0x20; turn; turn--) {                       /* 3ADA LD B,20h ... 3B24 DJNZ */
        c = rb(D64_VID_SPIRAL_SIDES);                       /* 3ADE / 3AE4 */
        if (turn != 0x20) wb(D64_VID_SPIRAL_SIDES, (uint8_t)(rb(D64_VID_SPIRAL_SIDES) - 1));   /* 3AE7 */
        wb(D64_VID_SPIRAL_SIDES, (uint8_t)(rb(D64_VID_SPIRAL_SIDES) - 1));                      /* 3AEA */
        do { vid_spiral_put(a, (uint16_t)(h << 8 | l)); l++; } while (--c);                     /* 3AED-3AF1 */
        c = rb(D64_VID_SPIRAL_SIDES + 1);                   /* 3AF3-3AF9 */
        wb(D64_VID_SPIRAL_SIDES + 1, (uint8_t)(c - 2));
        do { vid_spiral_put(a, (uint16_t)(h << 8 | l)); h = (uint8_t)(h + 2); } while (--c);   /* 3AFC-3B01 */
        c = rb(D64_VID_SPIRAL_SIDES + 2);                   /* 3B03-3B09 */
        wb(D64_VID_SPIRAL_SIDES + 2, (uint8_t)(c - 2));
        do { vid_spiral_put(a, (uint16_t)(h << 8 | l)); l--; } while (--c);                     /* 3B0C-3B10 */
        c = rb(D64_VID_SPIRAL_SIDES + 3);                   /* 3B12-3B18 */
        wb(D64_VID_SPIRAL_SIDES + 3, (uint8_t)(c - 2));
        do { vid_spiral_put(a, (uint16_t)(h << 8 | l)); h = (uint8_t)(h - 2); } while (--c);   /* 3B1B-3B20 */
        a ^= e;                                             /* 3B23 */
    }
    vid_spiral_put(a, (uint16_t)(h << 8 | l));              /* 3B26 */
    return (uint16_t)(h << 8 | l);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3AC3(void)
{
    z80 s = cpu;
    uint16_t yx = vid_spiral_pass(cpu.e);
    repone(&s, R_C | R_DE | R_IY);
    SET_HL(yx);
    cpu.a = 0; banderas_logicas(0, 0);
    cpu.b = 0;
    cpu.ix = D64_VID_SPIRAL_SIDES;
    z80_ret();
}
CHEQUEO(r_3AC3, R_TODOS)
#endif

/* 3AAF vid_spiral_wipe (PC 1000:5DC4): the screen effect of an hour change: two spiral passes (bytes
 * alternating 00/FF, then all 00), then chr_room_x := 0 so that the room is drawn again.  Out: A = 0
 * (flags of XOR A), E = 0, B = 0, HL = the last spiral position; C, D, IX, IY preserved. */
uint16_t vid_spiral_wipe(void)
{
    uint16_t yx;
    vid_spiral_pass(0xFF);                                  /* 3AB2-3AB4 */
    yx = vid_spiral_pass(0x00);                             /* 3AB7-3AB9 */
    wb(D64_CHR_ROOM_X, 0);                                  /* 3ABE-3ABF */
    return yx;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3AAF(void)
{
    z80 s = cpu;
    uint16_t yx = vid_spiral_wipe();
    repone(&s, R_C | R_D | R_IX | R_IY);
    SET_HL(yx);
    cpu.a = 0; banderas_logicas(0, 0);
    cpu.b = 0; cpu.e = 0;
    z80_ret();
}
CHEQUEO(r_3AAF, R_TODOS)
#endif

/* ==== 3B3B-3C8E, 3D87: scripted placements of objects and characters (called by the scripts of other
 * groups; none of them runs in the exploration sessions except obj_malachi_leaves_key3) ========== */


/* 3C84 util_copy5_inline_ds (PC 1000:5FCB): `CALL 3C84 <dw dst> <db 5 bytes>`: ds[dst..dst+4] := the 5
 * bytes (LDIR), and the return goes to the caller's caller (the return address is popped and not pushed
 * back).  Not in the table: it never returns to its caller; the C callers return right after it. */
void util_copy5_inline_ds(uint16_t dst, const uint8_t src[5])
{
    uint8_t i;
    for (i = 0; i < 5; i++) wb((uint16_t)(dst + i), src[i]);
}

/* 3B66 obj_malachi_leaves_key3 (PC 1000:5EA5): when Malaquias holds key 3 (bit 1 of his objects): he
 * loses it and it goes back on the table (record 2B77 := 00 00 35 35 13, inline at 3B74).  No outputs. */
void obj_malachi_leaves_key3(void)
{
    static const uint8_t key3_on_table[5] = { 0x00, 0x00, 0x35, 0x35, 0x13 };   /* 3B76-3B7A */
    uint8_t a = rb(D64_OBJ_MALACHI_OBJECTS);                /* 3B66 */
    if (!(a & 0x02)) return;                                /* 3B69-3B6B */
    wb(D64_OBJ_MALACHI_OBJECTS, (uint8_t)(a & 0xFD));       /* 3B6C-3B6E */
    util_copy5_inline_ds(0x2B77, key3_on_table);            /* 3B71 CALL 3C84 <77 2B> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3B66(void)
{
    obj_malachi_leaves_key3();
    z80_ret();
}
#endif

static const uint8_t cinco_ceros[5] = { 0x00, 0x00, 0x00, 0x00, 0x00 };

#ifndef JUEGO_PURO  /* the hybrid host */
/* the registers util_copy5_inline_ds leaves (LDIR of 5 bytes from the inline data `datos` to dst): HL past
 * the data, DE = dst + 5, BC = 0, H/N/PV flags cleared */
static void copy5_registros(uint16_t datos, uint16_t dst)
{
    SET_HL((uint16_t)(datos + 7));
    SET_DE((uint16_t)(dst + 5));
    SET_BC(0);
    cpu.hf = 0; cpu.nf = 0; cpu.pf = 0;
}
#endif

/* 3B3B obj_lamp_reset (PC 1000:5E6B): when Malaquias' holder has the lamp (294B bit 7) or the lamp time is
 * running: obj_lamp_placed := 0, ai_lamp_time := 0, ai_lamp_in_use := 0 (a byte: the PC clears a word),
 * bit 7 cleared in the Adso and Malaquias holders, the lamp record 2B81 := 0 (inline at 3B5C, the
 * 'iso_draw_tile_run' of the listings).  Callers 592B, 5AA7. */
void obj_lamp_reset(void)
{
    uint16_t t = rw(D64_AI_LAMP_TIME);
    if (((rb(D64_OBJ_MALACHI_HOLDER) & 0x80) | (uint8_t)(t >> 8) | (uint8_t)t) == 0) return;   /* 3B3B-3B45 */
    wb(D64_OBJ_LAMP_PLACED, 0);                             /* 3B46-3B47 */
    ww(D64_AI_LAMP_TIME, 0);                                /* 3B4A-3B4C */
    wb(D64_AI_LAMP_IN_USE, 0);                              /* 3B4F */
    wb(D64_GAME_ADSO_LAMP, rb(D64_GAME_ADSO_LAMP) & 0x7F);  /* 3B52-3B55 */
    wb(D64_OBJ_MALACHI_HOLDER, rb(D64_OBJ_MALACHI_HOLDER) & 0x7F);   /* 3B57-3B5A */
    util_copy5_inline_ds(0x2B81, cinco_ceros);              /* 3B5C CALL 3C84 <81 2B> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3B3B(void)
{
    uint16_t t = rw(D64_AI_LAMP_TIME);
    bool hace = ((rb(D64_OBJ_MALACHI_HOLDER) & 0x80) | (uint8_t)(t >> 8) | (uint8_t)t) != 0;
    obj_lamp_reset();
    if (hace) copy5_registros(0x3B5F, 0x2B81);
    z80_ret();
}
#endif

/* 3B7B obj_remove_glasses (PC 1000:5EBC): Guillermo and the Berengario slot lose the glasses (bit 5), the
 * score bar is redrawn (4D2A hud_draw_guillermo_objects, IX kept) and the glasses record 2B63 := 0.
 * Caller 5AB3. */
void obj_remove_glasses(void)
{
    wb(D64_B2_GUILLERMO_OBJECTS, rb(D64_B2_GUILLERMO_OBJECTS) & 0xDF);   /* 3B7B-3B80 */
    wb(D64_OBJ_BERENGAR_OBJECTS, rb(D64_OBJ_BERENGAR_OBJECTS) & 0xDF);   /* 3B83-3B88 */
    hud_draw_guillermo_objects();                           /* 3B8B-3B90 PUSH IX / CALL 4D2A / POP IX */
    util_copy5_inline_ds(0x2B63, cinco_ceros);              /* 3B92 CALL 3C84 <63 2B> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3B7B(void)
{
    obj_remove_glasses();
    copy5_registros(0x3B95, 0x2B63);
    z80_ret();
}
#endif

/* 3BE1 util_store_dx_at_bx (PC 1000:5F21): [hl] := e, [hl+1] := d.  Out: HL + 2. */
uint16_t util_store_dx_at_bx(uint16_t hl, uint16_t de)
{
    wb(hl, (uint8_t)de);                                    /* 3BE1 */
    wb((uint16_t)(hl + 1), (uint8_t)(de >> 8));             /* 3BE3 */
    return (uint16_t)(hl + 2);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3BE1(void)
{
    SET_HL(util_store_dx_at_bx(HL, DE));
    z80_ret();
}
CHEQUEO(r_3BE1, R_HL)
#endif

/* 3BE6 chr_set_face_and_place (PC 1000:5F28): spr_unflip_monk_faces (304F; HL, DE kept), [slot] := face
 * (util_store_dx_at_bx), then JP 3C84 with the 7 inline bytes after the caller's CALL 3BE6 (dst word + 5
 * bytes): it returns to the caller's caller.  Not in the table: it does not return to its caller; the C
 * callers return right after it. */
void chr_set_face_and_place(uint16_t slot, uint16_t face, uint16_t dst, const uint8_t src[5])
{
    spr_unflip_monk_faces();                                /* 3BE6-3BEC */
    (void)util_store_dx_at_bx(slot, face);                  /* 3BED */
    util_copy5_inline_ds(dst, src);                         /* 3BF0 JP 3C84 */
}

/* 3B9C chr_bernardo_arrives (PC 1000:5EDB): the Berengario slot becomes Bernardo Gui (face B293h in
 * spr_monk_faces + 4) at the abbey entrance (chr_berengar+1.. := 00 88 88 02 00).  Caller 5AF2. */
void chr_bernardo_arrives(void)
{
    static const uint8_t lugar[5] = { 0x00, 0x88, 0x88, 0x02, 0x00 };   /* 3BA7-3BAB */
    chr_set_face_and_place(D64_SPR_MONK_FACES + 4, 0xB293, D64_CHR_BERENGAR + 1, lugar);   /* 3B9C-3BA2 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3B9C(void)
{
    chr_bernardo_arrives();
    copy5_registros(0x3BA5, D64_CHR_BERENGAR + 1);
    z80_ret();
}
#endif

/* 3BAC chr_jorge_appears (PC 1000:5EEB): the Severino slot gets the face B2F7h (spr_monk_faces + 6),
 * chr_severin+1.. := 03 12 65 18 00.  Caller 5A8A. */
void chr_jorge_appears(void)
{
    static const uint8_t lugar[5] = { 0x03, 0x12, 0x65, 0x18, 0x00 };   /* 3BB7-3BBB */
    chr_set_face_and_place(D64_SPR_MONK_FACES + 6, 0xB2F7, D64_CHR_SEVERIN + 1, lugar);   /* 3BAC-3BB2 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3BAC(void)
{
    chr_jorge_appears();
    copy5_registros(0x3BB5, D64_CHR_SEVERIN + 1);
    z80_ret();
}
#endif

/* 3BBC chr_berengar_vanishes (PC 1000:5EFB): the cell under the Berengario slot ([chr_berengar+0Ch]) :=
 * 10h, chr_berengar+0Ah, +0Bh := 0, face B2F7h in spr_monk_faces + 4 and chr_berengar+1.. := 00 C8 24 00
 * 00 (out of the map).  Caller 5ABF. */
void chr_berengar_vanishes(void)
{
    static const uint8_t lugar[5] = { 0x00, 0xC8, 0x24, 0x00, 0x00 };   /* 3BD3-3BD7 */
    wb(rw(D64_CHR_BERENGAR + 0x0C), 0x10);                  /* 3BBC-3BC0 */
    wb(D64_CHR_BERENGAR + 0x0A, 0);                         /* 3BC1-3BC7 */
    wb(D64_CHR_BERENGAR + 0x0B, 0);
    chr_set_face_and_place(D64_SPR_MONK_FACES + 4, 0xB2F7, D64_CHR_BERENGAR + 1, lugar);   /* 3BC8-3BCE */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3BBC(void)
{
    chr_berengar_vanishes();
    copy5_registros(0x3BD1, D64_CHR_BERENGAR + 1);
    z80_ret();
}
#endif

/* 3BD8 chr_berengar_hooded (PC 1000:5F18): spr_unflip_monk_faces (304F), then face B35Bh (the hooded monk)
 * in spr_monk_faces + 4 (falls into util_store_dx_at_bx).  Caller 5582.  Out: HL = 2BEE, DE = B35B. */
void chr_berengar_hooded(void)
{
    spr_unflip_monk_faces();                                /* 3BD8 */
    (void)util_store_dx_at_bx(D64_SPR_MONK_FACES + 4, 0xB35B);   /* 3BDB-3BE0, falls into 3BE1 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3BD8(void)
{
    chr_berengar_hooded();
    SET_HL(D64_SPR_MONK_FACES + 6);
    SET_DE(0xB35B);
    z80_ret();
}
CHEQUEO(r_3BD8, R_HL | R_DE)
#endif

/* the shared tail 3C0F-3C1A: holder drops its object (4DCD obj_drop_object, IX = holder; IX and IY kept),
 * then game_idle_frames := 0 */
static void drop_and_reset_idle(uint16_t holder)
{
    obj_drop_object(holder);                                /* 3C0F CALL 4DCD (IX, IY kept: 3C12-3C14) */
    wb(D64_GAME_IDLE_FRAMES, 0);                            /* 3C16-3C17 */
}

/* 3BF3 obj_jorge_drops_book (PC 1000:5F35): the Severino holder (2960) drops its object, then
 * game_idle_frames := 0.  Caller 5738.  Out: A = 0. */
void obj_jorge_drops_book(void)
{
    drop_and_reset_idle(D64_OBJ_SEVERIN_HOLDER);            /* 3BF3-3BFB JR 3C0F */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3BF3(void)
{
    obj_jorge_drops_book();
    cpu.a = 0;
    banderas_logicas(0, 0);
    z80_ret();
}
CHEQUEO(r_3BF3, R_A | R_F | R_IX | R_IY)
#endif

/* 3BFD obj_abbot_drops_parchment (PC 1000:5F3C): when the abbot holds the parchment (bit 4):
 * obj_abbot_takemask := 0 and the abbot's holder (2952) drops it, game_idle_frames := 0.  Caller 5B97.
 * Out: A = 0, ZF = 1 either way. */
void obj_abbot_drops_parchment(void)
{
    if (!(rb(D64_OBJ_ABBOT_OBJECTS) & 0x10)) return;        /* 3BFD-3C02 */
    wb(D64_OBJ_ABBOT_TAKEMASK, 0);                          /* 3C03-3C04 */
    drop_and_reset_idle(D64_OBJ_ABBOT_HOLDER);              /* 3C07-3C0B */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3BFD(void)
{
    bool tiene = (rb(D64_OBJ_ABBOT_OBJECTS) & 0x10) != 0;
    obj_abbot_drops_parchment();
    cpu.a = 0;
    if (tiene) banderas_logicas(0, 0); else banderas_logicas(0, 1);
    z80_ret();
}
CHEQUEO(r_3BFD, R_A | R_F | R_IX | R_IY)
#endif

/* 3C1B obj_abbot_wants_parchment (PC 1000:5F59, obj_abbot_takemask := 10h): a lone RET in the 64K game,
 * still called by the abbot's script (5C49).  No inputs, no outputs. */
void obj_abbot_wants_parchment(void)
{
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C1B(void)
{
    obj_abbot_wants_parchment();
    z80_ret();
}
#endif

/* the inline placements: `CALL 3C84 <dw record> <5 bytes>`; the copy returns to the caller.  The
 * wrappers leave the registers of the copy (copy5_registros). */
/* 3C1C obj_place_parchment (PC 1000:5F5F): parchment record 2B68 := 00 00 18 64 18. Caller 5ACE. */
void obj_place_parchment(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x18, 0x64, 0x18 };
    util_copy5_inline_ds(0x2B68, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C1C(void)
{
    obj_place_parchment();
    copy5_registros(0x3C1F, 0x2B68);
    z80_ret();
}
#endif

/* 3C26 obj_place_parchment_unused (PC 1000:5F69): (no caller) record 2B68 := 00 00 58 3C 02. */
void obj_place_parchment_unused(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x58, 0x3C, 0x02 };
    util_copy5_inline_ds(0x2B68, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C26(void)
{
    obj_place_parchment_unused();
    copy5_registros(0x3C29, 0x2B68);
    z80_ret();
}
#endif

/* 3C52 obj_place_key1 (PC 1000:5F99): key 1 record 2B6D := 00 00 89 3E 08. Caller 5A7E. */
void obj_place_key1(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x89, 0x3E, 0x08 };
    util_copy5_inline_ds(0x2B6D, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C52(void)
{
    obj_place_key1();
    copy5_registros(0x3C55, 0x2B6D);
    z80_ret();
}
#endif

/* 3C5C obj_remove_key1 (PC 1000:5FA3): record 2B6D := 0. Caller 5ADE. */
void obj_remove_key1(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x00, 0x00, 0x00 };
    util_copy5_inline_ds(0x2B6D, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C5C(void)
{
    obj_remove_key1();
    copy5_registros(0x3C5F, 0x2B6D);
    z80_ret();
}
#endif

/* 3C66 obj_place_key3 (PC 1000:5FAD): key 3 record 2B72 := 00 00 35 35 13. Caller 5A87. */
void obj_place_key3(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x35, 0x35, 0x13 };
    util_copy5_inline_ds(0x2B72, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C66(void)
{
    obj_place_key3();
    copy5_registros(0x3C69, 0x2B72);
    z80_ret();
}
#endif

/* 3C70 obj_place_glasses (PC 1000:5FB7): glasses record 2B63 := 00 00 1B 23 18. Caller 5A7B. */
void obj_place_glasses(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x1B, 0x23, 0x18 };
    util_copy5_inline_ds(0x2B63, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C70(void)
{
    obj_place_glasses();
    copy5_registros(0x3C73, 0x2B63);
    z80_ret();
}
#endif

/* 3C7A obj_remove_key1_unused (PC 1000:5FC1): (no caller) record 2B6D := 0. */
void obj_remove_key1_unused(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x00, 0x00, 0x00 };
    util_copy5_inline_ds(0x2B6D, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C7A(void)
{
    obj_remove_key1_unused();
    copy5_registros(0x3C7D, 0x2B6D);
    z80_ret();
}
#endif

/* 3C30 obj_book_to_jorge (PC 1000:5F73): obj_severin_objects (2963) := 80h and the book record 2B59 :=
 * 80 00 60 29 00 (held by the Severino holder 2960).  Caller 5ABC. */
void obj_book_to_jorge(void)
{
    static const uint8_t v[5] = { 0x80, 0x00, 0x60, 0x29, 0x00 };   /* 3C3A-3C3E */
    wb(D64_OBJ_SEVERIN_OBJECTS, 0x80);                      /* 3C30-3C34 */
    util_copy5_inline_ds(0x2B59, v);                        /* 3C35 CALL 3C84 <59 2B> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C30(void)
{
    obj_book_to_jorge();
    cpu.a = 0x80;
    copy5_registros(0x3C38, 0x2B59);
    z80_ret();
}
#endif

/* 3C3F obj_place_lamp (PC 1000:5F82): once (obj_lamp_placed 0 -> 1): lamp record 2B81 := 00 00 5A 2A 04
 * (the kitchen).  Caller 5AAA. */
void obj_place_lamp(void)
{
    static const uint8_t v[5] = { 0x00, 0x00, 0x5A, 0x2A, 0x04 };   /* 3C4D-3C51 */
    uint8_t a = rb(D64_OBJ_LAMP_PLACED);                    /* 3C3F */
    if (a) return;                                          /* 3C42-3C43 */
    wb(D64_OBJ_LAMP_PLACED, (uint8_t)(a + 1));              /* 3C44-3C45 */
    util_copy5_inline_ds(0x2B81, v);                        /* 3C48 CALL 3C84 <81 2B> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C3F(void)
{
    uint8_t a = rb(D64_OBJ_LAMP_PLACED);
    obj_place_lamp();
    if (a) cpu.a = a;
    else { cpu.a = 1; copy5_registros(0x3C4B, 0x2B81); }
    z80_ret();
}
CHEQUEO(r_3C3F, R_A)
#endif

/* 3D87 obj_jorge_takes_book (PC 1000:6151): iso_room_dark := 1, vid_clear_play_area (16A1), Guillermo
 * loses the book (bit 7), his slots are redrawn (4D30 hud_draw_objects with A = 80h, C = his objects) and
 * the book record 2B59 := 0 (the copy returns to the caller: the RET at 3DA7 is never reached).  Caller
 * 57C2. */
void obj_jorge_takes_book(void)
{
    uint8_t c;
    uint16_t de;
    wb(D64_ISO_ROOM_DARK, 0x01);                            /* 3D87-3D89 */
    (void)vid_fill_play_area_ff(&de);                       /* 3D8C CALL 16A1 */
    c = (uint8_t)(rb(D64_B2_GUILLERMO_OBJECTS) & 0x7F);     /* 3D8F-3D94 */
    wb(D64_B2_GUILLERMO_OBJECTS, c);
    hud_draw_objects(0x80, c);                              /* 3D97-3D9A CALL 4D30 (A = 80h, C) */
    util_copy5_inline_ds(0x2B59, cinco_ceros);              /* 3D9D CALL 3C84 <59 2B> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D87(void)
{
    obj_jorge_takes_book();
    copy5_registros(0x3DA0, 0x2B59);
    z80_ret();
}
#endif

/* ==== 3C8F-3D3B: the camera ========================================================================== */

/* 3CAE ai_jorge_book_talk_with_gloves (PC 1000:6033): true (CF = 1) when Guillermo has the gloves (bit 6 of
 * his objects) and ai_severin_state is 0Dh, 0Eh or 0Fh (the 64K game has no Jorge: Severino's states).
 * Out: CF. */
bool ai_jorge_book_talk_with_gloves(void)
{
    uint8_t s;
    if (!(rb(D64_B2_GUILLERMO_OBJECTS) & 0x40)) return false;   /* 3CAE-3CB3 */
    s = rb(D64_AI_SEVERIN_STATE);                           /* 3CB4 */
    return s == 0x0D || s == 0x0E || s == 0x0F;             /* 3CB7-3CC4 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3CAE(void)
{
    cpu.cf = ai_jorge_book_talk_with_gloves();
    z80_ret();
}
CHEQUEO(r_3CAE, R_CF)
#endif

/* 3C8F game_idle_camera_check (PC 1000:600F): talk = CF of ai_jorge_book_talk_with_gloves: true ->
 * game_idle_frames := 32h, ai_camera_target := 5 and false (ZF = 1).  Otherwise true (ZF = 0) when one of
 * the movement keys (CPC keys 0, 8, 1) is down (the last test is a JP to sys_key_down).  Out: ZF. */
bool game_idle_camera_check(bool talk)
{
    uint8_t code;
    if (talk) {                                             /* 3C8F JR NC */
        wb(D64_GAME_IDLE_FRAMES, 0x32);                     /* 3C91-3C93 */
        wb(D64_AI_CAMERA_TARGET, 0x05);                     /* 3C96-3C98 */
        return false;                                       /* 3C9B XOR A */
    }
    if (sys_key_down(0x00, &code)) return true;             /* 3C9D-3CA1 */
    if (sys_key_down(0x08, &code)) return true;             /* 3CA2-3CA7 */
    return sys_key_down(0x01, &code) != 0;                  /* 3CA8-3CAA JP 2E8D */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3C8F(void)
{
    bool talk = cpu.cf;
    cpu.zf = !game_idle_camera_check(talk);
    if (talk) cpu.a = 0;
    z80_ret();
}
CHEQUEO(r_3C8F, R_ZF | R_A)
#endif

/* 3D01 game_speed_set (PC 1000:60A8): sys_frame_ticks := ticks.  In: A.  Flags preserved. */
void game_speed_set(uint8_t ticks)
{
    wb(D64_SYS_FRAME_TICKS, ticks);                         /* 3D01 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D01(void)
{
    game_speed_set(cpu.a);
    z80_ret();
}
#endif

/* 3CFE game_speed_default (PC 1000:60A5): sys_frame_ticks := sys_frame_ticks_normal (falls into 3D01).
 * Out: A = the normal ticks; the flags are preserved (game_camera_select relies on it). */
uint8_t game_speed_default(void)
{
    uint8_t t = rb(D64_SYS_FRAME_TICKS_NORMAL);             /* 3CFE */
    game_speed_set(t);
    return t;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3CFE(void)
{
    cpu.a = game_speed_default();
    z80_ret();
}
CHEQUEO(r_3CFE, R_A | R_F)
#endif

/* the tail 3CF6-3D04 of game_camera_select: game_camera_other := c, game_idle_frames := c, and the normal
 * speed when c = 0 (Guillermo) */
static void camera_set(uint8_t c)
{
    wb(D64_GAME_CAMERA_OTHER, c);                           /* 3CF6 */
    wb(D64_GAME_IDLE_FRAMES, c);                            /* 3CF9 */
    if (c == 0) game_speed_default();                       /* 3CFC-3CFD RET NZ, falls into 3CFE */
}

/* 3CC5 game_camera_select (PC 1000:6053): game_update_camera_and_bonus (51E7, a script); a movement key
 * puts the camera back on Guillermo (0); else game_idle_frames counts up to 32h and then: frame delay
 * sys_frame_ticks normal while a phrase is shown, 0 (no delay) otherwise; snd_play_music_if_idle (always,
 * unlike the PC); the camera goes to ai_camera_target when it changed.  No register results. */
void game_camera_select(void)
{
    uint8_t a, c;
    bool talk;
    game_update_camera_and_bonus();                         /* 3CC5 CALL 51E7 */
    talk = ai_jorge_book_talk_with_gloves();                /* 3CC8 */
    if (game_idle_camera_check(talk)) { camera_set(0); return; }   /* 3CCB-3CD0 LD A,0 / JR NZ 3CF6 */
    a = (uint8_t)(rb(D64_GAME_IDLE_FRAMES) + 1);            /* 3CD2-3CD6 */
    wb(D64_GAME_IDLE_FRAMES, a);
    if (a < 0x32) return;                                   /* 3CD9-3CDB */
    wb(D64_GAME_IDLE_FRAMES, (uint8_t)(a - 1));             /* 3CDC-3CDD */
    if (rb(D64_TXT_PHRASE_BUSY)) game_speed_default();      /* 3CE0-3CE4 (flags kept by 3CFE) */
    else game_speed_set(0);                                 /* 3CE7 CALL Z,3D01 with A = 0 */
    snd_play_music_if_idle();                               /* 3CEA CALL 0C77 */
    c = rb(D64_GAME_CAMERA_OTHER);                          /* 3CED-3CF0 */
    a = rb(D64_AI_CAMERA_TARGET);                           /* 3CF1 */
    if (a == c) return;                                     /* 3CF4-3CF5 */
    camera_set(a);                                          /* 3CF6 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3CC5(void)
{
    game_camera_select();
    z80_ret();
}
#endif

/* 3D05 util_return_zero (PC 1000:60AC): XOR A / RET: always A = 0, ZF = 1 (the CPC debug key tests it). */
bool util_return_zero(void)
{
    return true;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D05(void)
{
    cpu.a = 0;
    banderas_logicas(0, 0);
    (void)util_return_zero();
    z80_ret();
}
CHEQUEO(r_3D05, R_A | R_F)
#endif

/* 3D07 game_set_c004_inline (PC 1000:60AF): `CALL 3D07 <db v>`: game_idle_frames := v; returns past the
 * byte.  Out: A = v, HL = the return address. */
void game_set_c004_inline(uint8_t v)
{
    wb(D64_GAME_IDLE_FRAMES, v);                            /* 3D0A */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D07(void)
{
    uint16_t ret = rw(cpu.sp);
    uint8_t v = rb(ret);
    game_set_c004_inline(v);
    cpu.a = v;
    SET_HL((uint16_t)(ret + 1));
    retorna_a((uint16_t)(ret + 1));
}
CHEQUEO(r_3D07, R_A | R_HL)
#endif

/* 3D0F game_camera_from_ch_unused (PC 1000:60B8): (no caller) game_camera_other := b - 1.  In: B.
 * Out: A = b - 1. */
uint8_t game_camera_from_ch_unused(uint8_t b)
{
    uint8_t a = (uint8_t)(b - 1);
    wb(D64_GAME_CAMERA_OTHER, a);                           /* 3D0F-3D11 */
    return a;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D0F(void)
{
    uint8_t a = game_camera_from_ch_unused(cpu.b);
    cpu.a = a;
    cpu.sf = a >> 7; cpu.zf = a == 0; cpu.yf = (a >> 5) & 1; cpu.hf = (a & 0x0F) == 0x0F;
    cpu.xf = (a >> 3) & 1; cpu.pf = a == 0x7F; cpu.nf = 1;
    z80_ret();
}
CHEQUEO(r_3D0F, R_A | R_F)
#endif

/* 3D15 game_camera_update (PC 1000:60C0): once per frame: game_camera_select, then chr_camera_target :=
 * chr_record_ptrs[game_camera_other] (the record of the camera character).  Out: DE = the record,
 * HL = the address of its high byte, A = as util_add_bx_al leaves it. */
uint16_t game_camera_update(uint16_t *hl, uint8_t *a)
{
    uint16_t p, r;
    game_camera_select();                                   /* 3D15 */
    p = util_add_bx_al(D64_CHR_RECORD_PTRS, (uint8_t)(rb(D64_GAME_CAMERA_OTHER) * 2));   /* 3D18-3D1F */
    *a = (uint8_t)(p >> 8);                                 /* 128F leaves A = H */
    r = rw(p);                                              /* 3D22-3D24 */
    ww(D64_CHR_CAMERA_TARGET, r);                           /* 3D25 */
    *hl = (uint16_t)(p + 1);
    return r;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D15(void)
{
    uint16_t hl;
    uint8_t a;
    uint16_t de = game_camera_update(&hl, &a);
    SET_DE(de);
    SET_HL(hl);
    cpu.a = a;
    z80_ret();
}
CHEQUEO(r_3D15, R_A | R_DE | R_HL)
#endif

/* ==== 3D3C-3E28: lamp and night timers, percentage, bonus and poison, the end of the game ========= */

/* 3D3C ai_lamp_tick (PC 1000:60D8): the lamp event for ai_lamp_event (C): its current value, except
 * while Adso has the lamp, it is lit (ai_lamp_in_use) and the room is dark: ai_lamp_time += 1 and, at
 * each multiple of 256 frames when no event is pending, 1 at 300h, 2 at 600h, 0 otherwise.  Out: C. */
uint8_t ai_lamp_tick(void)
{
    uint8_t c = rb(D64_AI_LAMP_EVENT), h;                   /* 3D3C-3D3F */
    uint16_t t;
    if (!(rb(D64_GAME_ADSO_LAMP) & 0x80)) return c;         /* 3D40-3D45 */
    if (!rb(D64_AI_LAMP_IN_USE)) return c;                  /* 3D46-3D4A */
    if (!rb(D64_ISO_ROOM_DARK)) return c;                   /* 3D4B-3D4F */
    t = (uint16_t)(rw(D64_AI_LAMP_TIME) + 1);               /* 3D50-3D54 */
    ww(D64_AI_LAMP_TIME, t);
    if (t & 0xFF) return c;                                 /* 3D57-3D59 */
    if (c) return c;                                        /* 3D5A-3D5C */
    h = (uint8_t)(t >> 8);
    if (h == 3) return 1;                                   /* 3D5D-3D62 */
    if (h == 6) return 2;                                   /* 3D63-3D66 */
    return 0;                                               /* 3D67 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D3C(void)
{
    cpu.c = ai_lamp_tick();
    z80_ret();
}
CHEQUEO(r_3D3C, R_C)
#endif

/* 3D6A ai_night_end_tick (PC 1000:611F): 1 (for ai_night_ending) at NOCHE when ai_hour_frames_left is
 * exactly 0200h, else 0; when the high byte is 0 with the word not 0 and the low byte 0 (unreachable),
 * ai_advance_hour := 1.  Out: C. */
uint8_t ai_night_end_tick(void)
{
    uint16_t t = rw(D64_AI_HOUR_FRAMES_LEFT);               /* 3D6C */
    uint8_t h;
    if (t == 0) return 0;                                   /* 3D6F-3D71 */
    if (t & 0xFF) return 0;                                 /* 3D72-3D74 */
    if (rb(D64_GAME_HOUR)) return 0;                        /* 3D75-3D79 */
    h = (uint8_t)(t >> 8);
    if (h == 2) return 1;                                   /* 3D7A-3D7E */
    if (h) return 0;                                        /* 3D7F-3D81 */
    wb(D64_AI_ADVANCE_HOUR, 1);                             /* 3D82-3D83 */
    return 0;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3D6A(void)
{
    cpu.c = ai_night_end_tick();
    z80_ret();
}
CHEQUEO(r_3D6A, R_C)
#endif

/* 3DA8 game_compute_percentage (PC 1000:6173): when the investigation is solved (game_investigation_open
 * = 0) the text is "100"; else percent = 7*(day-1) + hour + 4 per bit set in the word game_bonus2 (8-bit
 * sum), 0 when below 5; its digits go into the inline text of game_check_end: game_percent_digits (3E61)
 * := ' ', tens, units ('1', '0', '0' when solved).  Out: A = 20h (31h), BC = units << 8 | tens (0),
 * HL = 3030h + BC. */
uint16_t game_compute_percentage(uint8_t *a)
{
    uint8_t d, c, al, tens = 0, units, i, first;
    uint16_t bx;
    if (!rb(D64_GAME_INVESTIGATION_OPEN)) {                 /* 3DA8-3DAC JP Z,3DE7 */
        first = 0x31; units = 0;                            /* 3DE7-3DEA */
    } else {
        d = (uint8_t)(rb(D64_GAME_DAY) - 1);                /* 3DAF-3DB2 */
        c = (uint8_t)(d + d);                               /* 3DB3-3DB5 */
        al = (uint8_t)(c + c + d + c);                      /* 3DB6-3DB9: 7*(day-1) */
        al = (uint8_t)(rb(D64_GAME_HOUR) + al);             /* 3DBA-3DBD */
        bx = rw(D64_GAME_BONUS2);                           /* 3DBE */
        for (i = 0; i < 16; i++) {                          /* 3DC1-3DC8 */
            if (bx & 0x8000) al = (uint8_t)(al + 4);
            bx = (uint16_t)(bx << 1);
        }
        if (al < 5) al = 0;                                 /* 3DCA-3DCE */
        for (;;) {                                          /* 3DCF-3DD8 */
            units = al;
            if (al < 10) break;
            al = (uint8_t)(al - 10);
            tens++;
        }
        first = 0x20;                                       /* 3DDA */
    }
    wb(D64_GAME_PERCENT_DIGITS, first);                     /* 3DE0 */
    wb(D64_GAME_PERCENT_DIGITS + 1, (uint8_t)(0x30 + tens));   /* 3DE3 */
    wb(D64_GAME_PERCENT_DIGITS + 2, (uint8_t)(0x30 + units));
    *a = first;
    return (uint16_t)(units << 8 | tens);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3DA8(void)
{
    uint8_t a;
    uint16_t bc = game_compute_percentage(&a);
    cpu.a = a;
    SET_BC(bc);
    SET_HL((uint16_t)(0x3030 + bc));
    z80_ret();
}
CHEQUEO(r_3DA8, R_A | R_BC | R_HL)
#endif


/* 3DEE game_update_bonus_and_poison (PC 1000:61CC): once per frame: game_bonus2 |= Guillermo's
 * gloves/key 1/key 2 (objects & 4Ch) | Adso's key 3 (& 02h).  While Guillermo holds the book without the
 * gloves, game_book_poison_count += 1; when it wraps to 0 he dies: chr_guillermo_state := Guillermo's
 * sprite byte +2 / 2, chr_guillermo_fall_dy := FEh, game_guillermo_dead := 1 and phrase 22h
 * (hud_say_now, inline at 3E27).  No register results. */
void game_update_bonus_and_poison(void)
{
    uint8_t c = rb(D64_B2_GUILLERMO_OBJECTS), n;            /* 3DEE-3DF1 */
    wb(D64_GAME_BONUS2, (uint8_t)(rb(D64_GAME_BONUS2) | (c & 0x4C) | (rb(D64_OBJ_ADSO_OBJECTS) & 0x02)));   /* 3DF2-3E00 */
    if (!(c & 0x80)) return;                                /* 3E03-3E06 */
    if (c & 0x40) return;                                   /* 3E07-3E09 */
    n = (uint8_t)(rb(D64_GAME_BOOK_POISON_COUNT) + 1);      /* 3E0A-3E0E */
    wb(D64_GAME_BOOK_POISON_COUNT, n);
    if (n) return;                                          /* 3E11 */
    wb(D64_CHR_GUILLERMO_STATE, (uint8_t)(rb(D64_SPR_TABLE + 2) >> 1));   /* 3E12-3E17 */
    wb(D64_CHR_GUILLERMO_FALL_DY, 0xFE);                    /* 3E1A-3E1C */
    wb(D64_GAME_GUILLERMO_DEAD, 1);                         /* 3E1F-3E21 */
    hud_say_now(0x22);                                      /* 3E24 CALL 4B71 <22> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3DEE(void)
{
    game_update_bonus_and_poison();
    z80_ret();
}
#endif

/* 3E29 game_check_end (PC 1000:6215): main-loop step.  Returns at once (0) unless Guillermo is dead
 * (game_guillermo_dead); then the camera goes back to Guillermo (game_camera_other := 80h) and, once no
 * phrase is shown, the end screen: clear the play area (16A1), game_compute_percentage (its digits go into
 * the second text), "HAS RESUELTO EL" at 2010h, " xx  POR CIENTO" at 300Eh, "DE LA INVESTIGACION" at 400Ch,
 * txt_cursor := 8006h; at 100% ("1" in game_percent_digits) JR Z,3EC6: the ending (game_ending, never
 * returns: 2); else "PULSA ESPACIO PARA EMPEZAR", then the wait for the space key (2D50 and CPC key 2Fh
 * each pass; every pass that finds it up is a wait point of the synchronous mode, `pausa 3EB8 3EC0`:
 * plat_pausa) and the new-game point (POP HL / JP 20C7: 1).  Not in the table and stays in Z80 there: in
 * the two last cases it does not return to its caller (it drops its return address); the main loop must
 * restart the game (1) or show the ending (2).  sp = the SP at its entry (for the wait). */
uint8_t game_check_end(uint16_t sp)
{
    uint8_t a, code;
    uint16_t de;
    if (rb(D64_GAME_GUILLERMO_DEAD) == 0) return 0;         /* 3E29-3E2D */
    wb(D64_GAME_CAMERA_OTHER, 0x80);                        /* 3E2E-3E30 */
    if (rb(D64_TXT_PHRASE_BUSY) != 0) return 0;             /* 3E33-3E37 */
    (void)vid_fill_play_area_ff(&de);                       /* 3E38 CALL 16A1 */
    (void)game_compute_percentage(&a);                      /* 3E3B */
    ww(D64_TXT_CURSOR, 0x2010);                             /* 3E3E-3E41 */
    (void)txt_print_inline(0x3E47);                         /* 3E44 "HAS RESUELTO EL" */
    ww(D64_TXT_CURSOR, 0x300E);                             /* 3E57-3E5A */
    (void)txt_print_inline(0x3E60);                         /* 3E5D " xx  POR CIENTO" */
    ww(D64_TXT_CURSOR, 0x400C);                             /* 3E70-3E73 */
    (void)txt_print_inline(0x3E79);                         /* 3E76 "DE LA INVESTIGACION" */
    ww(D64_TXT_CURSOR, 0x8006);                             /* 3E8D-3E90 */
    if (rb(D64_GAME_PERCENT_DIGITS) == 0x31) return 2;     /* 3E93-3E98 JR Z,3EC6 */
    (void)txt_print_inline(0x3E9D);                         /* 3E9A "PULSA ESPACIO PARA EMPEZAR" */
    for (;;) {
        sys_read_keyboard();                                /* 3EB8 */
        if (sys_key_down(0x2F, &code)) break;               /* 3EBB-3EBF */
        plat_pausa(sp);                                     /* 3EC0 JR Z,3EB8: a wait pass */
    }
    return 1;                                               /* 3EC2 POP HL / JP 20C7 */
}

/* 3EC6 game_ending (PC 1000:6295, the ending): "PON EL CASSETTE EN MARCHA" at the cursor (8006h, CALL
 * 4B44 with the text inline), then 31CF: the ending is loaded from the tape (32AB with DE = 2C00h bytes
 * ending at HL = 8BFFh, block 2Ah: 6000h-8BFFh, over the scripts at 6000h) and its code is called
 * again and again (CALL 6000h / JR 31DA).  The tape and the ending program are the platform's
 * (plat_cinta_carga, plat_final): the game never comes back.  sp = the SP of the CALL 32AB's caller
 * (31CF is reached by JP from 3E29's caller, the main loop: SP = its SP - 2). */
void game_ending(uint16_t sp)
{
    (void)txt_print_inline(0x3EC9);                         /* 3EC6 */
    (void)tape_load_block(0x8BFF, 0x2C00, 0x2A, (uint16_t)(sp - 2));   /* 31CF-31D7 */
    for (;;) plat_final();                                  /* 31DA CALL 6000h / JR 31DA */
}

/* 3EE6 ai_stop_hour_countdown (PC 1000:62B8): ai_hour_frames_left := 0 (only the scripts end the moment of
 * the day).  Called by Berengario's script.  Out: HL = 0. */
void ai_stop_hour_countdown(void)
{
    ww(D64_AI_HOUR_FRAMES_LEFT, 0x0000);                    /* 3EE6-3EEC */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3EE6(void)
{
    ai_stop_hour_countdown();
    SET_HL(0);
    z80_ret();
}
CHEQUEO(r_3EE6, R_HL)
#endif

/* ==== 3EEF-3F72: Malaquias rising, Guillermo's place at the ceremonies, the parchment test ======= */

/* 3EEF ai_malaquias_rise (PC 1000:62C0): one step of Malachi rising when he dies: chr_malachi_rise_delay
 * (3EEE) &= 0Fh (return if not 0); chr_malachi_rising (3EED) := 1; his height (2BA9) += 1; at 14h: his x
 * (2BA7) := 0, ai_malachi_dying := 2, ai_malachi_reached := 0.  Caller 52C3. */
void ai_malaquias_rise(void)
{
    uint8_t d = rb(D64_CHR_MALACHI_RISE_DELAY) & 0x0F, h;   /* 3EEF-3EF4 */
    wb(D64_CHR_MALACHI_RISE_DELAY, d);
    if (d) return;                                          /* 3EF7 */
    wb(D64_CHR_MALACHI_RISING, 1);                          /* 3EF8-3EFA */
    h = (uint8_t)(rb(D64_CHR_MALACHI + 4) + 1);             /* 3EFD-3F01 */
    wb(D64_CHR_MALACHI + 4, h);
    if (h < 0x14) return;                                   /* 3F04-3F06 */
    wb(D64_CHR_MALACHI + 2, 0);                             /* 3F07-3F08 */
    wb(D64_AI_MALACHI_DYING, 2);                            /* 3F0B-3F0D */
    wb(D64_AI_MALACHI_REACHED, 0);                          /* 3F10-3F11 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3EEF(void)
{
    ai_malaquias_rise();
    z80_ret();
}
#endif

/* 3F2D ai_check_guillermo_at (PC 1000:630B): is Guillermo at the ground-floor position pos (E = x,
 * D = y)?  0 if his height >= 0Bh or ((x ^ E) | (y ^ D)) >= 10h (another room), 2 if in that room, 1 if
 * exactly there and with orientation 1.  The result goes to ai_guillermo_in_place (37E8).  Out: A = C = the
 * result. */
uint8_t ai_check_guillermo_at(uint16_t pos)
{
    uint8_t r = 0, d;                                       /* 3F2D */
    if (rb(D64_CHR_GUILLERMO + 4) < 0x0B) {                 /* 3F2F-3F34 */
        d = (uint8_t)((rb(D64_CHR_GUILLERMO + 2) ^ (uint8_t)pos) | (rb(D64_CHR_GUILLERMO + 3) ^ (uint8_t)(pos >> 8)));   /* 3F36-3F3F */
        if (d < 0x10) {                                     /* 3F40-3F42 */
            r = 2;                                          /* 3F44 */
            if (d == 0 && rb(D64_CHR_GUILLERMO + 1) == 1) r = 1;   /* 3F46-3F50 */
        }
    }
    wb(D64_AI_GUILLERMO_IN_PLACE, r);                       /* 3F51-3F52 */
    return r;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3F2D(void)
{
    uint8_t r = ai_check_guillermo_at(DE);
    cpu.a = r; cpu.c = r;
    z80_ret();
}
CHEQUEO(r_3F2D, R_A | R_C)
#endif

/* 3F15 ai_check_guillermo_at_mass (PC 1000:62ED): ai_check_guillermo_at(4B84h) (his place in the church)
 * and, if that gives 0, ai_check_guillermo_at(3080h) (tail JR).  Callers 5BD6, 5BF3.  Out: A = C. */
uint8_t ai_check_guillermo_at_mass(void)
{
    uint8_t r = ai_check_guillermo_at(0x4B84);              /* 3F15-3F1C */
    if (r) return r;
    return ai_check_guillermo_at(0x3080);                   /* 3F1D-3F20 JR 3F2D */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3F15(void)
{
    uint8_t r = ai_check_guillermo_at_mass();
    cpu.a = r; cpu.c = r;
    z80_ret();
}
CHEQUEO(r_3F15, R_A | R_C)
#endif

/* 3F22 ai_check_guillermo_at_refectory (PC 1000:62FD): ai_check_guillermo_at(3938h) and, if that gives 0,
 * ai_check_guillermo_at(3020h) (falling into 3F2D).  Caller 5C10.  Out: A = C. */
uint8_t ai_check_guillermo_at_refectory(void)
{
    uint8_t r = ai_check_guillermo_at(0x3938);              /* 3F22-3F29 */
    if (r) return r;
    return ai_check_guillermo_at(0x3020);                   /* 3F2A, falls into 3F2D */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3F22(void)
{
    uint8_t r = ai_check_guillermo_at_refectory();
    cpu.a = r; cpu.c = r;
    z80_ret();
}
CHEQUEO(r_3F22, R_A | R_C)
#endif


/* 3F56 ai_parchment_check (PC 1000:633B): ZF result.  false (NZ) if bit 0 of ai_monk_flags (37F2) is set;
 * true (Z) if Guillermo carries the parchment (bit 4 of his objects); false if somebody holds it (bit 7
 * of its record 2B68); otherwise true when the floor of the parchment's height (2B6C) is the ground floor
 * (iso_floor_base). */
bool ai_parchment_check(void)
{
    if (rb(D64_AI_MONK_FLAGS) & 0x01) return false;                    /* 3F56-3F5B */
    if ((rb(D64_B2_GUILLERMO_OBJECTS) & 0x10) == 0x10) return true;   /* 3F5C-3F63 */
    if (rb(D64_OBJ_OBJECTS + 0x0F) & 0x80) return false;   /* 3F64-3F69 */
    return iso_floor_base(rb(D64_OBJ_OBJECTS + 0x13)) == 0;   /* 3F6A-3F72 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3F56(void)
{
    cpu.zf = ai_parchment_check();
    z80_ret();
}
CHEQUEO(r_3F56, R_ZF)
#endif

/* ==== 3F73-4444: path searches and movement commands ================================================ */
/* a push into the search queue (SP moved into it) */
#ifdef MEDIR_SCRATCH
/* Measurement of the shared scratch region (sprite buffer, mirror buffers, path queue): the lowest
 * path-queue pointer (its call frames reach 6 bytes lower) and the highest sprite-buffer allocation end, over a
 * whole game; printed when the library unloads.  Not part of the game. */
uint16_t medir_vsp_min = 0xFFFF, medir_buf_max = 0, medir_buf_llenos = 0;
uint16_t medir_hw_pasada = 0, medir_hw_max = 0, medir_hw_max_refl = 0, medir_hw_refl = 0, medir_hw_rect_max = 0,
         medir_hw_rect_max_met = 0, medir_hw_rectpool = 0, medir_hw_rectpool_max = 0;
unsigned long medir_hw_met = 0;
unsigned long medir_hw_pasadas_refl = 0, medir_hw_mas[8] = {0};   /* passes over 600, 700, ... 1300 bytes */
#define MEDIR_SPR_GUILLERMO     0x29A4u     /* D64_SPR_GUILLERMO, D64_SPR_ADSO, D64_ISO_MIRROR_BUF_GUILLERMO of */
#define MEDIR_SPR_ADSO          0x29B8u     /* datos_logica_b.h (the reflections and the mirror copies) */
#define MEDIR_MIRROR_BUF        0x855Cu
static int medir_hw_activo(uint16_t rec, int t)
{
    uint16_t g;
    if (rb(rec) >= 0xFE || (rb((uint16_t)(rec + 5)) & 0x80)) return 0;
    if (t < 2) return 1;
    g = rw((uint16_t)(rec + 7));
    return g >= MEDIR_MIRROR_BUF && g < (uint16_t)(MEDIR_MIRROR_BUF + 620);
}
static void medir_hw_rect(uint16_t ix, uint16_t bytes)
{
    static const uint16_t recs[4] = { D64_SPR_TABLE, D64_SPR_TABLE + 0x14, MEDIR_SPR_GUILLERMO, MEDIR_SPR_ADSO };
    uint8_t rx = rb((uint16_t)(ix + 0x0C)), ry = rb((uint16_t)(ix + 0x0D)), rw_ = rb((uint16_t)(ix + 0x0E)), rh = rb((uint16_t)(ix + 0x0F));
    int t, meets = 0;
    for (t = 0; t < 4; t++) {
        uint16_t rec = recs[t];
        uint8_t x, y, w, h;
        if (!medir_hw_activo(rec, t)) continue;
        if (t >= 2) medir_hw_refl = 1;
        x = rb((uint16_t)(rec + 1)); y = rb((uint16_t)(rec + 2)); w = (uint8_t)(rb((uint16_t)(rec + 5)) & 0x7F); h = rb((uint16_t)(rec + 6));
        if (x < rx + rw_ && rx < x + w && y < ry + rh && ry < y + h) meets = 1;
    }
    medir_hw_pasada = (uint16_t)(medir_hw_pasada + bytes / 2 + (meets ? bytes / 2 : 0));
    medir_hw_rectpool = (uint16_t)(medir_hw_rectpool + bytes / 2);
    if (bytes / 2 > medir_hw_rect_max) medir_hw_rect_max = (uint16_t)(bytes / 2);
    if (meets) { medir_hw_met++; if (bytes / 2 > medir_hw_rect_max_met) medir_hw_rect_max_met = (uint16_t)(bytes / 2); }
}
static void medir_hw_fin_pasada(void)
{
    int k;
    if (medir_hw_pasada > medir_hw_max) medir_hw_max = medir_hw_pasada;
    if (medir_hw_refl) { medir_hw_pasadas_refl++; if (medir_hw_pasada > medir_hw_max_refl) medir_hw_max_refl = medir_hw_pasada; }
    for (k = 0; k < 8; k++) if (medir_hw_pasada > 600 + 100 * k) medir_hw_mas[k]++;
    if (medir_hw_rectpool > medir_hw_rectpool_max) medir_hw_rectpool_max = medir_hw_rectpool;
    medir_hw_pasada = 0; medir_hw_rectpool = 0; medir_hw_refl = 0;
}
unsigned long medir_tiles_buf = 0, medir_tiles_sala = 0, medir_mezcla_alin = 0, medir_mezcla_desp = 0, medir_mezcla_esp = 0,
              medir_rect = 0, medir_pasadas = 0;
#define MEDIR_VSP(v) do { if ((v) < medir_vsp_min) medir_vsp_min = (v); } while (0)
__attribute__((destructor)) static void medir_scratch_informe(void)
{
    fprintf(stderr, "MEDIR_SCRATCH path_queue_min=%04X (frames to %04X) spr_buf_max=%04X full_events=%u\n",
            medir_vsp_min, (unsigned)(medir_vsp_min - 6), medir_buf_max, medir_buf_llenos);
    medir_hw_fin_pasada();
    fprintf(stderr, "MEDIR_HW composition_max=%u (C64 rectangles + coverage) max_with_reflections=%u passes_with_reflections=%lu "
            "passes_over_600..1300=%lu,%lu,%lu,%lu,%lu,%lu,%lu,%lu\n", medir_hw_max, medir_hw_max_refl, medir_hw_pasadas_refl,
            medir_hw_mas[0], medir_hw_mas[1], medir_hw_mas[2], medir_hw_mas[3], medir_hw_mas[4], medir_hw_mas[5], medir_hw_mas[6], medir_hw_mas[7]);
    fprintf(stderr, "MEDIR_HW rectangles_only_max=%u (C64 bytes a pass) rectangle_max=%u rectangle_max_meeting=%u rectangles_meeting=%lu\n",
            medir_hw_rectpool_max, medir_hw_rect_max, medir_hw_rect_max_met, medir_hw_met);
    fprintf(stderr, "MEDIR_DIBUJO tiles_in_rectangles=%lu tiles_in_rooms=%lu merge_bytes aligned=%lu shifted=%lu mirrored=%lu "
            "rectangles=%lu spr_draw_passes=%lu\n", medir_tiles_buf, medir_tiles_sala, medir_mezcla_alin, medir_mezcla_desp,
            medir_mezcla_esp, medir_rect, medir_pasadas);
}
#define MEDIR_CUENTA(c) do { (c)++; } while (0)
#define MEDIR_HW_RECT(ix, bytes) medir_hw_rect((ix), (bytes))
#define MEDIR_HW_PASADA() medir_hw_fin_pasada()
#else
#define MEDIR_HW_RECT(ix, bytes) do { } while (0)
#define MEDIR_HW_PASADA() do { } while (0)
#define MEDIR_VSP(v) do { } while (0)
#define MEDIR_CUENTA(c) do { } while (0)
#endif

static void vpush(uint16_t *vsp, uint16_t w)
{
    *vsp = (uint16_t)(*vsp - 2);
    MEDIR_VSP(*vsp);
    ww(*vsp, w);
}

/* 40DE-40E6, the common exit of the searches: chr_path_result := result, SP back from chr_path_saved_sp,
 * EI, RET */
static void path_exit(uint8_t result)
{
    wb(D64_CHR_PATH_RESULT, result);                        /* 40DE */
    plat_ei();                                              /* 40E5 */
}

/* 4080-40BE chr_path_check_square (PC 1000:3AA1), up to 40C2: can a character stand on the 2x2 square whose
 * top-right cell is `cell` (cells cell, cell-1, cell-24, cell-25)?  With c = value & 3Fh (character marks
 * fail) and h = chr_path_height (4085): |h-c| <= 1, and the square flat or a single slope.  Valid:
 * [cell] |= 80h and true (at 40C2 the check-only mode, 40C2 = RET, returns: the callers read bit 7).  Not
 * in the table: in search mode it pushes into its caller's stack (see room_neighbour). */
static bool path_square_ok(uint16_t cell, uint8_t value)
{
    uint8_t c = value & 0x3F, a, b;
    if ((uint8_t)(rb(D64_CHR_PATH_HEIGHT) - c + 1) >= 3) return false;          /* 4080-408A */
    a = (uint8_t)((rb((uint16_t)(cell - 1)) & 0x3F) - c);                      /* 408B-4090 */
    if (a == 0) {                                                               /* 4091 JR Z,40AA */
        b = (uint8_t)((rb((uint16_t)(cell - 0x18)) & 0x3F) - c + 1);           /* 40AA-40B3 */
        if (b >= 3) return false;
    } else {
        b = (uint8_t)(a + 1);                                                   /* 4093-4097 */
        if (b >= 3) return false;
        if ((uint8_t)((rb((uint16_t)(cell - 0x18)) & 0x3F) - c) != 0) return false;   /* 4098-409E */
    }
    if ((uint8_t)((rb((uint16_t)(cell - 0x19)) & 0x3F) - c + 1) != b) return false;  /* 409F-40A7, 40B5-40BD */
    wb(cell, rb(cell) | 0x80);                                                  /* 40BE */
    return true;
}

/* 4077 chr_path_try_neighbour + 40C2-40DD (PC 1000:3A96, 3AA1): one neighbour of the room search, CALLed
 * from ret - 3 with SP = *vsp, IX = cell, A = back, DE = pos: chr_path_orientation := back; a visited cell
 * (bit 7) is skipped, else the square check; a valid square with 40C2 = RET just returns; in search mode
 * (NOP) bit 7 is cleared again and bit 6 (the target) ends the search (true: chr_path_result := FFh, SP back
 * from chr_path_saved_sp), else bit 7 is set again and pos is queued (POP BC / PUSH DE / PUSH BC / RET: pos
 * in the slot of the return address, SP one word lower).  Not in the table: it moves SP. */
static bool room_neighbour(uint16_t cell, uint8_t back, uint16_t pos, uint16_t ret, uint16_t *vsp)
{
    ww((uint16_t)(*vsp - 2), ret);                          /* CALL 4077 */
    wb(D64_CHR_PATH_ORIENTATION, back);                     /* 407A */
    if (rb(cell) & 0x80) return false;                      /* 407D-407F */
    if (!path_square_ok(cell, rb(cell))) return false;
    if (rb(D64_CHR_PATH_SMC_RET) == 0xC9) return false;    /* 40C2 RET */
    wb(cell, rb(cell) & 0x7F);                              /* 40C3 */
    if (rb(cell) & 0x40) {                                  /* 40C7-40CE: the target */
        path_exit(0xFF);                                    /* 40D8-40DE */
        return true;
    }
    wb(cell, rb(cell) | 0x80);                              /* 40D0 */
    ww((uint16_t)(*vsp - 2), pos);                          /* 40D4-40D7 */
    ww((uint16_t)(*vsp - 4), ret);
    *vsp = (uint16_t)(*vsp - 2);
    MEDIR_VSP(*vsp);
    return false;
}

/* 3FD3-4076 (PC 1000:39CA): the room search proper: marks the border of the height buffer with bit 7,
 * chr_path_saved_sp := sp (the SP at the search's entry), SP := 877Eh (the queue), chr_path_length := 1,
 * queues the origin (marked visited; the CALL 0944's return address is overwritten by the FFFFh separator
 * that follows), and expands the queue words in order: a separator (bit 7 of x) ends a level (queued again,
 * chr_path_length + 1) or the search (the queue is empty: result 00); a cell sets chr_path_height and tries
 * its neighbours x+1, y-1, x-1, y+1 (back orientations 2, 3, 0, 1).  Every exit goes through 40DE: SP back,
 * EI, RET.  Returns HL: the queue word being expanded at the hit, or the separator that ended it. */
static uint16_t room_bfs(uint16_t sp)
{
    uint16_t buf = rw(D64_CHR_HBUF_PTR), top = buf, bottom = (uint16_t)(buf + 0x228), left = buf;
    uint16_t vsp, p, w, cell, idx, lo;
    uint8_t i, x, y;
    for (i = 0; i < 0x18; i++) {                            /* 3FD3-3FFA */
        wb(top, rb(top) | 0x80);
        wb(left, rb(left) | 0x80);
        wb((uint16_t)(left + 0x17), rb((uint16_t)(left + 0x17)) | 0x80);
        wb(bottom, rb(bottom) | 0x80);
        left = (uint16_t)(left + 0x18);
        bottom = (uint16_t)(bottom + 1);
        top = (uint16_t)(top + 1);
    }
    ww(D64_CHR_PATH_SAVED_SP, sp);                          /* 3FFC */
    vsp = D64_PATH_QUEUE;                                   /* 4000 LD SP,877Eh */
    wb(D64_CHR_PATH_LENGTH, 1);                             /* 4003-4005 */
    w = rw(D64_CHR_PATH_ORIGIN);                            /* 4008 */
    vpush(&vsp, w);                                         /* 400C */
    ww((uint16_t)(vsp - 2), 0x4011);                        /* 400E CALL 0944 */
    cell = iso_grid_cell_ptr((uint8_t)w, (uint8_t)(w >> 8), &idx, &lo);
    wb(cell, rb(cell) | 0x80);                              /* 4011 */
    vpush(&vsp, 0xFFFF);                                    /* 4015-4018 */
    p = D64_PATH_QUEUE;                                     /* 4019 */
    for (;;) {
        p = (uint16_t)(p - 2);                              /* 401C-401F */
        w = rw(p);
        if (w & 0x80) {                                     /* 4020-4023: a separator */
            if (p == vsp) {                                 /* 4025-402C SBC HL,SP */
                path_exit(0);
                return p;
            }
            vpush(&vsp, w);                                 /* 402F */
            wb(D64_CHR_PATH_LENGTH, (uint8_t)(rb(D64_CHR_PATH_LENGTH) + 1));   /* 4030-4034 */
            continue;
        }
        ww((uint16_t)(vsp - 2), p);                         /* 4039 PUSH HL */
        ww((uint16_t)(vsp - 4), w);                         /* 403A PUSH DE */
        ww((uint16_t)(vsp - 6), 0x403F);                    /* 403C CALL 0944 */
        cell = iso_grid_cell_ptr((uint8_t)w, (uint8_t)(w >> 8), &idx, &lo);
        wb(D64_CHR_PATH_HEIGHT, rb(cell) & 0x0F);           /* 4041-4046 */
        x = (uint8_t)w; y = (uint8_t)(w >> 8);
        cell = (uint16_t)(cell + 1); x++;                   /* 4049-404D */
        if (room_neighbour(cell, 2, (uint16_t)(y << 8 | x), 0x4051, &vsp)) return p;
        cell = (uint16_t)(cell - 0x19); x--; y--;           /* 4051-4059 */
        if (room_neighbour(cell, 3, (uint16_t)(y << 8 | x), 0x405D, &vsp)) return p;
        cell = (uint16_t)(cell + 0x17); y++; x--;           /* 405D-4065 */
        if (room_neighbour(cell, 0, (uint16_t)(y << 8 | x), 0x4069, &vsp)) return p;
        cell = (uint16_t)(cell + 0x19); y++; x++;           /* 4069-4071 */
        if (room_neighbour(cell, 1, (uint16_t)(y << 8 | x), 0x4075, &vsp)) return p;
    }
}

/* 3F92 chr_path_room_to_marked (PC 1000:397E): room search with no target check: marks the cell of
 * chr_path_dest with bit 6 and runs the search (callers may have marked more cells).  sp = SP at entry.
 * Out: HL (see room_bfs), A = chr_path_result; EI. */
uint16_t chr_path_room_to_marked(uint16_t sp)
{
    uint16_t idx, lo, w = rw(D64_CHR_PATH_DEST);            /* 3F92 */
    uint16_t cell = iso_grid_cell_ptr((uint8_t)w, (uint8_t)(w >> 8), &idx, &lo);
    wb(cell, rb(cell) | 0x40);                              /* 3F98 */
    return room_bfs(sp);                                    /* 3F9C JR 3FD3 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3F92(void)
{
    SET_HL(chr_path_room_to_marked(cpu.sp));
    cpu.a = rb(D64_CHR_PATH_RESULT);
    z80_ret();
}
CHEQUEO(r_3F92, R_HL | R_A)
#endif

/* 3F9E chr_path_room_search (PC 1000:398C): room search to chr_path_dest: chr_path_saved_sp := sp; the
 * target must have height < 0Eh and be a valid square (path_square_ok with 40C2 = RET), then it gets bit 6
 * and the search runs.  The early exits (result 00) return the HL that iso_grid_cell_ptr left for the
 * target.  Out: HL, A = chr_path_result; EI. */
uint16_t chr_path_room_search(uint16_t sp)
{
    uint16_t idx, lo, w = rw(D64_CHR_PATH_DEST);            /* 3F9E */
    uint16_t cell = iso_grid_cell_ptr((uint8_t)w, (uint8_t)(w >> 8), &idx, &lo);
    uint8_t h;
    ww(D64_CHR_PATH_SAVED_SP, sp);                          /* 3FA4 */
    h = rb(cell) & 0x0F;                                    /* 3FA8-3FAD */
    wb(D64_CHR_PATH_HEIGHT, h);
    if (h >= 0x0E) {                                        /* 3FB1-3FB5 */
        path_exit(0);
        return lo;
    }
    wb(D64_CHR_PATH_SMC_RET, 0xC9);                         /* 3FB8-3FBA */
    (void)path_square_ok(cell, h);                          /* 3FBD */
    wb(D64_CHR_PATH_SMC_RET, 0x00);                         /* 3FC0-3FC1 */
    if (!(rb(cell) & 0x80)) {                               /* 3FC4-3FC8 */
        path_exit(0);
        return lo;
    }
    wb(cell, (uint8_t)((rb(cell) & 0x7F) | 0x40));          /* 3FCB-3FCF */
    return room_bfs(sp);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_3F9E(void)
{
    SET_HL(chr_path_room_search(cpu.sp));
    cpu.a = rb(D64_CHR_PATH_RESULT);
    z80_ret();
}
CHEQUEO(r_3F9E, R_HL | R_A)
#endif

/* 441E chr_path_floor_cell_ptr (PC 1000:3F5B): the cell of screen (x = L, y = H) in the floor map:
 * chr_path_room_links_ptr + ((y << 4 | x) & FFh).  Out: IX, DE = the index (D = 0), A = its low byte. */
uint16_t chr_path_floor_cell_ptr(uint16_t xy)
{
    uint8_t idx = (uint8_t)(((uint8_t)(xy >> 8) << 4) | (uint8_t)xy);   /* 441E-4423 */
    return (uint16_t)(rw(D64_CHR_PATH_ROOM_LINKS_PTR) + idx);           /* 4424-442B */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_441E(void)
{
    uint8_t idx = (uint8_t)((cpu.h << 4) | cpu.l);
    cpu.ix = chr_path_floor_cell_ptr(HL);
    SET_DE(idx);
    cpu.a = idx;
    z80_ret();
}
CHEQUEO(r_441E, R_IX | R_DE | R_A)
#endif

/* 4404 chr_path_floor_try_neighbour (PC 1000:3F3B): one neighbour of the floor search, CALLed from ret - 3
 * with SP = *vsp, IX = cell, C = the side mask, B = back, DE = pos: blocked if [cell] & mask (no passage);
 * the target (the bit that the self-modified BIT n,(IX+0) at 440A tests: its opcode byte
 * D64_CHR_PATH_FLOOR_TARGET_TEST, bit 6 = a marked cell, or bit 4 / 5 = stairs up / down when
 * chr_path_find looks for the nearest stairs): the search ends (40D8: chr_path_orientation := back,
 * chr_path_result := FFh, true); visited (bit 7): skipped; else bit 7 is set and pos is queued (as
 * room_neighbour).  Not in the table: it moves SP. */
static bool floor_neighbour(uint16_t cell, uint8_t mask, uint8_t back, uint16_t pos, uint16_t ret, uint16_t *vsp)
{
    uint8_t target = (uint8_t)(1u << ((rb(D64_CHR_PATH_FLOOR_TARGET_TEST) >> 3) & 7));
    ww((uint16_t)(*vsp - 2), ret);                          /* CALL 4404 */
    if (rb(cell) & mask) return false;                      /* 4404-4408 */
    if (rb(cell) & target) {                                /* 440A-440E JP NZ,40D8 */
        wb(D64_CHR_PATH_ORIENTATION, back);
        path_exit(0xFF);
        return true;
    }
    if (rb(cell) & 0x80) return false;                      /* 4411-4415 */
    wb(cell, rb(cell) | 0x80);                              /* 4416 */
    ww((uint16_t)(*vsp - 2), pos);                          /* 441A-441D */
    ww((uint16_t)(*vsp - 4), ret);
    *vsp = (uint16_t)(*vsp - 2);
    MEDIR_VSP(*vsp);
    return false;
}

/* 4399 chr_path_floor_search (PC 1000:3EBD): the search between the screens of a floor (map
 * chr_path_room_links_ptr, cell = y*16 + x) from chr_path_origin, with the queue 877Eh:
 * chr_path_saved_sp := sp; neighbours x+1, y-1, x-1, y+1 with side masks 04, 08, 01, 02 and back
 * orientations 2, 3, 0, 1 (43C7, listed as ai_malachi_think, is a label of this loop); the target test
 * is floor_neighbour's.  chr_path_find enters here (CALL 4399) with the test on the stairs bits;
 * chr_path_floor_to_screen falls into it.  Out: chr_path_result (FFh found / 00), chr_path_orientation;
 * HL as room_bfs; *found = DE: the screen reached (y << 8 | x) on a hit, the separator word that ended an
 * empty queue otherwise; EI. */
uint16_t chr_path_floor_search(uint16_t sp, uint16_t *found)
{
    uint16_t vsp, p, w, cell;
    uint8_t x, y;
    ww(D64_CHR_PATH_SAVED_SP, sp);                          /* 4399 */
    vsp = D64_PATH_QUEUE;                                   /* 439D */
    w = rw(D64_CHR_PATH_ORIGIN);                            /* 43A0 */
    vpush(&vsp, w);                                         /* 43A4 */
    ww((uint16_t)(vsp - 2), 0x43A9);                        /* 43A6 CALL 441E */
    cell = chr_path_floor_cell_ptr(w);
    wb(cell, rb(cell) | 0x80);                              /* 43A9 */
    vpush(&vsp, 0xFFFF);                                    /* 43AD-43B0 */
    p = D64_PATH_QUEUE;                                     /* 43B1 */
    for (;;) {
        p = (uint16_t)(p - 2);                              /* 43B4-43B7 */
        w = rw(p);
        if (w & 0x80) {                                     /* 43B8-43BB */
            if (p == vsp) {                                 /* 43BD-43C4 */
                *found = w;
                path_exit(0);
                return p;
            }
            vpush(&vsp, w);                                 /* 43C7 */
            continue;
        }
        ww((uint16_t)(vsp - 2), p);                         /* 43CA PUSH HL */
        ww((uint16_t)(vsp - 4), w);                         /* 43CB PUSH DE */
        ww((uint16_t)(vsp - 6), 0x43D0);                    /* 43CD CALL 441E */
        cell = chr_path_floor_cell_ptr(w);
        x = (uint8_t)w; y = (uint8_t)(w >> 8);
        cell = (uint16_t)(cell + 1); x++;                   /* 43D2-43D8 */
        *found = (uint16_t)(y << 8 | x);
        if (floor_neighbour(cell, 0x04, 2, *found, 0x43DB, &vsp)) return p;
        cell = (uint16_t)(cell - 0x11); x--; y--;           /* 43DB-43E5 */
        *found = (uint16_t)(y << 8 | x);
        if (floor_neighbour(cell, 0x08, 3, *found, 0x43E8, &vsp)) return p;
        cell = (uint16_t)(cell + 0x0F); y++; x--;           /* 43E8-43F2 */
        *found = (uint16_t)(y << 8 | x);
        if (floor_neighbour(cell, 0x01, 0, *found, 0x43F5, &vsp)) return p;
        cell = (uint16_t)(cell + 0x11); y++; x++;           /* 43F5-43FF */
        *found = (uint16_t)(y << 8 | x);
        if (floor_neighbour(cell, 0x02, 1, *found, 0x4402, &vsp)) return p;
    }
}

/* 438F chr_path_floor_to_screen (PC 1000:3EB1): marks screen chr_path_dest in the floor map with bit 6,
 * then falls into chr_path_floor_search (4399).  Out: as chr_path_floor_search (DE dropped). */
uint16_t chr_path_floor_to_screen(uint16_t sp)
{
    uint16_t cell, found;
    cell = chr_path_floor_cell_ptr(rw(D64_CHR_PATH_DEST));  /* 438F-4392 */
    wb(cell, rb(cell) | 0x40);                              /* 4395 */
    return chr_path_floor_search(sp, &found);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4399(void)
{
    uint16_t found;
    SET_HL(chr_path_floor_search(cpu.sp, &found));
    SET_DE(found);
    cpu.a = rb(D64_CHR_PATH_RESULT);
    z80_ret();
}
CHEQUEO(r_4399, R_HL | R_DE | R_A)

static void w_438F(void)
{
    SET_HL(chr_path_floor_to_screen(cpu.sp));
    cpu.a = rb(D64_CHR_PATH_RESULT);
    z80_ret();
}
CHEQUEO(r_438F, R_HL | R_A)
#endif

/* 432C chr_cmd_write_turn (PC 1000:3E43): turn command from orientation cur to new_orient: d = cur -
 * new_orient, if negative (-d) XOR 2 (0 -> 2); writes chr_cmd_turn_len[d] bits of the word
 * chr_cmd_turn_bits[d] (high byte first) with chr_cmd_write_bits.  In: A = cur, C = new_orient, IY = chr.
 * Out: C = d, and A, B, DE, HL as chr_cmd_write_bits leaves them: *a and *hl here, which the callers pass
 * on to chr_probe_ahead (its fallbacks off the floor shown); *de = p + 1 (the EX DE,HL of 434A) or the
 * address of the last command byte stored. */
static uint8_t write_turn(uint16_t chr, uint8_t cur, uint8_t new_orient, uint8_t *a, uint16_t *hl, uint16_t *de)
{
    uint8_t d = (uint8_t)(cur - new_orient), n, idx0;
    uint16_t p;
    bool carry;
    if (cur < new_orient) {                                 /* 432C-432D JR NC */
        d = (uint8_t)((uint8_t)-d ^ 2);                     /* 432F-4331 */
        if (d == 0) d = 2;                                  /* 4333-4335 */
    }
    p = util_add_bx_al(D64_CHR_CMD_TURN_LEN, d);            /* 4338-433B */
    n = rb(p);                                              /* 433E */
    p = util_add_bx_al(D64_CHR_CMD_TURN_BITS, (uint8_t)(d * 2));   /* 433F-4344 */
    *de = (uint16_t)(p + 1);                                /* 4347-434A: EX DE,HL */
    *hl = (uint16_t)(rb(p) << 8 | rb((uint16_t)(p + 1)));
    idx0 = rb((uint16_t)(chr + 0x0B));
    *a = chr_cmd_write_bits(chr, hl, n, &carry);            /* 434B */
    if (rb((uint16_t)(chr + 0x0B)) != idx0)
        *de = (uint16_t)(rw((uint16_t)(chr + 0x0C)) + (uint8_t)(rb((uint16_t)(chr + 0x0B)) - 1));
    return d;
}

uint8_t chr_cmd_write_turn(uint16_t chr, uint8_t cur, uint8_t new_orient)
{
    uint8_t a;
    uint16_t hl, de;
    return write_turn(chr, cur, new_orient, &a, &hl, &de);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_432C(void)
{
    uint8_t a;
    uint16_t hl, de;
    cpu.c = write_turn(cpu.iy, cpu.a, cpu.c, &a, &hl, &de);
    cpu.a = a;
    cpu.b = 0;
    SET_DE(de);
    SET_HL(hl);
    z80_ret();
}
CHEQUEO(r_432C, R_A | R_BC | R_DE | R_HL)
#endif

/* 4292 chr_cmd_write_step (PC 1000:3CE3): command for one step and the simulated move.  a, c = heights of
 * the two cells ahead (from chr_probe_ahead), step = the (dx, dy) entry chr_apply_step adds.  +5 bit 4
 * cleared.  1-cell character (+5 bit 7): turned on the slope (bit 5): plain step (table 3F83); else
 * height+1, and unless a = 1 (going up) table 3F89, +5 bit 4 (going down) and height-2; a = c: becomes a
 * 4-cell character (table entry + 3, +5 &= 10h, one or two advances: two when chr_orientation_parity gives
 * ZF); else one advance.  4-cell character: a = 1 climbs (height+1, +5 = 80h, table 3F86), a = FFh descends
 * (height-1, +5 = 90h, 3F8C), both becoming 1-cell (one or two advances: two when not ZF); else one advance
 * (3F8F).  Then the 3 bytes of the table entry (bits high, bits low, count) go to chr_cmd_write_bits.  The
 * table pointer is kept in the shadow HL (EXX; 42FA, listed as game_update_camera_and_bonus, is one of
 * those EXX).  Out: HL = step after the advances; *a_out = the A chr_cmd_write_bits leaves; BC, DE
 * preserved (chr_cmd_write_bits runs in the shadow bank). */
static uint16_t write_step(uint16_t chr, uint8_t a, uint8_t c, uint16_t step, uint8_t *a_out)
{
    uint16_t c4 = (uint16_t)(chr + 4), c5 = (uint16_t)(chr + 5), tbl, hl = step, bits;
    uint8_t f;
    bool carry;
    wb(c5, rb(c5) & 0xEF);                                  /* 4292 */
    if (rb(c5) & 0x80) {                                    /* 4296: 1-cell character */
        if (rb(c5) & 0x20) {                                /* 429C */
            tbl = D64_CHR_CMD_STEP_TABLE;                   /* 42A2-42A7 JP 431D */
            hl = apply_step(chr, hl);
            goto write;
        }
        wb(c4, (uint8_t)(rb(c4) + 1));                      /* 42AA */
        tbl = D64_CHR_CMD_STEP_TABLE;                       /* 42AD */
        if (a != 1) {                                       /* 42B2 */
            tbl = D64_CHR_CMD_STEP_TABLE + 6;               /* 42B6 */
            wb(c4, (uint8_t)(rb(c4) - 1));                  /* 42BB */
            wb(c5, rb(c5) | 0x10);                          /* 42BE */
            wb(c4, (uint8_t)(rb(c4) - 1));                  /* 42C2 */
        }
        if (a == c) {                                       /* 42C5: becomes a 4-cell character */
            tbl = (uint16_t)(tbl + 3);                      /* 42C8 */
            wb(c5, rb(c5) & 0x10);                          /* 42CD-42D2 */
            (void)apply_step(chr, hl);                      /* 42D5-42D9 (HL kept) */
            if (chr_orientation_parity(chr) == 0) hl = apply_step(chr, hl);   /* 42DA-42DD CALL Z */
            goto write;
        }
    } else {                                                /* 42E2: 4-cell character */
        if (a == 1) {
            wb(c4, (uint8_t)(rb(c4) + 1));                  /* 42F1 */
            f = 0x80; tbl = D64_CHR_CMD_STEP_TABLE + 3;
        } else if (a == 0xFF) {
            wb(c4, (uint8_t)(rb(c4) - 1));                  /* 42FD */
            f = 0x90; tbl = D64_CHR_CMD_STEP_TABLE + 9;
        } else {
            tbl = D64_CHR_CMD_STEP_TABLE + 12;              /* 42EA */
            goto advance;
        }
        wb(c5, f);                                          /* 4307 */
        (void)apply_step(chr, hl);                          /* 430A-430E (HL kept) */
        if (chr_orientation_parity(chr) != 0) hl = apply_step(chr, hl);  /* 430F-4312 CALL NZ */
        goto write;
    }
advance:
    hl = apply_step(chr, hl);                               /* 4317-431D */
write:
    bits = (uint16_t)(rb(tbl) << 8 | rb((uint16_t)(tbl + 1)));   /* 4320-4326, in the shadow bank */
    *a_out = chr_cmd_write_bits(chr, &bits, rb((uint16_t)(tbl + 2)), &carry);   /* 4327 */
    return hl;
}

uint16_t chr_cmd_write_step(uint16_t chr, uint8_t a, uint8_t c, uint16_t step)
{
    uint8_t a_out;
    return write_step(chr, a, c, step, &a_out);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4292(void)
{
    uint8_t a;
    uint16_t hl = write_step(cpu.iy, cpu.a, cpu.c, HL, &a);
    cpu.a = a;
    SET_HL(hl);
    z80_ret();
}
CHEQUEO(r_4292, R_A | R_BC | R_DE | R_HL)
#endif

/* 41B8 chr_cmd_turn_and_step (PC 1000:3BE9): generator for one step (chr_cmd_generator): the new
 * orientation into +1 (a turn command if it changed), the heights ahead (chr_probe_ahead) and one step
 * command.  In: C = orientation, HL (reaches chr_probe_ahead when no turn is written), IY = chr.
 * Out: A as chr_cmd_write_bits leaves it (returned). */
static uint8_t turn_and_step(uint16_t chr, uint8_t orient, uint16_t hl)
{
    uint8_t a = rb((uint16_t)(chr + 1)), c = orient;        /* 41B8 */
    uint16_t de;
    wb((uint16_t)(chr + 1), orient);                        /* 41BB */
    if (a != orient) c = write_turn(chr, a, orient, &a, &hl, &de);   /* 41BE-41BF */
    a = chr_probe_ahead(chr, a, &c, &hl);                   /* 41C2 */
    (void)write_step(chr, a, c, hl, &a);                    /* 41C5 */
    return a;
}

void chr_cmd_turn_and_step(uint16_t chr, uint8_t orient, uint16_t hl)
{
    (void)turn_and_step(chr, orient, hl);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_41B8(void)
{
    cpu.a = turn_and_step(cpu.iy, cpu.c, HL);
    z80_ret();
}
CHEQUEO(r_41B8, R_A)
#endif

/* 41C9 chr_cmd_write_path (PC 1000:3BFD): default generator: rebuilds the path found by the room search and
 * writes its commands.  chr_path_saved_sp := sp; DI; sys_ticks := FFh (the main loop does not wait).  With
 * SP = chr_path_solution (the operand 41D4, the queue word that reached the target, stored by the callers)
 * it walks the queue towards older entries (POPs: reads only) and writes 3-byte records (x, y, orientation)
 * at spr_buffer 7F80h after an FFh: the target with chr_path_orientation XOR 2, then for each earlier level
 * the first queued cell next to the current one along one axis (chr_path_dy_tmp 4211, chr_path_candidate
 * 422C), until chr_path_origin.  Then SP back, EI, and from the last record back to the FFh: turn (a turn of
 * a 1-cell character to the other axis toggles +5 bit 5), chr_cmd_write_turn, chr_probe_ahead and
 * chr_cmd_write_step; records whose position the simulated character already skipped are passed by.  HL
 * reaching chr_probe_ahead: the last record's address for the first step, 0 for the next ones (or the turn's
 * HL).  In: IY = chr.  Out: IX = the FFh record (A = FFh). */
uint16_t chr_cmd_write_path(uint16_t chr, uint16_t sp)
{
    uint16_t vsp, de, bc, p, ix, hl;
    uint8_t a, b, c, k;
    ww(D64_CHR_PATH_SAVED_SP, sp);                          /* 41C9 */
    plat_di();                                              /* 41CD */
    wb(D64_SYS_TICKS, 0xFF);                                /* 41CE-41D0 */
    vsp = rw(D64_CHR_PATH_SOLUTION);                        /* 41D3 LD SP,nn */
    de = rw(vsp); vsp = (uint16_t)(vsp + 2);                /* 41D6 POP DE */
    p = D64_SPR_BUFFER;                                     /* 41D7 */
    wb(p, 0xFF);
    bc = rw(D64_CHR_PATH_DEST);                             /* 41DD */
    p++; wb(p, (uint8_t)bc);
    p++; wb(p, (uint8_t)(bc >> 8));
    p++; wb(p, rb(D64_CHR_PATH_ORIENTATION) ^ 2);           /* 41E5-41EA */
    if (rb(D64_CHR_PATH_LENGTH) != 1) {                     /* 41EB-41F0 */
        for (;;) {
            do { bc = rw(vsp); vsp = (uint16_t)(vsp + 2); } while (!(bc & 0x8000));   /* 41F2-41F6 */
            p++; wb(p, (uint8_t)de);                        /* 41F8-41FB */
            p++; wb(p, (uint8_t)(de >> 8));
            for (;;) {
                bc = rw(vsp); vsp = (uint16_t)(vsp + 2);    /* 41FC POP BC */
                a = (uint8_t)((uint8_t)(bc >> 8) - (uint8_t)(de >> 8) + 1);   /* 41FD-4202 */
                if (a >= 3) continue;
                wb(D64_CHR_PATH_DY_TMP, a);                 /* 4204 */
                a = (uint8_t)((uint8_t)bc - (uint8_t)de + 1);   /* 4207-420C */
                if (a >= 3) continue;
                k = (uint8_t)(a * 4 + rb(D64_CHR_PATH_DY_TMP));   /* 420E-4210 */
                ww(D64_CHR_PATH_CANDIDATE, bc);             /* 4212 */
                if (k == 1) b = 0;                          /* 4216-4229 */
                else if (k == 6) b = 1;
                else if (k == 9) b = 2;
                else if (k == 4) b = 3;
                else continue;
                break;
            }
            de = rw(D64_CHR_PATH_CANDIDATE);                /* 422B */
            p++; wb(p, b);                                  /* 422E */
            if (rb(D64_CHR_PATH_ORIGIN) == (uint8_t)de && rb(D64_CHR_PATH_ORIGIN + 1) == (uint8_t)(de >> 8)) break;   /* 422F-423A */
        }
    }
    plat_ei();                                              /* 423C-4240 SP back, EI */
    ix = p;                                                 /* 4241-4242 */
    hl = p;
    for (;;) {
        b = rb((uint16_t)(chr + 1));                        /* 4244 */
        c = rb(ix);                                         /* 4247 */
        if ((rb((uint16_t)(chr + 5)) & 0x80) && ((b ^ c) & 1))   /* 424A-4254 */
            wb((uint16_t)(chr + 5), rb((uint16_t)(chr + 5)) ^ 0x20);   /* 4256-425B */
        wb((uint16_t)(chr + 1), c);                         /* 425F */
        a = b;                                              /* 425E */
        if (b != c) c = write_turn(chr, b, c, &a, &hl, &de);   /* 4262-4263 */
        a = chr_probe_ahead(chr, a, &c, &hl);               /* 4266-4268 (IX pushed) */
        (void)write_step(chr, a, c, hl, &a);                /* 426B */
        for (;;) {
            ix = (uint16_t)(ix - 3);                        /* 4270-4274 */
            if (rb(ix) == 0xFF) return ix;                  /* 4276-427B */
            hl = (uint16_t)(rb((uint16_t)(chr + 3)) << 8 | rb((uint16_t)(chr + 2)));   /* 427C-4281 */
            (void)chr_to_hbuf_coords(&hl);                  /* 4282 */
            de = (uint16_t)(rb((uint16_t)(ix + 2)) << 8 | rb((uint16_t)(ix + 1)));   /* 4285-4288 */
            hl = (uint16_t)(hl - de);                       /* 428B-428C AND A / SBC HL,DE */
            if (hl == 0) break;                             /* 428E JR Z,4244 */
        }
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_41C9(void)
{
    cpu.ix = chr_cmd_write_path(cpu.iy, cpu.sp);
    cpu.a = 0xFF;
    z80_ret();
}
CHEQUEO(r_41C9, R_A | R_IX)
#endif

/* 434F chr_cmd_generate (PC 1000:3E6E): generates a character's movement commands: saves its position
 * (+2, +3), orientation (+1), height (+4) and +5, empties its command buffer (+9 = +0Bh = 0), calls the
 * generator in chr_cmd_generator (436A: 41C9 the path found, or 41B8 one step) with SP = sp - 8 (after
 * PUSH DE, PUSH DE, PUSH AF and the CALL), puts +5 back, writes the end command 1000h (12 bits) and
 * restores the rest (+9 = +0Bh = 0).  In: IY = chr, C = orientation and HL for the 41B8 generator.
 * Out: HL = the saved x, y. */
void chr_cmd_generate(uint16_t chr, uint8_t orient, uint16_t hl, uint16_t sp)
{
    uint8_t x = rb((uint16_t)(chr + 2)), y = rb((uint16_t)(chr + 3));   /* 434F-4355 */
    uint8_t o = rb((uint16_t)(chr + 1)), h = rb((uint16_t)(chr + 4));   /* 4356-435C */
    uint8_t f5;
    uint16_t g, bits = 0x1000;
    bool carry;
    wb((uint16_t)(chr + 9), 0);                             /* 435D-4364 */
    wb((uint16_t)(chr + 0x0B), 0);
    f5 = rb((uint16_t)(chr + 5));                           /* 4365-4368 */
    g = rw(D64_CHR_CMD_GENERATOR);                          /* 4369 CALL nn */
    if (g == 0x41B8) chr_cmd_turn_and_step(chr, orient, hl);
    else if (g == 0x41C9) (void)chr_cmd_write_path(chr, (uint16_t)(sp - 8));
    /* never another one: the generators are 41C9 and 41B8 */
    wb((uint16_t)(chr + 5), f5);                            /* 436C-436D */
    (void)chr_cmd_write_bits(chr, &bits, 0x0C, &carry);     /* 4370-4375 */
    wb((uint16_t)(chr + 4), h);                             /* 4378-437C */
    wb((uint16_t)(chr + 1), o);
    wb((uint16_t)(chr + 2), x);                             /* 437F-4383 */
    wb((uint16_t)(chr + 3), y);
    wb((uint16_t)(chr + 9), 0);                             /* 4386-438A */
    wb((uint16_t)(chr + 0x0B), 0);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_434F(void)
{
    uint16_t xy = (uint16_t)(rb((uint16_t)(cpu.iy + 3)) << 8 | rb((uint16_t)(cpu.iy + 2)));
    chr_cmd_generate(cpu.iy, cpu.c, HL, cpu.sp);
    SET_HL(xy);
    z80_ret();
}
CHEQUEO(r_434F, R_HL)
#endif

/* 41A8 chr_cmd_write_one_step (PC 1000:3BD7): one step of the character chr in orientation orient:
 * chr_cmd_generator := 41B8, chr_cmd_generate (HL = 41B8 reaches the generator), chr_cmd_generator := 41C9
 * again.  In: C = orient, IY = chr; sp = SP at entry.  Out: HL = 41C9h. */
void chr_cmd_write_one_step(uint16_t chr, uint8_t orient, uint16_t sp)
{
    ww(D64_CHR_CMD_GENERATOR, 0x41B8);                      /* 41A8-41AB */
    chr_cmd_generate(chr, orient, 0x41B8, (uint16_t)(sp - 2));   /* 41AE */
    ww(D64_CHR_CMD_GENERATOR, 0x41C9);                      /* 41B1-41B4 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_41A8(void)
{
    chr_cmd_write_one_step(cpu.iy, cpu.c, cpu.sp);
    SET_HL(0x41C9);
    z80_ret();
}
CHEQUEO(r_41A8, R_HL)
#endif

/* 40FA chr_adso_step_prepare (PC 1000:3B38): removes the character's marks from the height buffer
 * (chr_mark_hbuf with mark 0, which leaves the character's cell in IX, or ix when it is off the buffer),
 * 40C2 := RET (path_square_ok only checks) and chr_path_height := the height of that cell.  In: IY = chr,
 * IX = ix.  Out: IX = the cell, A = the height, C = 0. */
uint16_t chr_adso_step_prepare(uint16_t chr, uint16_t ix)
{
    ix = chr_mark_hbuf(chr, 0, ix);                         /* 40FA-40FC */
    wb(D64_CHR_PATH_SMC_RET, 0xC9);                         /* 40FF-4101 */
    wb(D64_CHR_PATH_HEIGHT, rb(ix) & 0x0F);                 /* 4104-4109 */
    return ix;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_40FA(void)
{
    uint16_t ix = chr_adso_step_prepare(cpu.iy, cpu.ix);
    cpu.ix = ix;
    cpu.a = rb(ix) & 0x0F;
    cpu.c = 0;
    z80_ret();
}
CHEQUEO(r_40FA, R_IX | R_A | R_C)
#endif

/* 4164 chr_adso_step_restore (PC 1000:3BB9): 40C2 := NOP again and the character's mark (+0Eh) back into
 * the height buffer.  In: IY = chr. */
void chr_adso_step_restore(uint16_t chr)
{
    wb(D64_CHR_PATH_SMC_RET, 0x00);                         /* 4164-4165 */
    (void)chr_mark_hbuf(chr, rb((uint16_t)(chr + 0x0E)), 0);   /* 4168-416B (the IX it leaves is not used) */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4164(void)
{
    chr_adso_step_restore(cpu.iy);
    z80_ret();
}
#endif

/* 4130-417F (PC 1000:3B7A): tries the first 3 orientations of entry `entry` of chr_adso_dir_choices
 * (4188, 4 per entry) from the cell ix: the square one step away (chr_dir_buffer_step) has bit 7 cleared and
 * is checked (path_square_ok, check only); the first valid one gets a step command
 * (chr_cmd_write_one_step), the marks come back (chr_adso_step_restore) and Adso's behaviour must run
 * again (JP 04EB ai_update_adso with the same SP: true, the caller does it); if none,
 * chr_adso_step_restore and false (RET).  sp = the SP at the entry of 40EB / 410D. */
static bool adso_try_dirs(uint16_t chr, uint16_t ix, uint8_t entry, uint16_t sp)
{
    uint16_t p = util_add_bx_al(D64_CHR_ADSO_DIR_CHOICES, (uint8_t)(entry * 4));   /* 4130-4138 */
    uint16_t cell;
    uint8_t n = 3, orient;
    do {                                                    /* 4139-4162 */
        orient = rb(p);                                     /* 413B */
        cell = (uint16_t)(ix + rw(util_add_bx_al(D64_CHR_DIR_BUFFER_STEP, (uint8_t)(orient * 2))));   /* 4141-414B */
        wb(cell, rb(cell) & 0x7F);                          /* 414D */
        (void)path_square_ok(cell, rb(cell));               /* 4151-4154 */
        if (rb(cell) & 0x80) {                              /* 4157-415B: a free square */
            wb(cell, rb(cell) & 0x7F);                      /* 416F */
            chr_cmd_write_one_step(chr, orient, (uint16_t)(sp - 2));   /* 4177 */
            chr_adso_step_restore(chr);                     /* 417A */
            return true;                                    /* 417D JP ai_update_adso */
        }
        p = (uint16_t)(p + 1);                              /* 4161 */
    } while (--n);
    chr_adso_step_restore(chr);                             /* 4164 */
    return false;
}

/* 40EB chr_adso_step_guillermo_dir (PC 1000:3B28): (JP from 057E, the down key) Adso (IY) tries to step in
 * Guillermo's orientation or, failing that, the next ones: entry = Guillermo's orientation + 1 (3 -> 7).
 * sp = SP at entry, ix = IX at entry.  True when it leaves through ai_update_adso (JP 04EB, SP = sp): the
 * caller runs it. */
bool chr_adso_step_guillermo_dir(uint16_t chr, uint16_t sp, uint16_t ix)
{
    uint8_t e;
    ix = chr_adso_step_prepare(chr, ix);                    /* 40EB */
    e = (uint8_t)(rb(D64_CHR_GUILLERMO + 1) + 1);           /* 40EE-40F1 */
    if (e == 3) e = 7;                                      /* 40F2-40F6 */
    return adso_try_dirs(chr, ix, e, sp);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_40EB(void)
{
    if (chr_adso_step_guillermo_dir(cpu.iy, cpu.sp, cpu.ix)) ai_update_adso(cpu.sp);   /* JP 04EB */
    z80_ret();
}
#endif

/* 410D chr_adso_step_aside (PC 1000:3B4B): (JP from 0576, Adso blocks Guillermo) entry = the octant of Adso
 * relative to Guillermo: bit 2 Adso has the smaller x, bit 1 the smaller y, bit 0 |dy| < |dx|.  As 40EB. */
bool chr_adso_step_aside(uint16_t chr, uint16_t sp, uint16_t ix)
{
    uint8_t gx, gy, e = 0, ax, ay, dx, dy;
    ix = chr_adso_step_prepare(chr, ix);                    /* 410D */
    gx = rb(D64_CHR_GUILLERMO + 2);                         /* 4110 */
    gy = rb(D64_CHR_GUILLERMO + 3);
    ax = rb(D64_CHR_ADSO + 2);
    ay = rb(D64_CHR_ADSO + 3);
    dx = (uint8_t)(ax - gx);                                /* 4116-4119 */
    if (ax < gx) { dx = (uint8_t)-dx; e |= 4; }             /* 411A-411E */
    dy = (uint8_t)(ay - gy);                                /* 4121-4124 */
    if (ay < gy) { dy = (uint8_t)-dy; e |= 2; }             /* 4125-4129 */
    if (dy < dx) e++;                                       /* 412B-412E */
    return adso_try_dirs(chr, ix, e, sp);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_410D(void)
{
    if (chr_adso_step_aside(cpu.iy, cpu.sp, cpu.ix)) ai_update_adso(cpu.sp);   /* JP 04EB */
    z80_ret();
}
#endif

/* ==== 4451-4AC8: the sprite engine and the room spiral =============================================== */

/* a byte of memory that may be the screen (C000h-FFFFh: rscr / wscr) */
static uint8_t lee_mem(uint16_t a)
{
    return a >= 0xC000 ? rscr(a) : rb(a);
}

static void escribe_mem(uint16_t a, uint8_t v)
{
    if (a >= 0xC000) wscr(a, v); else wb(a, v);
}

/* LDIR: bc bytes (0 = 65536) from *hl to *de, both advanced */
static void ldir(uint16_t *de, uint16_t *hl, uint16_t bc)
{
    do {
        escribe_mem(*de, lee_mem(*hl));
        *de = (uint16_t)(*de + 1);
        *hl = (uint16_t)(*hl + 1);
    } while (--bc);
}

/* 16-bit p plus the 8-bit a (ADD A,L / LD L,A / ADC A,H / SUB L / LD H,A) */
static uint16_t mas8(uint16_t p, uint8_t a)
{
    return (uint16_t)(p + a);
}

/* 4477 util_delay_cx (PC 1000:14AE): DEC BC / LD A,B / OR C / JR NZ: a busy delay of bc passes (0 = 65536);
 * only caller 31C6 (5 x 0500h passes).  Not a wait point of puntos64.txt, so the hybrid gives it no time;
 * the C64 should make it a platform delay.  Out: BC = 0, A = 0, ZF = 1. */
void util_delay_cx(uint16_t bc)
{
    do { } while (--bc);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4477(void)
{
    util_delay_cx(BC);
    SET_BC(0);
    cpu.a = 0;
    banderas_logicas(0, 0);
    z80_ret();
}
CHEQUEO(r_4477, R_A | R_F | R_BC)
#endif

/* 48EB util_mul_al_bx (PC 1000:19AE): hl * a, 8 shift-and-add steps.  Out: DE = the product (16 bit),
 * HL = hl << 8, A = 0, B = 0. */
uint16_t util_mul_al_bx(uint16_t hl, uint8_t a)
{
    uint16_t de = 0;
    uint8_t i;
    for (i = 0; i < 8; i++) {                               /* 48EB LD B,8 ... 48F9 DJNZ */
        if (a & 1) de = (uint16_t)(de + hl);                /* 48F0-48F7 */
        a = (uint8_t)(a >> 1);
        hl = (uint16_t)(hl << 1);                           /* 48F8 */
    }
    return de;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_48EB(void)
{
    SET_DE(util_mul_al_bx(HL, cpu.a));
    SET_HL((uint16_t)(HL << 8));
    cpu.a = 0;
    cpu.b = 0;
    z80_ret();
}
CHEQUEO(r_48EB, R_A | R_B | R_DE | R_HL)
#endif

/* 48FC spr_rect_tile_align (PC 1000:19B5): the tile the rectangle starts in (x & FCh, y & F8h) and the size
 * grown to whole tiles: w = (w + (x & 3) + 3) & FCh, h = (h + (y & 7) + 7) & F8h (8 bit).  In: HL = pos
 * (L = x, H = y), DE = size (E = w, D = h).  Out: HL, DE, C = y & 7, B = x & 3, A = the new w. */
uint16_t spr_rect_tile_align(uint16_t pos, uint16_t *size)
{
    uint8_t x = (uint8_t)pos, y = (uint8_t)(pos >> 8);
    uint8_t w = (uint8_t)*size, h = (uint8_t)(*size >> 8);
    h = (uint8_t)((uint8_t)(h + (y & 7) + 7) & 0xF8);       /* 490C-4912 */
    w = (uint8_t)((uint8_t)(w + (x & 3) + 3) & 0xFC);       /* 4913-4919 */
    *size = (uint16_t)(h << 8 | w);
    return (uint16_t)((y & 0xF8) << 8 | (x & 0xFC));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_48FC(void)
{
    uint16_t size = DE, pos = HL;
    uint16_t p = spr_rect_tile_align(pos, &size);
    cpu.c = (uint8_t)((pos >> 8) & 7);
    cpu.b = (uint8_t)(pos & 3);
    SET_HL(p);
    SET_DE(size);
    cpu.a = (uint8_t)size;
    z80_ret();
}
CHEQUEO(r_48FC, R_A | R_BC | R_DE | R_HL)
#endif

/* 4886 spr_rect_union_old (PC 1000:192B): grows the rectangle spr_rect_pos (2926: x, y) / spr_rect_size
 * (2928: w, h) to cover the old rectangle at old_pos (L = x, H = y) of size old_size (E = w, D = h),
 * re-aligned to 4-byte / 8-line tiles, with the 8-bit arithmetic of the original.  Out: A, C and DE as the
 * original leaves them (*regs = A << 8 | C, the return value DE). */
uint16_t spr_rect_union_old(uint16_t old_pos, uint16_t old_size, uint16_t *regs)
{
    uint8_t l = (uint8_t)old_pos, h = (uint8_t)(old_pos >> 8);
    uint8_t e = (uint8_t)old_size, d = (uint8_t)(old_size >> 8);
    uint8_t a, c;
    a = rb(D64_SPR_RECT_POS);                               /* 4886 */
    if (a >= l) {                                           /* 4889-488A SUB L / JR C */
        c = (uint8_t)(a - l);
        a = (uint8_t)(rb(D64_SPR_RECT_SIZE) + c);           /* 488C-4890 */
        if (a >= e) e = a;                                  /* 4891-4894 */
        c = l & 3;                                          /* 4895-4898 */
        wb(D64_SPR_RECT_POS, l & 0xFC);                     /* 4899-489C */
        a = (uint8_t)((uint8_t)(e + c + 3) & 0xFC);         /* 489F-48A3 */
        wb(D64_SPR_RECT_SIZE, a);
    } else {
        c = (uint8_t)(l - a + e);                           /* 48AA-48AD */
        a = rb(D64_SPR_RECT_SIZE);                          /* 48AE */
        if (a < c) {                                        /* 48B1-48B2 */
            a = (uint8_t)((uint8_t)(c + 3) & 0xFC);         /* 48B4-48B7 */
            wb(D64_SPR_RECT_SIZE, a);
        }
    }
    a = rb(D64_SPR_RECT_POS + 1);                           /* 48BC */
    if (a >= h) {                                           /* 48BF-48C0 */
        c = (uint8_t)(a - h);
        a = (uint8_t)(rb(D64_SPR_RECT_SIZE + 1) + c);       /* 48C2-48C6 */
        if (a >= d) d = a;                                  /* 48C7-48CA */
        c = h & 7;                                          /* 48CB-48CE */
        wb(D64_SPR_RECT_POS + 1, h & 0xF8);                 /* 48CF-48D2 */
        a = (uint8_t)((uint8_t)(d + c + 7) & 0xF8);         /* 48D5-48DB */
        wb(D64_SPR_RECT_SIZE + 1, a);
    } else {
        c = (uint8_t)(h - a + d);                           /* 48DF-48E2 */
        a = rb(D64_SPR_RECT_SIZE + 1);                      /* 48E3 */
        if (a < c) {                                        /* 48E6-48E7 RET NC */
            a = (uint8_t)((uint8_t)(c + 7) & 0xF8);         /* 48E8-48D9 */
            wb(D64_SPR_RECT_SIZE + 1, a);
        }
    }
    *regs = (uint16_t)(a << 8 | c);
    return (uint16_t)(d << 8 | e);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4886(void)
{
    uint16_t regs;
    SET_DE(spr_rect_union_old(HL, DE, &regs));
    cpu.a = (uint8_t)(regs >> 8);
    cpu.c = (uint8_t)regs;
    z80_ret();
}
CHEQUEO(r_4886, R_A | R_C | R_DE)
#endif

/* 4717 spr_mirror_byte: a sprite byte with its 4 mode-1 pixels in the opposite order, through the shadow
 * HL: H' = a, L' = 0, four times RRA / ADC HL,HL, a last RRA, then (A & F0h) | L'.  The first RRA takes the
 * carry the caller leaves (0 after AND A at 46AB).  Out: A, the shadow HL, the flags of OR L. */
uint8_t spr_mirror_byte(uint8_t a, bool cf, uint16_t *hl_sombra)
{
    uint16_t hl = (uint16_t)(a << 8);
    uint32_t t;
    uint8_t c = cf, nc, i;
    for (i = 0; i < 4; i++) {                               /* 471B-4725 */
        nc = a & 1; a = (uint8_t)((a >> 1) | (c << 7)); c = nc;          /* RRA */
        t = (uint32_t)hl * 2u + c; c = (uint8_t)((t >> 16) & 1); hl = (uint16_t)t;   /* ADC HL,HL */
    }
    a = (uint8_t)((a >> 1) | (c << 7));                     /* 4727 RRA */
    *hl_sombra = hl;
    return (uint8_t)((a & 0xF0) | (uint8_t)hl);             /* 4728-472A */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4717(void)
{
    uint16_t hl;
    uint8_t a = spr_mirror_byte(cpu.a, cpu.cf, &hl);
    cpu.a = a;
    banderas_logicas(a, 0);
    cpu.h_ = (uint8_t)(hl >> 8);
    cpu.l_ = (uint8_t)hl;
    z80_ret();
}
CHEQUEO(r_4717, R_A | R_F)
#endif

/* 491B spr_tile_unmark_hook (PC 1000:1A2A): the patched byte 491B: C9 (RET) normally; 00 (NOP, written by
 * spr_draw_all for its final pass) falls into 491C: the 'drawn' bit 7 of the tile-buffer entry (IX) is
 * cleared when spr_tile_ptr_check says it lies in the tile buffer. */
void spr_tile_unmark_hook(uint16_t entry)
{
    if (rb(D64_SPR_TILE_UNMARK_HOOK) == 0xC9) return;      /* 491B RET */
    if (!spr_tile_ptr_check(entry)) return;                 /* 491C-491F CALL 30FD / RET C */
    wb(entry, rb(entry) & 0x7F);                            /* 4920 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_491B(void)
{
    spr_tile_unmark_hook(cpu.ix);
    z80_ret();
}
#endif

/* 49E5 spr_tile_to_buffer (PC 1000:1B3D): tile n (A) at dst (the shadow DE): 8 lines of 4 bytes; after each
 * line dst advances by a word (4A28/4A2C for the merge, 4A44/4A48 for the copy: w - 4 in the sprite buffer,
 * 07FCh on the screen).  The graphic: tiles 80h-FFh at 8300h + 32n, merged with the OR / AND tables
 * 9100h / 9200h; tiles below 80h at the address (C6h + ((n & 70h) >> 1 | bit 3 of n)) << 8 | (32n & FFh)
 * (the unused tails of the screen's 2 KiB blocks), merged with 8F00h / 9000h, or copied as they are when
 * below 0Bh.  dst may be the screen (iso_draw_room_spiral). */
void spr_tile_to_buffer(uint8_t n, uint16_t dst)
{
    uint16_t src = (uint16_t)(n * 32u), paso;
    uint8_t tabla = (uint8_t)(D64_VID_TILE_OR_B >> 8), i, j, b;          /* 49F2-49F5 */
    src = (uint16_t)((uint8_t)((src >> 8) + (D64_ISO_TILE_GFX_HIGH >> 8)) << 8 | (uint8_t)src);   /* 49E5-49F1 */
    if (!(n & 0x80)) {                                      /* 49F6-49F8 */
        uint8_t h = (uint8_t)(((n & 0x70) >> 1) | ((n >> 3) & 1));        /* 49FA-4A05 */
        src = (uint16_t)((uint8_t)(h + 0xC6) << 8 | (uint8_t)src);        /* 4A06-4A08 */
        if (n < 0x0B) {                                     /* 4A09-4A0C: 4A34, opaque copy */
            paso = (uint16_t)(rb(D64_SPR_TILE_COPY_SKIP_HI) << 8 | rb(D64_SPR_TILE_COPY_SKIP));
            for (i = 0; i < 8; i++) {                       /* 4A37 LD B,8 ... 4A4B DJNZ */
                for (j = 0; j < 4; j++) {                   /* 4A3B-4A41 LDI x 4 */
                    escribe_mem(dst, lee_mem(src));
                    dst = (uint16_t)(dst + 1);
                    src = (uint16_t)(src + 1);
                }
                dst = (uint16_t)(dst + paso);               /* 4A43-4A4A */
            }
            return;
        }
        tabla = (uint8_t)(D64_VID_TILE_OR_A >> 8);          /* 4A0E-4A11 */
    }
    paso = (uint16_t)(rb(D64_SPR_TILE_DST_SKIP_HI) << 8 | rb(D64_SPR_TILE_DST_SKIP));
    for (i = 0; i < 8; i++) {                               /* 4A12 LD C,8 ... 4A31 */
        for (j = 0; j < 4; j++) {                           /* 4A14 LD B,4 ... 4A24 DJNZ */
            b = lee_mem(src);                               /* 4A16 */
            escribe_mem(dst, (uint8_t)((lee_mem(dst) & rb((uint16_t)((tabla + 1) << 8 | b)))
                                       | rb((uint16_t)(tabla << 8 | b))));   /* 4A18-4A20 */
            dst = (uint16_t)(dst + 1);
            src = (uint16_t)(src + 1);
        }
        dst = (uint16_t)(dst + paso);                       /* 4A27-4A2E */
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_49E5(void)
{
    spr_tile_to_buffer(cpu.a, (uint16_t)(cpu.d_ << 8 | cpu.e_));
    z80_ret();
}
#endif

/* 4925 spr_draw_tiles_in_depth_range (PC 1000:1A35): copies into the sprite buffer the tiles of the
 * rectangle (tile buffer from spr_tile_pos, size spr_rect_size) whose depth lies between the previous limit
 * and depth + 0101h: spr_depth_lower := spr_depth_upper, spr_depth_upper := (x + 1, y + 1).  The
 * destination (the shadow DE) starts at spr_cur_buffer, +4 per cell, row start + 8 w per row; the next-line
 * steps of spr_tile_to_buffer := w - 4.  Per cell spr_tile_test_jump := 497F; per layer (entry bytes 0-2,
 * 3-5: depth x, depth y, tile): tile 0 -> skip; drawn mark (bit 7) -> JP to spr_tile_test_jump (497F the
 * depth test, which then skips; 49AA draw); else the depth test ((dx >= low.x or dy >= low.y) and
 * dy < up.y and dx < up.x, not drawn): spr_tile_test_jump := 49AA, bit 7 set when spr_tile_ptr_check says
 * the entry is in the tile buffer, spr_tile_to_buffer; after each layer spr_tile_unmark_hook.  Row and
 * cell counts 0 mean 256 (DJNZ / DEC B). */
void spr_draw_tiles_in_depth_range(uint16_t depth)
{
    uint16_t dst, ix, rowix, rowdst, up, lo;
    uint8_t rows, cols, w, n, layer, a, dy;
    bool draw;
    ww(D64_SPR_DEPTH_LOWER, rw(D64_SPR_DEPTH_UPPER));       /* 4925-4928 */
    ww(D64_SPR_DEPTH_UPPER, (uint16_t)((uint8_t)((depth >> 8) + 1) << 8 | (uint8_t)(depth + 1)));   /* 492B-492D */
    dst = rw(D64_SPR_CUR_BUFFER);                           /* 4931-4936 */
    ix = rw(D64_SPR_TILE_POS);                              /* 4937 */
    w = rb(D64_SPR_RECT_SIZE);
    rows = (uint8_t)(rb(D64_SPR_RECT_SIZE + 1) >> 3);       /* 493B-4943 */
    cols = (uint8_t)(w >> 2);                               /* 4945-4947 */
    wb(D64_SPR_TILE_DST_SKIP_HI, 0);                        /* 4949-494D */
    wb(D64_SPR_TILE_COPY_SKIP_HI, 0);
    wb(D64_SPR_TILE_DST_SKIP, (uint8_t)(w - 4));            /* 4950-4958 */
    wb(D64_SPR_TILE_COPY_SKIP, (uint8_t)(w - 4));
    do {                                                    /* 495B */
        rowix = ix;
        rowdst = dst;
        n = cols;
        do {                                                /* 4962 */
            ww(D64_SPR_TILE_TEST_JUMP, 0x497F);             /* 4964-4967 */
            for (layer = 0; layer < 2; layer++) {           /* LD C,2 ... 49C0 DEC C */
                if (rb((uint16_t)(ix + 2)) != 0) {          /* 496A-496E */
                    up = rw(D64_SPR_DEPTH_UPPER);           /* 4971 */
                    lo = rw(D64_SPR_DEPTH_LOWER);           /* 4974 */
                    a = rb(ix);                             /* 4977 */
                    draw = false;
                    if ((a & 0x80) && rw(D64_SPR_TILE_TEST_JUMP) == 0x49AA) {   /* 497A-497C JP NZ,(497D) */
                        draw = true;
                    } else {                                /* 497F */
                        dy = rb((uint16_t)(ix + 1));
                        if ((a >= (uint8_t)lo || dy >= (uint8_t)(lo >> 8))   /* 497F-4988 */
                            && dy < (uint8_t)(up >> 8)                       /* 498A */
                            && rb(ix) < (uint8_t)up                          /* 498D-4991 */
                            && !(rb(ix) & 0x80)) {                           /* 4993-4997 */
                            ww(D64_SPR_TILE_TEST_JUMP, 0x49AA);              /* 4999-499C */
                            if (spr_tile_ptr_check(ix)) wb(ix, rb(ix) | 0x80);   /* 499F-49A6 */
                            draw = true;
                        }
                    }
                    if (draw) { MEDIR_CUENTA(medir_tiles_buf); spr_tile_to_buffer(rb((uint16_t)(ix + 2)), dst); }   /* 49AA-49B5 */
                }
                spr_tile_unmark_hook(ix);                   /* 49B7 */
                ix = (uint16_t)(ix + 3);                    /* 49BA-49BF */
            }
            dst = (uint16_t)(dst + 4);                      /* 49C3-49C8 */
        } while (--n);                                      /* 49C9 DJNZ */
        dst = (uint16_t)(rowdst + 8u * w);                  /* 49CB-49D7 */
        ix = (uint16_t)(rowix + 0x60);                      /* 49D8-49DD */
    } while (--rows);                                       /* 49DF-49E1 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4925(void)
{
    spr_draw_tiles_in_depth_range(BC);
    z80_ret();
}
#endif

/* 47E7 spr_blit_to_screen (PC 1000:1840): copies the composed rectangle of the sprite ix (buffer [ix+10h],
 * x [ix+0Ch] bytes, y [ix+0Dh] lines, w [ix+0Eh], h [ix+0Fh]) to the screen, clipped to the play area:
 * nothing from line C8h or byte 48h on; lines above 28h and bytes left of 8 are cut (spr_blit_skip = bytes
 * cut per line), then the width is cut at 40h bytes (spr_blit_skip = the overflow) and the height at A0h
 * lines; spr_blit_width, spr_blit_lines := what is left; the start by 3778; each line an LDIR of the word
 * spr_blit_width bytes (0: 65536), the source then advances by spr_blit_skip; the next line as 3558 does. */
void spr_blit_to_screen(uint16_t ix)
{
    uint8_t h, b, l, c, a, lines;
    uint16_t cut = 0, src, scr, d;
    wb(D64_SPR_BLIT_SKIP, 0);                               /* 47E7-47E8 */
    h = rb((uint16_t)(ix + 0x0D));                          /* 47EB */
    b = rb((uint16_t)(ix + 0x0F));                          /* 47EE */
    if (h >= 0xC8) return;                                  /* 47F6-47F9 */
    a = (uint8_t)(h - 0x28);                                /* 47FA */
    if (h < 0x28) {                                         /* 47FD JR NC */
        a = (uint8_t)-a;                                    /* 47FF */
        if (a >= b) return;                                 /* 4801-4802 */
        cut = util_mul_al_bx(rb((uint16_t)(ix + 0x0E)), a);        /* 4803-480C */
        b = (uint8_t)(b + (uint8_t)(h - 0x28));             /* 480D-480F */
        h = 0;                                              /* 4810 */
    } else {
        h = a;
    }
    src = (uint16_t)(rw((uint16_t)(ix + 0x10)) + cut);      /* 4812-481A */
    l = rb((uint16_t)(ix + 0x0C));                          /* 481B */
    c = rb((uint16_t)(ix + 0x0E));                          /* 481E */
    if (l >= 0x48) return;                                  /* 4821-4824 */
    a = (uint8_t)(l - 8);                                   /* 4825 */
    if (l < 8) {                                            /* 4828 JR NC */
        a = (uint8_t)-a;                                    /* 482A */
        if (a >= rb((uint16_t)(ix + 0x0E))) return;         /* 482C-482F */
        wb(D64_SPR_BLIT_SKIP, a);                           /* 4830 */
        src = mas8(src, a);                                 /* 4833-4839 */
        c = (uint8_t)(c + (uint8_t)(l - 8));                /* 483A-483C */
        l = 0;                                              /* 483D */
    } else {
        l = a;
    }
    a = (uint8_t)(c + l);                                   /* 483F-4843 */
    if (a >= 0x40) {
        a = (uint8_t)(a - 0x40);
        wb(D64_SPR_BLIT_SKIP, a);                           /* 4845 */
        c = (uint8_t)(c - a);                               /* 4848-484B */
    }
    wb(D64_SPR_BLIT_WIDTH, c);                              /* 484C-484F */
    c = b;                                                  /* 4850-4851 */
    a = (uint8_t)(b + h);                                   /* 4852-4855 */
    if (a >= 0xA0) c = (uint8_t)(c - (uint8_t)(a - 0xA0));  /* 4857-485A */
    wb(D64_SPR_BLIT_LINES, c);                              /* 485B-485E */
    scr = vid_xy_to_offset((uint16_t)(h << 8 | l));         /* 485F CALL 3778 */
    lines = rb(D64_SPR_BLIT_LINES);                         /* 4862 */
    do {
        d = scr;                                            /* 4864-4866 */
        ldir(&d, &src, rw(D64_SPR_BLIT_WIDTH));             /* 4867-486A */
        src = mas8(src, rb(D64_SPR_BLIT_SKIP));             /* 486C-4872 */
        a = (uint8_t)((scr >> 8) + 8);                      /* 4874-4877: the next line, as 3558 */
        if ((scr >> 8) + 8 > 0xFF) {
            uint16_t t = (uint16_t)((uint8_t)scr + 0x40);
            a = (uint8_t)((uint8_t)(a + (t >> 8)) | 0xC0);  /* 487A-4882 */
            scr = (uint16_t)(a << 8 | (uint8_t)t);
        } else {
            scr = (uint16_t)(a << 8 | (uint8_t)scr);
        }
    } while (--lines);                                      /* 4883 DJNZ */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_47E7(void)
{
    spr_blit_to_screen(cpu.ix);
    z80_ret();
}
#endif

/* 472D-47A9 (inside spr_draw_all, PC 1000:1725): the light sprite (graphic pointer 0), composed at dst in a
 * rectangle 14h bytes wide: a top band of FFh bytes (one, then an LDIR of spr_light_fill_a), 15 rows of 4
 * lines: spr_light_dx dark bytes (DJNZ after a zero test), 16 bits of spr_light_pattern (big endian; a 0 bit
 * is a dark byte x 4 lines; one more shift first when spr_light_flip holds ADD HL,HL), spr_light_dx_rest
 * dark bytes (no zero test: 0 = 256), then a bottom band (one FFh and an LDIR of spr_light_fill_b).  Dark
 * is FFh.  The pattern pointer, row counter and row step live in the shadow registers. */
static void spr_draw_light(uint16_t dst)
{
    uint16_t d, s, ix, row, pat = D64_SPR_LIGHT_PATTERN, bits;
    uint8_t r, c, k;
    d = (uint16_t)(dst + 1); s = dst;                       /* 4732-473C */
    wb(dst, 0xFF);
    ldir(&d, &s, rw(D64_SPR_LIGHT_FILL_A));
    ix = d;                                                 /* 473F-4740 */
    for (r = 15; r; r--) {                                  /* 4746 LD B,0Fh ... 4798 DJNZ */
        row = ix;                                           /* 4748 PUSH IX */
        bits = (uint16_t)(rb(pat) << 8 | rb((uint16_t)(pat + 1)));   /* 474A-4752 */
        pat = (uint16_t)(pat + 2);
        c = rb(D64_SPR_LIGHT_DX);                           /* 4755-4759 */
        if (c) {
            do {
                for (k = 0; k < 4; k++) wb((uint16_t)(ix + 0x14 * k), 0xFF);   /* 475B-4767 */
                ix = (uint16_t)(ix + 1);
            } while (--c);
        }
        if (rb(D64_SPR_LIGHT_FLIP) == 0x29) bits = (uint16_t)(bits << 1);   /* 476D */
        for (c = 16; c; c--) {                              /* 476B LD B,10h ... 477F DJNZ */
            uint8_t lit = (uint8_t)(bits >> 15);            /* 476E-476F */
            bits = (uint16_t)(bits << 1);
            if (!lit)
                for (k = 0; k < 4; k++) wb((uint16_t)(ix + 0x14 * k), 0xFF);   /* 4771-477C */
            ix = (uint16_t)(ix + 1);                        /* 477D */
        }
        c = rb(D64_SPR_LIGHT_DX_REST);                      /* 4781 */
        do {
            for (k = 0; k < 4; k++) wb((uint16_t)(ix + 0x14 * k), 0xFF);   /* 4783-478F */
            ix = (uint16_t)(ix + 1);
        } while (--c);
        ix = (uint16_t)(row + 0x50);                        /* 4793-4797 */
    }
    s = ix; d = (uint16_t)(ix + 1);                         /* 479A-47A2 */
    wb(ix, 0xFF);                                           /* 47A3 */
    ldir(&d, &s, rw(D64_SPR_LIGHT_FILL_B));                 /* 47A5 */
}

/* 4612-4714 (inside spr_draw_all, PC 1000:1661): merges the sprite iy into the rectangle being composed,
 * after the clipping stored in the operands 46A7, 467C/4703, 4694, 46A4, 4614, 4684.  The first graphic line
 * is [iy+7] + skipped lines * width, or for a monk ([iy+0Bh] bit 7 clear) already past line 10 his robe
 * (spr_monk_robes[[iy+0Bh]], bit 14 of the pointer = mirrored) + (lines - 10) * width; plus the skipped
 * bytes.  Mirrored graphics: spr_ov_mirror_call := CALL NZ (spr_mirror_byte), spr_ov_src_step := DEC HL and
 * the skipped bytes counted from the right (w - skip - 1).  The destination: spr_cur_buffer + dst_y *
 * rectangle width + dst_x.  A graphic pointer of 0 is the light.  Bytes 0 are transparent; the others are
 * merged: dst = (dst & ~(b | b >> 4 << ... the pixels of b that are not 0)) | b.  At sprite line 10 a monk
 * switches to his robe (the patches of a mirrored robe set again; a plain robe keeps them). */
static void spr_merge_sprite(uint16_t iy)
{
    uint16_t src, dst, rsrc, rdst, hl, rp;
    uint8_t c, lines, w, b, m, robe, hi;
    wb(D64_SPR_OV_MIRROR_CALL, 0xCC);                       /* 4616-4618 */
    wb(D64_SPR_OV_SRC_STEP, 0x23);                          /* 461B-461D */
    hl = rw(D64_SPR_OV_SRC_Y);                              /* 4613 */
    wb(D64_SPR_OV_LINE, (uint8_t)hl);                       /* 4620-4621 */
    if ((uint8_t)hl >= 0x0A && !(rb((uint16_t)(iy + 0x0B)) & 0x80)) {   /* 4624-462C */
        hl = (uint16_t)((hl & 0xFF00) | (uint8_t)(hl - 0x0A));          /* 462E-4631 */
        wb(D64_SPR_OV_SRC_STRIDE, rb((uint16_t)(iy + 5)));  /* 4632-4635 */
        src = util_mul_al_bx(hl, rb((uint16_t)(iy + 5)));          /* 4638 */
        robe = rb((uint16_t)(iy + 0x0B));                   /* 463B-464A */
        rp = rw((uint16_t)(D64_SPR_MONK_ROBES + (uint8_t)(robe + robe)));
        hi = (uint8_t)(rp >> 8);
        src = (uint16_t)((rp & 0xBFFF) + src);              /* 464B-464E */
        if (hi & 0x40) {                                    /* 464F-4651 */
            wb(D64_SPR_OV_MIRROR_CALL, 0xC4);               /* 4653-4655 */
            wb(D64_SPR_OV_SRC_STEP, 0x2B);                  /* 4658-465A */
            wb(D64_SPR_OV_SRC_X, (uint8_t)(rb((uint16_t)(iy + 5)) - rb(D64_SPR_OV_SRC_X) - 1));   /* 465D-4666 */
        }
    } else {
        wb(D64_SPR_OV_SRC_STRIDE, rb((uint16_t)(iy + 5)));  /* 466B-466E */
        src = (uint16_t)(rw((uint16_t)(iy + 7)) + util_mul_al_bx(hl, rb((uint16_t)(iy + 5))));   /* 4671-467A */
    }
    src = mas8(src, rb(D64_SPR_OV_SRC_X));                  /* 467B-4681 */
    wb(D64_SPR_OV_DST_STRIDE, rb(D64_SPR_RECT_SIZE));       /* 4686-4689 */
    dst = (uint16_t)(rw(D64_SPR_CUR_BUFFER) + util_mul_al_bx(rw(D64_SPR_OV_DST_Y), rb(D64_SPR_RECT_SIZE)));   /* 4683-4692 */
    dst = mas8(dst, rb(D64_SPR_OV_DST_X));                  /* 4693-4699 */
    if (src == 0) {                                         /* 469B-469D JP Z,472D */
        spr_draw_light(dst);
        return;
    }
    c = rb(D64_SPR_OV_LINE);                                /* 46A0 */
    lines = rb(D64_SPR_OV_LINES);                           /* 46A3 */
    do {
        w = rb(D64_SPR_OV_WIDTH);                           /* 46A6 */
        rsrc = src;                                         /* 46A8-46A9 */
        rdst = dst;
        do {
            b = lee_mem(src);                               /* 46AA */
            if (b != 0) {                                   /* 46AB-46AC */
#ifdef MEDIR_SCRATCH
                if (rb(D64_SPR_OV_MIRROR_CALL) == 0xC4) medir_mezcla_esp++;
                else if ((rb(D64_SPR_OV_DST_X) ^ rb(D64_SPR_OV_SRC_X)) & 1) medir_mezcla_desp++;
                else medir_mezcla_alin++;
#endif
                if (rb(D64_SPR_OV_MIRROR_CALL) == 0xC4) {   /* 46AE CALL NZ,4717 */
                    uint16_t sombra;
                    b = spr_mirror_byte(b, false, &sombra);
                }
                m = (uint8_t)(b | (uint8_t)(b >> 4 | b << 4));   /* 46B2-46B7 */
                m = (uint8_t)~m;                            /* 46BA */
                wb(dst, (uint8_t)((rb(dst) & m) | b));      /* 46BD-46C2 */
            }
            src = rb(D64_SPR_OV_SRC_STEP) == 0x2B ? (uint16_t)(src - 1) : (uint16_t)(src + 1);   /* 46C3 */
            dst = (uint16_t)(dst + 1);                      /* 46C4 */
        } while (--w);                                      /* 46C5 DJNZ */
        src = (uint16_t)(rsrc + rw(D64_SPR_OV_SRC_STRIDE)); /* 46C7-46CB */
        dst = rdst;                                         /* 46CC */
        c++;                                                /* 46CD */
        if (c == 0x0A) {                                    /* 46CE-46D1 */
            robe = rb((uint16_t)(iy + 0x0B));               /* 46D3 */
            if (!(robe & 0x80)) {                           /* 46D6-46D8 */
                rp = rw((uint16_t)(D64_SPR_MONK_ROBES + (uint8_t)(robe + robe)));   /* 46DA-46E5 */
                if (rp & 0x4000) {                          /* 46E6-46E8 */
                    wb(D64_SPR_OV_MIRROR_CALL, 0xC4);       /* 46EB-46ED */
                    wb(D64_SPR_OV_SRC_STEP, 0x2B);          /* 46F0-46F2 */
                    wb(D64_SPR_OV_SRC_X_ROBE, (uint8_t)(rb((uint16_t)(iy + 5)) - rb(D64_SPR_OV_SRC_X_ROBE) - 1));   /* 46F5-46FE */
                }
                src = (uint16_t)(mas8(rp, rb(D64_SPR_OV_SRC_X_ROBE)) & 0xBFFF);   /* 4701-4708 */
            }
        }
        dst = mas8(dst, rb(D64_SPR_OV_DST_STRIDE));         /* 470A-4710 */
    } while (--lines);                                      /* 4711-4712 DJNZ */
}

/* 447D spr_draw_all (PC 1000:14B6): composes and draws every sprite that changed (entered by JP from 2236
 * and 2262: sp = their entry SP).  spr_saved_sp := sp, spr_buf_free := 7F80h; a 0 word and the address of
 * every active sprite (FE skipped, FF ends) are pushed (the list lives on the stack: spr_sorted_top = sp - 2
 * - 2n), counting those with bit 7; none -> SP back, EI, RET.  Bubble sort by depth ([spr] & 3Fh, ascending
 * towards the top).  Then for each sprite popped through spr_sorted_cursor: bit 6 cleared; bit 7 set ->
 * the union of its new and old rectangles aligned to tiles (spr_rect_tile_align, spr_rect_union_old ->
 * spr_rect_pos/size, [spr+0Ch..0Fh]), spr_tile_pos := 8594h + 12 y + 1.5 x, w*h bytes of the sprite buffer
 * ([spr+10h], spr_cur_buffer; full past 877Eh -> step 5) cleared, bit 6 set, spr_depth_upper := 0; every
 * sprite of the list (spr_overlay_cursor; vanishing ones skipped) is clipped (3786, x then y), the tiles
 * between the previous depth and its depth [spr+12h] are copied (spr_draw_tiles_in_depth_range) and it is
 * merged; at the end the tiles in front of everything are copied (BC = FCFCh with the hook 491B = NOP).
 * Step 5 (47AC): every processed sprite is copied to the screen (spr_blit_to_screen), its flags cleared, a
 * vanishing one becomes FE; then SP = spr_saved_sp and the whole routine runs again (the sprites that did
 * not fit).  The CPU's SP is moved to the list's top while composing (the Z80 calls go below it).
 * Out: *rix, *riy = the IX, IY the original leaves (the last sprite of step 5 and of the overlay list; kept
 * when nothing changed), HL = the FF of the sprite table, DE = 14h, A = C = 0. */
static void spr_draw(uint16_t sp, uint16_t *rix, uint16_t *riy)
{
    uint16_t s, top, q, de, hl, cursor, ocur, ix, iy, pos, size, bytes, buf, next, d, f, regs;
    uint32_t suma;
    uint8_t changed, swaps, len, skip, off, a;
    for (;;) {
        MEDIR_CUENTA(medir_pasadas);
        MEDIR_HW_PASADA();
        ww(D64_SPR_SAVED_SP, sp);                           /* 447D */
        ww(D64_SPR_BUF_FREE, D64_SPR_BUFFER);               /* 4481-4484 */
        q = sp;
        ww((uint16_t)(q - 2), 0); q = (uint16_t)(q - 2);    /* 4487-448B */
        changed = 0;
        for (s = D64_SPR_TABLE;; s = (uint16_t)(s + 0x14)) {   /* 448C-44A2 */
            a = rb(s);
            if (a == 0xFF) break;
            if (a == 0xFE) continue;
            q = (uint16_t)(q - 2); ww(q, s);
            if (a & 0x80) changed++;
        }
        top = q;
        ww(D64_SPR_SORTED_TOP, top);                        /* 44A4 */
        plat_di();                                          /* 44A8 */
        if (!changed) {                                     /* 44A9-44B2 */
            plat_ei();
            return;
        }
        for (;;) {                                          /* 44B3: bubble sort */
            swaps = 0;
            q = top;
            de = rw(q);
            for (;;) {
                hl = rw((uint16_t)(q + 2));
                if (hl == 0) break;                         /* 44BB-44C3 */
                if ((rb(hl) & 0x3F) < (rb(de) & 0x3F)) {    /* 44C5-44CD */
                    ww(q, hl);                              /* 44D2-44D5 */
                    ww((uint16_t)(q + 2), de);
                    swaps++;
                } else {
                    de = hl;                                /* 44CF */
                }
                q = (uint16_t)(q + 2);
            }
            if (!swaps) break;
        }
        /* 44D8 LD SP,(2BE1): the CPU's SP on the list while composing */
        cursor = top;
        ww(D64_SPR_SORTED_CURSOR, cursor);                  /* 44DC */
        for (;;) {                                          /* 44E0 */
            plat_di();                                      /* 44E4-44EF: SP on the list */
            de = rw(cursor);
            cursor = (uint16_t)(cursor + 2);
            ww(D64_SPR_SORTED_CURSOR, cursor);
            plat_ei();
            if (de == 0) break;                             /* 44F0-44F2 JP Z,47AC */
            ix = de;                                        /* 44F5-44F6 */
            *rix = ix;
            wb(ix, rb(ix) & 0xBF);                          /* 44F8 */
            if (!(rb(ix) & 0x80)) continue;                 /* 44FC-4500 */
            pos = (uint16_t)(rb((uint16_t)(ix + 2)) << 8 | rb((uint16_t)(ix + 1)));   /* 4502-4505 */
            size = (uint16_t)(rb((uint16_t)(ix + 6)) << 8 | (rb((uint16_t)(ix + 5)) & 0x7F));   /* 4508-450E */
            pos = spr_rect_tile_align(pos, &size);          /* 4510 */
            ww(D64_SPR_RECT_SIZE, size);                    /* 4513 */
            ww(D64_SPR_RECT_POS, pos);                      /* 4517 */
            (void)spr_rect_union_old((uint16_t)(rb((uint16_t)(ix + 4)) << 8 | rb((uint16_t)(ix + 3))),
                                     (uint16_t)(rb((uint16_t)(ix + 0x0A)) << 8 | rb((uint16_t)(ix + 9))), &regs);   /* 451A-4526 */
            pos = rw(D64_SPR_RECT_POS);                     /* 4529 */
            wb((uint16_t)(ix + 0x0C), (uint8_t)pos);        /* 452C-4531 */
            wb((uint16_t)(ix + 0x0D), (uint8_t)(pos >> 8));
            f = (uint16_t)(pos & 0xFC);                     /* 4532-453D */
            f = (uint16_t)(f + (f >> 1));
            ww(D64_SPR_TILE_POS, (uint16_t)(0x8594u + 12u * (uint8_t)(pos >> 8) + f));   /* 453E-454E */
            size = rw(D64_SPR_RECT_SIZE);                   /* 4551 */
            wb((uint16_t)(ix + 0x0E), (uint8_t)size);       /* 4554-4559 */
            wb((uint16_t)(ix + 0x0F), (uint8_t)(size >> 8));
            bytes = util_mul_al_bx((uint8_t)size, (uint8_t)(size >> 8));   /* 455A-455F */
            buf = rw(D64_SPR_BUF_FREE);                     /* 4560 */
            ww(D64_SPR_CUR_BUFFER, buf);                    /* 4563 */
            wb((uint16_t)(ix + 0x10), (uint8_t)buf);        /* 4566-456B */
            wb((uint16_t)(ix + 0x11), (uint8_t)(buf >> 8));
            suma = (uint32_t)buf + bytes;                   /* 456C-4570 */
            next = (uint16_t)suma;
            ww(D64_SPR_BUF_FREE, next);
#ifdef MEDIR_SCRATCH
            if (next >= (uint16_t)D64_PATH_QUEUE || suma > 0xFFFFu) medir_buf_llenos++;
            else if (next > medir_buf_max) medir_buf_max = next;
#endif
            if (!((uint32_t)next < (uint32_t)D64_PATH_QUEUE + (suma > 0xFFFFu))) break;   /* 4573-4579 SBC, JP NC,47AC */
            wb(ix, rb(ix) | 0x40);                          /* 457C */
            MEDIR_CUENTA(medir_rect);
            MEDIR_HW_RECT(ix, bytes);
            d = (uint16_t)(buf + 1); q = buf;               /* 4580-4586 */
            wb(buf, 0);
            ldir(&d, &q, (uint16_t)(bytes - 1));
            ww(D64_SPR_DEPTH_UPPER, 0);                     /* 4588-458B */
            ocur = top;                                     /* 458F-4593 */
            ww(D64_SPR_OVERLAY_CURSOR, ocur);
            for (;;) {                                      /* 4597 */
                plat_di();                                  /* 459B-45A6: SP on the list */
                de = rw(ocur);
                ocur = (uint16_t)(ocur + 2);
                ww(D64_SPR_OVERLAY_CURSOR, ocur);
                plat_ei();
                if (de == 0) {                              /* 45A7-45A9 */
                    wb(D64_SPR_TILE_UNMARK_HOOK, 0x00);     /* 45AC-45B1 */
                    spr_draw_tiles_in_depth_range(0xFCFC);  /* 45B4 */
                    wb(D64_SPR_TILE_UNMARK_HOOK, 0xC9);     /* 45B7-45B9 */
                    break;                                  /* 45BC JP 44E0 */
                }
                iy = de;                                    /* 45BF-45C0 */
                *riy = iy;
                if (rb((uint16_t)(iy + 5)) & 0x80) continue;   /* 45C2-45C6 */
                if (!util_clip_span(rb(D64_SPR_RECT_POS), rb((uint16_t)(iy + 1)), rb((uint16_t)(iy + 5)),
                                    rb(D64_SPR_RECT_SIZE), &len, &skip, &off)) continue;   /* 45C8-45D9 CALL 3786 */
                wb(D64_SPR_OV_WIDTH, len);                  /* 45DC */
                wb(D64_SPR_OV_SRC_X, skip);                 /* 45DF-45E3 */
                wb(D64_SPR_OV_SRC_X_ROBE, skip);
                wb(D64_SPR_OV_DST_X, off);                  /* 45E6 */
                if (!util_clip_span(rb(D64_SPR_RECT_POS + 1), rb((uint16_t)(iy + 2)), rb((uint16_t)(iy + 6)),
                                    rb(D64_SPR_RECT_SIZE + 1), &len, &skip, &off)) continue;   /* 45EA-45FB CALL 3786 */
                wb(D64_SPR_OV_LINES, len);                  /* 45FE */
                wb(D64_SPR_OV_SRC_Y, skip);                 /* 4601 */
                wb(D64_SPR_OV_DST_Y, off);                  /* 4605 */
                spr_draw_tiles_in_depth_range((uint16_t)(rb((uint16_t)(iy + 0x13)) << 8 | rb((uint16_t)(iy + 0x12))));   /* 4609-460F */
                spr_merge_sprite(iy);                       /* 4612-4714 */
            }
        }
        for (ix = D64_SPR_TABLE;; ix = (uint16_t)(ix + 0x14)) {   /* 47AC-47DD: step 5 */
            a = rb(ix);
            if (a == 0xFF) break;
            if (a == 0xFE || !(a & 0x40)) continue;
            spr_blit_to_screen(ix);                         /* 47BF */
            wb(ix, rb(ix) & 0x3F);                          /* 47C2-47C9 */
            if (rb((uint16_t)(ix + 5)) & 0x80) {            /* 47CA-47CE */
                wb((uint16_t)(ix + 5), rb((uint16_t)(ix + 5)) & 0x7F);
                wb(ix, 0xFE);
            }
        }
        *rix = ix;
        sp = rw(D64_SPR_SAVED_SP);                          /* 47E0 LD SP,(4473) / JP 447D */
    }
}

/* 447D spr_draw_all: spr_draw for the C callers (the registers dropped).  In: sp. */
void spr_draw_all(uint16_t sp)
{
    uint16_t ix = 0, iy = 0;
    spr_draw(sp, &ix, &iy);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_447D(void)
{
    uint16_t sp = cpu.sp, s, ix = cpu.ix, iy = cpu.iy;
    spr_draw(sp, &ix, &iy);
    cpu.ix = ix;
    cpu.iy = iy;
    for (s = D64_SPR_TABLE; rb(s) != 0xFF; s = (uint16_t)(s + 0x14)) {}
    SET_HL(s);
    SET_DE(0x0014);
    cpu.a = 0;
    cpu.c = 0;
    z80_ret();
}
CHEQUEO(r_447D, R_A | R_C | R_DE | R_HL | R_IX | R_IY)
#endif

/* 4AC8 iso_draw_tile (PC 1000:1C53 iso_draw_tile_run, one tile): PUSH DE / EXX / CALL 49E5 / POP DE: tile a
 * drawn at the screen address DE (which becomes the shadow DE of spr_tile_to_buffer).  The POP DE goes
 * into the other register set: the caller's sets come back swapped, with DE = de in the main one. */
void iso_draw_tile(uint8_t a, uint16_t de)
{
    MEDIR_CUENTA(medir_tiles_sala);
    spr_tile_to_buffer(a, de);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4AC8(void)
{
    uint16_t de = DE;
    iso_draw_tile(cpu.a, de);
    exx();
    SET_DE(de);
    z80_ret();
}
CHEQUEO(r_4AC8, R_DE)
#endif

/* 4A5F iso_draw_room_spiral (PC 1000:1BD6): draws the whole tile buffer to the screen from the centre
 * outwards (entered by JP from 163B): from the tile-buffer entry 8AAAh and the screen address C21Ch, 8
 * rounds of runs down, right, up and left (iso_spiral_runs 4A4F: lengths 4, 1, 5, 2, each 2 longer the next
 * round; buffer steps +60h, +6, -60h, -6; screen steps +40h, +4, -40h, -4); for each entry of a run the
 * background tile [entry+2] and then the foreground tile [entry+5], when not 0, are drawn (iso_draw_tile);
 * the next-line steps of spr_tile_to_buffer := 07FCh (the next pixel line of the screen, back 4 bytes). */
void iso_draw_room_spiral(void)
{
    uint16_t de = 0xC21C, ix = 0x8AAA, iy;
    uint8_t c, b, n;
    wb(D64_SPR_TILE_DST_SKIP, 0xFC);                        /* 4A62-4A67 */
    wb(D64_SPR_TILE_COPY_SKIP, 0xFC);
    wb(D64_SPR_TILE_DST_SKIP_HI, 0x07);                     /* 4A6A-4A6F */
    wb(D64_SPR_TILE_COPY_SKIP_HI, 0x07);
    wb(D64_ISO_SPIRAL_RUNS, 4);                             /* 4A76-4A86 */
    wb(D64_ISO_SPIRAL_RUNS + 4, 1);
    wb(D64_ISO_SPIRAL_RUNS + 8, 5);
    wb(D64_ISO_SPIRAL_RUNS + 0x0C, 2);
    for (c = 8; c; c--) {                                   /* 4A8A LD C,8 ... 4AC5 */
        iy = D64_ISO_SPIRAL_RUNS;                           /* 4A8C */
        for (b = 4; b; b--) {                               /* 4A90 LD B,4 ... 4AC2 DJNZ */
            n = rb(iy);                                     /* 4A93 */
            wb(iy, (uint8_t)(n + 2));                       /* 4A96-4A9B */
            do {                                            /* 4A9C ... 4ABA DJNZ */
                if (rb((uint16_t)(ix + 2))) iso_draw_tile(rb((uint16_t)(ix + 2)), de);   /* 4A9D-4AA1 */
                if (rb((uint16_t)(ix + 5))) iso_draw_tile(rb((uint16_t)(ix + 5)), de);   /* 4AA4-4AA8 */
                ix = (uint16_t)(ix + (rb((uint16_t)(iy + 3)) << 8 | rb((uint16_t)(iy + 1))));   /* 4AAB-4AB1 */
                de = (uint16_t)(de + (rb((uint16_t)(iy + 3)) << 8 | rb((uint16_t)(iy + 2))));   /* 4AB3-4AB8 */
            } while (--n);
            iy = (uint16_t)(iy + 4);                        /* 4ABC-4ABF */
        }
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4A5F(void)
{
    iso_draw_room_spiral();
    z80_ret();
}
#endif

/* ==== 4B43-4C45: score bar phrases, inline text, inventory =========================================== */

/* 4B43 util_ret_530a (PC 1000:530A): a lone RET called once per frame by the main loop (a removed
 * routine).  No inputs, no outputs. */
void util_ret_530a(void)
{
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4B43(void)
{
    util_ret_530a();
    z80_ret();
}
#endif

/* 4B44 txt_print_inline (PC 1000:530B): `CALL 4B44 <bytes> FF`: prints every byte AND 7Fh with
 * txt_draw_char_inverted (3649) at the cursor txt_cursor, up to the FF; returns past the FF.  In: s =
 * the address of the bytes (in ds[]: game_compute_percentage writes into one of them).  Out: the
 * address past the FF (also IX), A = FFh, ZF = 1. */
uint16_t txt_print_inline(uint16_t s)
{
    uint8_t c;
    for (;;) {
        c = rb(s);                                          /* 4B46 */
        s = (uint16_t)(s + 1);
        if (c == 0xFF) return s;                            /* 4B4D-4B4F */
        (void)txt_draw_char_inverted((uint8_t)(c & 0x7F));  /* 4B50-4B52 CALL 3649 */
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4B44(void)
{
    uint16_t fin = txt_print_inline(rw(cpu.sp));
    cpu.ix = fin;
    cpu.a = 0xFF;
    cpu.zf = 1;
    retorna_a(fin);
}
CHEQUEO(r_4B44, R_A | R_ZF | R_IX)
#endif

/* 4BB2 txt_skip_strings (PC 1000:53A8): p advanced past n FF-terminated strings (n = 0 skips 256).
 * In: HL = p, B = n.  Out: HL, B = 0, A = FFh. */
uint16_t txt_skip_strings(uint16_t p, uint8_t n)
{
    do {
        while (rb(p++) != 0xFF) {}                          /* 4BB2-4BB6 */
    } while (--n);                                          /* 4BB8 DJNZ */
    return p;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4BB2(void)
{
    SET_HL(txt_skip_strings(HL, cpu.b));
    cpu.b = 0;
    cpu.a = 0xFF;
    z80_ret();
}
CHEQUEO(r_4BB2, R_HL | R_B | R_A)
#endif

/* 4B57 hud_clear_phrase_area (PC 1000:531D): clears the phrase line of the score bar: 8 pixel lines of
 * 20h bytes from screen E510h (FFh stored in the first byte and propagated by LDIR to the next 1Fh; the
 * next line by 3558).  No register results. */
void hud_clear_phrase_area(void)
{
    uint16_t p = 0xE510;                                    /* 4B59 */
    uint8_t n, i;
    for (n = 8; n; n--) {                                   /* 4B57 LD B,8 ... 4B6E DJNZ */
        wscr(p, 0xFF);                                      /* 4B63 */
        for (i = 0; i < 0x1F; i++)                          /* 4B67 LDIR */
            wscr((uint16_t)(p + 1 + i), rscr((uint16_t)(p + i)));
        p = vid_next_line(p);                               /* 4B6A CALL 3558 */
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4B57(void)
{
    hud_clear_phrase_area();
    z80_ret();
}
#endif

/* 4B7C hud_say (PC 1000:535F): `CALL 4B7C <db phrase>`: starts phrase `phrase` unless one is being shown
 * (txt_phrase_busy): snd_phrase_voice := txt_phrase_sound[phrase], txt_phrase_busy = txt_phrase_active =
 * txt_word_done := 1, txt_phrase_ptr := the phrase in txt_phrases (txt_skip_strings), txt_trailing_blanks
 * := 0 (no beep, unlike the PC).  DI ... EI.  Out: CF = 1 started (A = 0), 0 busy. */
bool hud_say(uint8_t phrase)
{
    uint16_t p;
    if (rb(D64_TXT_PHRASE_BUSY)) return false;              /* 4B7F-4B83 */
    plat_di();                                              /* 4B84 */
    p = util_add_bx_al(D64_TXT_PHRASE_SOUND, phrase);       /* 4B86-4B8B */
    wb(D64_SND_PHRASE_VOICE, rb(p));                        /* 4B8E-4B8F */
    wb(D64_TXT_PHRASE_BUSY, 1);                             /* 4B95-4B9D */
    wb(D64_TXT_PHRASE_ACTIVE, 1);
    wb(D64_TXT_WORD_DONE, 1);
    p = D64_TXT_PHRASES;                                    /* 4BA0 */
    if (phrase) p = txt_skip_strings(p, phrase);            /* 4BA3-4BA5 */
    ww(D64_TXT_PHRASE_PTR, p);                              /* 4BA8 */
    wb(D64_TXT_TRAILING_BLANKS, 0);                         /* 4BAB-4BAC */
    plat_ei();                                              /* 4BB0 */
    return true;
}

#ifndef JUEGO_PURO  /* the hybrid host */
/* the registers hud_say leaves: started: CF = 1, A = 0, HL = txt_phrase_ptr, DE = the txt_phrase_sound entry,
 * B = 0; busy: CF = 0, A = txt_phrase_busy, HL = past the inline byte */
static void w_hud_say_salida(uint16_t ret, bool started)
{
    if (started) {
        cpu.a = 0;
        cpu.cf = 1;
        SET_HL(rw(D64_TXT_PHRASE_PTR));
        SET_DE((uint16_t)(D64_TXT_PHRASE_SOUND + rb(ret)));
        cpu.b = 0;
    } else {
        cpu.a = rb(D64_TXT_PHRASE_BUSY);
        cpu.cf = 0;
        SET_HL((uint16_t)(ret + 1));
    }
    retorna_a((uint16_t)(ret + 1));
}

static void w_4B7C(void)
{
    uint16_t ret = rw(cpu.sp);
    w_hud_say_salida(ret, hud_say(rb(ret)));
}
CHEQUEO(r_4B7C, R_A | R_CF | R_HL)
#endif

/* 4B71 hud_say_now (PC 1000:5353): `CALL 4B71 <db phrase>`: a phrase with priority: txt_phrase_busy :=
 * txt_phrase_active := 0, clears the phrase line, then falls into hud_say with the same inline byte. */
void hud_say_now(uint8_t phrase)
{
    plat_di();                                              /* 4B71 */
    wb(D64_TXT_PHRASE_BUSY, 0);                             /* 4B72-4B76 */
    wb(D64_TXT_PHRASE_ACTIVE, 0);
    hud_clear_phrase_area();                                /* 4B79 */
    (void)hud_say(phrase);                                  /* falls into 4B7C */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4B71(void)
{
    uint16_t ret = rw(cpu.sp);
    hud_say_now(rb(ret));
    w_hud_say_salida(ret, true);
}
CHEQUEO(r_4B71, R_A | R_CF | R_B | R_DE | R_HL)
#endif

/* 4BDE obj_play_inventory_sound (PC 1000:53D5): changed = old ^ new object bits (A), held = the new bits
 * (C): the drop sound (0C9F) when (changed & held) == 0, else the take sound (0C95).  AF and BC are
 * preserved. */
void obj_play_inventory_sound(uint8_t changed, uint8_t held)
{
    if ((changed & held) == 0) snd_play_object_dropped();   /* 4BE0-4BE2 CALL Z,0C9F */
    else snd_play_object_taken();                           /* 4BE6 CALL 0C95 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4BDE(void)
{
    z80 s = cpu;
    obj_play_inventory_sound(cpu.a, cpu.c);
    repone(&s, R_A | R_F | R_BC);
    z80_ret();
}
CHEQUEO(r_4BDE, R_A | R_F | R_BC)
#endif

/* 4BEC obj_update_inventory (PC 1000:53EC): once per frame: obj_pick_up_objects (4C46) for every holder,
 * obj_drop_on_space (4DC3), obj_update_key_permissions (4D97); the inventory sounds of Adso (objects, then
 * the lamp byte) and Guillermo; obj_read_manuscript (5184) when Guillermo's glasses/parchment bits changed
 * and he has both; redraw of the changed score-bar slots (4D30); bit 0 ('taken this frame') cleared in
 * every object record.  No register results. */
void obj_update_inventory(void)
{
    uint8_t lamp_before, adso_before, c, a;
    uint16_t p;
    wb(D64_OBJ_GUILLERMO_OBJECTS_BEFORE, rb(D64_B2_GUILLERMO_OBJECTS));   /* 4BEC-4BF3 */
    lamp_before = rb(D64_GAME_ADSO_LAMP);                   /* 4BF6 */
    adso_before = rb(D64_OBJ_ADSO_OBJECTS);                 /* 4BFA */
    (void)obj_pick_up_objects(D64_OBJ_CHAR_OBJECTS);        /* 4BFE CALL 4C46 (IX = the holders) */
    obj_drop_on_space();                                    /* 4C01 CALL 4DC3 */
    (void)obj_update_key_permissions();                     /* 4C04 CALL 4D97 */
    c = rb(D64_OBJ_ADSO_OBJECTS);                           /* 4C07-4C0A */
    a = (uint8_t)(adso_before ^ c);                         /* 4C0C */
    if (a) obj_play_inventory_sound(a, c);                  /* 4C0D */
    c = rb(D64_GAME_ADSO_LAMP);                             /* 4C10-4C13 */
    a = (uint8_t)(lamp_before ^ c);                         /* 4C15 */
    if (a) obj_play_inventory_sound(a, c);                  /* 4C16 */
    c = rb(D64_B2_GUILLERMO_OBJECTS);                       /* 4C19-4C1C */
    a = (uint8_t)(rb(D64_OBJ_GUILLERMO_OBJECTS_BEFORE) ^ c);   /* 4C1D-4C20 */
    if (a) obj_play_inventory_sound(a, c);                  /* 4C23 */
    if ((a & 0x30) && (c & 0x30) == 0x30) obj_read_manuscript();   /* 4C26-4C2F CALL 5184 */
    if (a) hud_draw_objects(a, c);                          /* 4C32-4C34 CALL NZ,4D30 */
    for (p = D64_OBJ_OBJECTS; rb(p) != 0xFF; p = (uint16_t)(p + 5))   /* 4C37-4C44 */
        wb(p, (uint8_t)(rb(p) & 0xFE));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4BEC(void)
{
    uint16_t p;
    obj_update_inventory();
    for (p = D64_OBJ_OBJECTS; rb(p) != 0xFF; p = (uint16_t)(p + 5)) {}
    SET_HL(p);                                              /* the FF that ended the loop */
    SET_BC(5);
    cpu.a = 0xFF;
    cpu.zf = 1;
    z80_ret();
}
CHEQUEO(r_4BEC, R_A | R_ZF | R_BC | R_HL)
#endif

/* 4BBB hud_blink_yes_no (PC 1000:53B4): prints at txt_cursor := A41Dh either "   " (ai_sleep_answer_count
 * odd) or "S:N" (even), so the prompt blinks while Adso waits for the answer.  IX kept.  Caller 59E2. */
void hud_blink_yes_no(void)
{
    ww(D64_TXT_CURSOR, 0xA41D);                             /* 4BBD-4BC0 */
    if (rb(D64_AI_SLEEP_ANSWER_COUNT) & 1)                  /* 4BC3-4BC8 */
        (void)txt_print_inline(0x4BCD);                     /* 4BCA CALL 4B44 <20 20 20 FF> */
    else
        (void)txt_print_inline(0x4BD7);                     /* 4BD4 CALL 4B44 <53 3A 4E FF> */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4BBB(void)
{
    hud_blink_yes_no();
    cpu.a = 0xFF;
    cpu.zf = 1;
    z80_ret();
}
CHEQUEO(r_4BBB, R_A | R_ZF | R_IX)

/* ==== the table ====================================================================================== */

const traducida_t traducidas_logica_a[] = {
    { 0x3AAF, "vid_spiral_wipe", w_3AAF, r_3AAF },
    { 0x3AC3, "vid_spiral_pass", w_3AC3, r_3AC3 },
    { 0x3B2A, "vid_spiral_put", w_3B2A, r_3B2A },
    { 0x3B3B, "obj_lamp_reset", w_3B3B, sin_resultados },
    { 0x3B66, "obj_malachi_leaves_key3", w_3B66, sin_resultados },
    { 0x3B7B, "obj_remove_glasses", w_3B7B, sin_resultados },
    { 0x3B9C, "chr_bernardo_arrives", w_3B9C, sin_resultados },
    { 0x3BAC, "chr_jorge_appears", w_3BAC, sin_resultados },
    { 0x3BBC, "chr_berengar_vanishes", w_3BBC, sin_resultados },
    { 0x3BD8, "chr_berengar_hooded", w_3BD8, r_3BD8 },
    { 0x3BE1, "util_store_dx_at_bx", w_3BE1, r_3BE1 },
    { 0x3BF3, "obj_jorge_drops_book", w_3BF3, r_3BF3 },
    { 0x3BFD, "obj_abbot_drops_parchment", w_3BFD, r_3BFD },
    { 0x3C1B, "obj_abbot_wants_parchment", w_3C1B, sin_resultados },
    { 0x3C1C, "obj_place_parchment", w_3C1C, sin_resultados },
    { 0x3C26, "obj_place_parchment_unused", w_3C26, sin_resultados },
    { 0x3C30, "obj_book_to_jorge", w_3C30, sin_resultados },
    { 0x3C3F, "obj_place_lamp", w_3C3F, r_3C3F },
    { 0x3C52, "obj_place_key1", w_3C52, sin_resultados },
    { 0x3C5C, "obj_remove_key1", w_3C5C, sin_resultados },
    { 0x3C66, "obj_place_key3", w_3C66, sin_resultados },
    { 0x3C70, "obj_place_glasses", w_3C70, sin_resultados },
    { 0x3C7A, "obj_remove_key1_unused", w_3C7A, sin_resultados },
    { 0x3C8F, "game_idle_camera_check", w_3C8F, r_3C8F },
    { 0x3CAE, "ai_jorge_book_talk_with_gloves", w_3CAE, r_3CAE },
    { 0x3CC5, "game_camera_select", w_3CC5, sin_resultados },
    { 0x3CFE, "game_speed_default", w_3CFE, r_3CFE },
    { 0x3D01, "game_speed_set", w_3D01, sin_resultados },
    { 0x3D05, "util_return_zero", w_3D05, r_3D05 },
    { 0x3D07, "game_set_c004_inline", w_3D07, r_3D07 },
    { 0x3D0F, "game_camera_from_ch_unused", w_3D0F, r_3D0F },
    { 0x3D15, "game_camera_update", w_3D15, r_3D15 },
    { 0x3D3C, "ai_lamp_tick", w_3D3C, r_3D3C },
    { 0x3D6A, "ai_night_end_tick", w_3D6A, r_3D6A },
    { 0x3D87, "obj_jorge_takes_book", w_3D87, sin_resultados },
    { 0x3DA8, "game_compute_percentage", w_3DA8, r_3DA8 },
    { 0x3DEE, "game_update_bonus_and_poison", w_3DEE, sin_resultados },
    { 0x3EE6, "ai_stop_hour_countdown", w_3EE6, r_3EE6 },
    { 0x3EEF, "ai_malaquias_rise", w_3EEF, sin_resultados },
    { 0x3F15, "ai_check_guillermo_at_mass", w_3F15, r_3F15 },
    { 0x3F22, "ai_check_guillermo_at_refectory", w_3F22, r_3F22 },
    { 0x3F2D, "ai_check_guillermo_at", w_3F2D, r_3F2D },
    { 0x3F56, "ai_parchment_check", w_3F56, r_3F56 },
    { 0x3F92, "chr_path_room_to_marked", w_3F92, r_3F92 },
    { 0x3F9E, "chr_path_room_search", w_3F9E, r_3F9E },
    { 0x40EB, "chr_adso_step_guillermo_dir", w_40EB, sin_resultados },
    { 0x40FA, "chr_adso_step_prepare", w_40FA, r_40FA },
    { 0x410D, "chr_adso_step_aside", w_410D, sin_resultados },
    { 0x4164, "chr_adso_step_restore", w_4164, sin_resultados },
    { 0x41A8, "chr_cmd_write_one_step", w_41A8, r_41A8 },
    { 0x41B8, "chr_cmd_turn_and_step", w_41B8, r_41B8 },
    { 0x41C9, "chr_cmd_write_path", w_41C9, r_41C9 },
    { 0x4292, "chr_cmd_write_step", w_4292, r_4292 },
    { 0x432C, "chr_cmd_write_turn", w_432C, r_432C },
    { 0x434F, "chr_cmd_generate", w_434F, r_434F },
    { 0x438F, "chr_path_floor_to_screen", w_438F, r_438F },
    { 0x4399, "chr_path_floor_search", w_4399, r_4399 },
    { 0x441E, "chr_path_floor_cell_ptr", w_441E, r_441E },
    { 0x4477, "util_delay_cx", w_4477, r_4477 },
    { 0x447D, "spr_draw_all", w_447D, r_447D },
    { 0x4717, "spr_mirror_byte", w_4717, r_4717 },
    { 0x47E7, "spr_blit_to_screen", w_47E7, sin_resultados },
    { 0x4886, "spr_rect_union_old", w_4886, r_4886 },
    { 0x48EB, "util_mul_al_bx", w_48EB, r_48EB },
    { 0x48FC, "spr_rect_tile_align", w_48FC, r_48FC },
    { 0x491B, "spr_tile_unmark_hook", w_491B, sin_resultados },
    { 0x4925, "spr_draw_tiles_in_depth_range", w_4925, sin_resultados },
    { 0x49E5, "spr_tile_to_buffer", w_49E5, sin_resultados },
    { 0x4A5F, "iso_draw_room_spiral", w_4A5F, sin_resultados },
    { 0x4AC8, "iso_draw_tile", w_4AC8, r_4AC8 },
    { 0x4B43, "util_ret_530a", w_4B43, sin_resultados },
    { 0x4B44, "txt_print_inline", w_4B44, r_4B44 },
    { 0x4B57, "hud_clear_phrase_area", w_4B57, sin_resultados },
    { 0x4B71, "hud_say_now", w_4B71, r_4B71 },
    { 0x4B7C, "hud_say", w_4B7C, r_4B7C },
    { 0x4BB2, "txt_skip_strings", w_4BB2, r_4BB2 },
    { 0x4BBB, "hud_blink_yes_no", w_4BBB, r_4BBB },
    { 0x4BDE, "obj_play_inventory_sound", w_4BDE, r_4BDE },
    { 0x4BEC, "obj_update_inventory", w_4BEC, r_4BEC },
    { 0, NULL, NULL, NULL }
};
#endif

