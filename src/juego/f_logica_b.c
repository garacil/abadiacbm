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

/* abadia64ks, group logica_b: the CPC 64 KiB game's functions at 4C46-5FFF translated to C, with their
 * wrappers and result checks for the hybrid host (table traducidas_logica_b).
 *
 * The range holds the per-frame inventory (pick up, drop, key permissions, the score-bar object slots),
 * the mirror reflection, the clock and the score bar (hour name, day numeral, obsequium), the mirror
 * numeral of the manuscript, and the behaviour scripts of the monks and the camera/bonus logic.  The
 * scripts are written in the original's inline postfix language (RST 08h test = 391Eh, RST 10h
 * assignment = 38FCh, variable table 386Ah): here they are C expressions.  Comparisons give 00 (true)
 * or FFh (false); the operator 26h is a bitwise OR (a logical AND of such truths), 2Ah a bitwise AND (a
 * logical OR, or a bit test with a mask).  Each RST 10h assignment also leaves the address of its
 * variable in the operand at 390Dh (scr_set).  The labels parch_* that the function map gave to
 * 51F3-5600 come from a wrong 6128 alignment: that code is the scripts (the 64K game has no ending
 * parchment in memory).
 *
 * Every call is a C call (juego64.h).  The inline phrase byte of each `CALL 4B7C / 4B71 <db phrase>` is
 * written as the constant it is (its 64K address in the comment). */
#include <stdio.h>
#include <string.h>
#include "juego64.h"
#include "datos_logica_b.h"

/* sys_key_down as the scripts use it: true (NZ) while CPC key `key` is down */
static bool key_down(uint8_t key)
{
    uint8_t code;
    return sys_key_down(key, &code) != 0;
}

/* 16A1: the play area filled with FFh */
static void play_area_ff(void)
{
    uint16_t de;
    (void)vid_fill_play_area_ff(&de);
}

/* ================================================================ objects */

/* 4EA5 obj_front_position (PC 1000:57C0): the cell in front of the character of holder h: x + 2 dx,
 * y + 2 dy from the step table (8 bytes per orientation) and the character's height; stored into the
 * operands of obj_pick_up_objects (obj_front_x/y/z).  In: IX = holder.  Out: A = height, C = x, B = y
 * (DE = address of the height, HL = step table entry + 1). */
uint8_t obj_front_position(uint16_t h, uint8_t *x, uint8_t *y)
{
    uint16_t c = (uint16_t)(rw((uint16_t)(h + 1)) - 1);                 /* the orientation, before x */
    uint16_t t = (uint16_t)(D64_CHR_STEP_TABLE + (uint8_t)(rb(c) * 8)); /* 22E7: HL + 8A (8-bit) */
    uint8_t z;
    *x = (uint8_t)(rb((uint16_t)(c + 1)) + rb(t) + rb(t));
    wb(D64_OBJ_FRONT_X, *x);
    *y = (uint8_t)(rb((uint16_t)(c + 2)) + rb((uint16_t)(t + 1)) + rb((uint16_t)(t + 1)));
    wb(D64_OBJ_FRONT_Y, *y);
    z = rb((uint16_t)(c + 3));
    wb(D64_OBJ_FRONT_Z, z);
    return z;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4EA5(void)
{
    uint8_t x, y, z;
    uint16_t c = (uint16_t)(rw((uint16_t)(cpu.ix + 1)) - 1);
    z = obj_front_position(cpu.ix, &x, &y);
    cpu.a = z; cpu.c = x; cpu.b = y;
    SET_DE((uint16_t)(c + 3));
    SET_HL((uint16_t)(D64_CHR_STEP_TABLE + (uint8_t)(rb(c) * 8) + 1));
    z80_ret();
}

static int r_4EA5(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = resultado_a(cz, zz, msg, n);
    ok &= cz->b == zz->b && cz->c == zz->c && cz->d == zz->d && cz->e == zz->e && cz->h == zz->h && cz->l == zz->l;
    if (!ok) snprintf(msg + strlen(msg), n - strlen(msg), " BC/DE/HL");
    return ok;
}
#endif

/* 4C46 obj_pick_up_objects (PC 1000:5463): for every holder from h to the FF entry whose counter +6 runs
 * out (decremented to FFh, then back to 0): the cell in front of it (obj_front_position) and every object
 * record not taken this frame, not hidden, allowed by the holder's masks (+4 for +0, +5 for +3, minus what
 * it has) and lying there (its own position, or its holder's character position when held, then only if
 * the taker is not locked: holder +0 bit 0 into obj_holder_locked): the object is taken from its old
 * holder, spr_mark_leaving, record +0 := 81h and +2/+3 := the new holder, holder +6 := 10h, holder bits
 * set.  One object per holder per frame.  (The Z80 keeps the object's bit 8000h >> n in HL'.)
 * In: IX = first holder.  Out: IX = the FF entry. */
uint16_t obj_pick_up_objects(uint16_t h)
{
    for (; rb(h) != 0xFF; h = (uint16_t)(h + 7)) {
        uint16_t cnt = (uint16_t)(h + 6), mask, bit, spr, obj;
        uint8_t x, y;
        wb(cnt, (uint8_t)(rb(cnt) - 1));
        if (rb(cnt) != 0xFF) continue;
        wb(cnt, (uint8_t)(rb(cnt) + 1));
        obj_front_position(h, &x, &y);
        mask = (uint16_t)((uint8_t)((rb((uint16_t)(h + 5)) ^ rb((uint16_t)(h + 3))) & rb((uint16_t)(h + 5))) << 8
                          | (uint8_t)((rb((uint16_t)(h + 4)) ^ rb(h)) & rb((uint16_t)(h + 4))));
        wb(D64_OBJ_HOLDER_LOCKED, (uint8_t)(rb(h) & 0x01));
        bit = 0x8000;
        spr = D64_OBJ_SPRITES;
        obj = D64_OBJ_OBJECTS;
        for (;;) {
            bool wanted = (mask & 0x8000) != 0;
            uint8_t f = rb(obj);
            mask = (uint16_t)(mask << 1);
            if (wanted && !(f & 0x01) && !(f & 0x40)) {
                uint8_t ox = rb((uint16_t)(obj + 2)), oy = rb((uint16_t)(obj + 3)), oz = rb((uint16_t)(obj + 4));
                uint16_t owner = (uint16_t)(oy << 8 | ox);          /* the holder entry when held */
                bool ok = true;
                if (f & 0x80) {
                    if (rb(D64_OBJ_HOLDER_LOCKED)) ok = false;
                    else {
                        uint16_t c = rw((uint16_t)(owner + 1));
                        ox = rb(c); oy = rb((uint16_t)(c + 1)); oz = rb((uint16_t)(c + 2));
                    }
                }
                if (ok && (uint8_t)(oz - rb(D64_OBJ_FRONT_Z)) < 5 && ox == rb(D64_OBJ_FRONT_X) && oy == rb(D64_OBJ_FRONT_Y)) {
                    if (rb(obj) & 0x80) {                           /* taken from its holder */
                        wb(owner, (uint8_t)(rb(owner) ^ (uint8_t)bit));
                        wb((uint16_t)(owner + 3), (uint8_t)(rb((uint16_t)(owner + 3)) ^ (uint8_t)(bit >> 8)));
                    }
                    (void)spr_mark_leaving(spr);
                    wb((uint16_t)(obj + 2), (uint8_t)h);
                    wb((uint16_t)(obj + 3), (uint8_t)(h >> 8));
                    wb(obj, 0x81);
                    wb(cnt, 0x10);
                    wb(h, (uint8_t)(rb(h) | (uint8_t)bit));
                    wb((uint16_t)(h + 3), (uint8_t)(rb((uint16_t)(h + 3)) | (uint8_t)(bit >> 8)));
                    break;
                }
            }
            obj = (uint16_t)(obj + 5);
            spr = (uint16_t)(spr + 0x14);
            bit = (uint16_t)(bit >> 1);
            if (rb(obj) == 0xFF) break;
        }
    }
    return h;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4C46(void)
{
    cpu.ix = obj_pick_up_objects(cpu.ix);
    cpu.a = 0xFF; cpu.zf = 1;
    z80_ret();
}

static int r_4C46(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    if (cz->ix == zz->ix) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " IX C %04X Z80 %04X", cz->ix, zz->ix);
    return 0;
}
#endif

/* 4D30 hud_draw_objects (PC 1000:55F0): redraws the object slots of the score bar whose bit is set in
 * changed (bit 7 = slot 0 .. bit 2 = slot 5), from the screen address C591h (slots 5 bytes apart, one more
 * after the third): an object held (bit of held) is drawn from its sprite (+5 width & 7Fh, +6 rows, +7/+8
 * graphics), else the slot is cleared (4 bytes x 12 rows).  Stops when no changed bit is left.
 * In: A = changed, C = held. */
void hud_draw_objects(uint8_t changed, uint8_t held)
{
    uint16_t scr = D64_SCR_OBJECT_SLOTS, spr = D64_OBJ_SPRITES;
    uint8_t slot;
    for (slot = 6; slot; --slot) {
        bool is_held = (held & 0x80) != 0, is_changed;
        held = (uint8_t)(held << 1);
        if (!changed) return;
        is_changed = (changed & 0x80) != 0;
        changed = (uint8_t)(changed << 1);
        if (is_changed) {
            uint16_t hl = scr;
            uint8_t r, i;
            if (!is_held) {
                for (r = 0x0C; r; --r) {
                    for (i = 0; i < 4; ++i) wscr((uint16_t)(hl + i), 0x00);
                    hl = vid_next_line(hl);
                }
            } else {                                                /* DJNZ loops: 0 counts 256 */
                uint8_t rows = rb((uint16_t)(spr + 6)), width = (uint8_t)(rb((uint16_t)(spr + 5)) & 0x7F);
                uint16_t g = rw((uint16_t)(spr + 7));
                r = rows;
                do {
                    uint16_t p = hl;
                    i = width;
                    do { wscr(p, rb(g)); ++p; ++g; } while (--i);
                    hl = vid_next_line(hl);
                } while (--r);
            }
        }
        scr = (uint16_t)(scr + 5);
        spr = (uint16_t)(spr + 0x14);
        if (slot == 4) scr = (uint16_t)(scr + 1);
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4D30(void) { hud_draw_objects(cpu.a, cpu.c); z80_ret(); }
#endif

/* 4D2A hud_draw_guillermo_objects (PC 1000:55E9): hud_draw_objects(FFh, objects of Guillermo): redraws
 * every slot.  Falls into 4D30. */
void hud_draw_guillermo_objects(void)
{
    hud_draw_objects(0xFF, rb(D64_GUILLERMO_OBJECTS));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4D2A(void) { hud_draw_guillermo_objects(); z80_ret(); }
#endif

/* 4D97 obj_update_key_permissions (PC 1000:5688): Adso's key 3 (bit 1 of his objects) -> bit 4 of his
 * door entry (292Dh); Guillermo's key 1 (bit 3) -> bit 0 and key 2 (bit 2) -> bit 2 of his (292Ah).
 * Out: A = Guillermo's new door byte. */
uint8_t obj_update_key_permissions(void)
{
    uint8_t c = (uint8_t)((rb(D64_OBJ_ADSO_OBJECTS) & 0x02) << 3), a;
    wb(D64_OBJ_DOOR_PERMISSIONS_ADSO, (uint8_t)((rb(D64_OBJ_DOOR_PERMISSIONS_ADSO) & 0xEF) | c));
    a = (uint8_t)(rb(D64_GUILLERMO_OBJECTS) & 0x0C);
    c = (uint8_t)((a & 0xFB) >> 3);
    a = (uint8_t)((a & 0x04) | c);
    a = (uint8_t)((rb(D64_OBJ_DOOR_PERMISSIONS) & 0xFA) | a);
    wb(D64_OBJ_DOOR_PERMISSIONS, a);
    return a;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4D97(void) { cpu.a = obj_update_key_permissions(); z80_ret(); }
#endif

/* 4DCD obj_drop_object (PC 1000:56CF): holder h drops its first object (highest bit of +3) when its
 * counter +6 runs out: in front of it (obj_front_position) if that floor cell, on the floor shown, inside
 * the height buffer, is empty, lower than 0Dh, at most 4 above the floor level and level with its three
 * neighbours (else nothing this time); at its character's own position when the floor or the buffer do
 * not allow the test.  Clears the holder's bits, +6 := 10h, writes the record (+4 height, +1 orientation
 * read at an address whose high byte is the height, as the original does, +2/+3 x/y, bit 7 cleared)
 * and redraws it (obj_redraw_one_object, a JP).  In: IX = holder. */
void obj_drop_object(uint16_t h)
{
    uint8_t a = rb((uint16_t)(h + 3)), n = 0, b = 8, x, y, z, base, height, orient;
    uint16_t cnt = (uint16_t)(h + 6), pos, t, bit, spr, obj;
    for (;;) {
        bool c = (a & 0x80) != 0;
        ++n;
        a = (uint8_t)(a << 1);
        if (c) break;
        if (--b == 0) return;
    }
    wb(D64_OBJ_DROP_INDEX, n);
    wb(cnt, (uint8_t)(rb(cnt) - 1));
    if (rb(cnt) != 0xFF) return;
    wb(cnt, (uint8_t)(rb(cnt) + 1));
    z = obj_front_position(h, &x, &y);
    base = iso_floor_base(z);
    wb(D64_OBJ_DROP_LEVEL, (uint8_t)(z - base));
    pos = (uint16_t)(y << 8 | x);
    {
        uint16_t yx = pos, idx, low, p;
        if (rb(D64_CHR_SHOWN_FLOOR) == base && !chr_to_hbuf_coords(&yx)) {
            uint8_t v, hc;
            p = iso_grid_cell_ptr((uint8_t)yx, (uint8_t)(yx >> 8), &idx, &low);
            v = rb(p);
            if (v & 0xF0) return;
            hc = (uint8_t)(v & 0x0F);
            if (hc >= 0x0D) return;
            if ((uint8_t)(hc - rb(D64_OBJ_DROP_LEVEL)) >= 5) return;
            if (hc != rb((uint16_t)(p - 1)) || hc != rb((uint16_t)(p - 0x18)) || hc != rb((uint16_t)(p - 0x19))) return;
            height = (uint8_t)(rb(D64_CHR_SHOWN_FLOOR) + hc);
        } else {                                                    /* 4E3B: at the character's position */
            uint16_t c = rw((uint16_t)(h + 1));
            pos = (uint16_t)(rb((uint16_t)(c + 1)) << 8 | rb(c));
            height = rb((uint16_t)(c + 2));
        }
    }
    n = rb(D64_OBJ_DROP_INDEX);
    t = (uint16_t)(rw((uint16_t)(h + 1)) - 1);
    t = (uint16_t)((t & 0x00FF) | height << 8);
    orient = (uint8_t)(rb(t) ^ 0x02);
    wb(cnt, 0x10);
    bit = 0x8000;
    for (a = n; --a; ) bit = (uint16_t)(bit >> 1);
    wb(h, (uint8_t)(~(uint8_t)bit & rb(h)));
    wb((uint16_t)(h + 3), (uint8_t)(~(uint8_t)(bit >> 8) & rb((uint16_t)(h + 3))));
    spr = D64_OBJ_SPRITES;
    obj = D64_OBJ_OBJECTS;
    for (a = n; --a; ) { spr = (uint16_t)(spr + 0x14); obj = (uint16_t)(obj + 5); }
    wb(obj, (uint8_t)(rb(obj) & 0x7F));
    wb((uint16_t)(obj + 4), height);
    wb((uint16_t)(obj + 1), orient);
    wb((uint16_t)(obj + 2), (uint8_t)pos);
    wb((uint16_t)(obj + 3), (uint8_t)(pos >> 8));
    obj_redraw_one_object(spr, obj);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4DCD(void) { obj_drop_object(cpu.ix); z80_ret(); }
#endif

/* 4DC3 obj_drop_on_space (PC 1000:56C4): when the space bar (CPC key 2Fh) is down, Guillermo drops an
 * object (falls into 4DCD). */
void obj_drop_on_space(void)
{
    if (!key_down(0x2F)) return;
    obj_drop_object(D64_OBJ_CHAR_OBJECTS);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4DC3(void) { obj_drop_on_space(); z80_ret(); }
#endif

/* ================================================================ the mirror */

/* 4FC9 iso_mirror_draw_callback (PC 1000:594D): the flip routine of the mirror image (chr_cur_flip,
 * called by chr_animate at 25AD with IX = the sprite): copies width x rows bytes (+5, +6) of the sprite's
 * graphics (+7/+8) into the buffer iso_mirror_buffer, points +7/+8 at it and jumps to
 * spr_flip_graphics_h with HL = buffer, C = width, B = rows. */
void iso_mirror_draw_callback(uint16_t spr)
{
    uint8_t width = rb((uint16_t)(spr + 5)), rows = rb((uint16_t)(spr + 6));
    uint16_t cnt = util_mul_al_bx(width, rows);
    uint16_t buf = rw(D64_ISO_MIRROR_BUFFER), src = rw((uint16_t)(spr + 7)), i;
    ww((uint16_t)(spr + 7), buf);
    i = 0;
    do { wb((uint16_t)(buf + i), rb((uint16_t)(src + i))); ++i; } while (i != cnt);   /* LDIR */
    spr_flip_graphics_h(buf, width, rows);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4FC9(void) { iso_mirror_draw_callback(cpu.ix); z80_ret(); }
#endif

/* 4F03 iso_mirror_reflect (PC 1000:5841): draws the mirror image of character chr (sprite spr) when the
 * height buffer is at the mirror room (origin 1Ch, 5Ch), the character is on the floor of base 16h
 * (height < base + 8), x in 20h..29h and y in 62h..6Bh: x := 42h - x (one less when bit 7 of +5),
 * orientation mirrored (XOR 2 when even), +0 XOR 2, chr_cur_flip := 4FC9, chr_cur_anim := anim, sprite
 * +0Bh bit 7, chr_animate; then the sprite's old position/size (+3/+4, +9/+0Ah) := the previous image's
 * (state+1, state+3) when one was shown, else the new ones; the state words := the new ones; the
 * character is restored.  The operands 4F9A/4FA2 (state+1), 4F9E/4FA6 (state+3), 4FA9 (state +0) and
 * 4FD9 (buf) are patched first.  In: HL = buf, BC = state, DE = anim, IX = spr, IY = chr.
 * Out: L = 00 (drawn) or FEh. */
uint8_t iso_mirror_reflect(uint16_t buf, uint16_t state, uint16_t anim, uint16_t spr, uint16_t chr)
{
    uint8_t z, base, x, y, orient, flags, o;
    uint16_t pos, size, old_pos, old_size;
    ww(D64_ISO_MIRROR_BUFFER, buf);
    if (rb(D64_CHR_HBUF_ORIGIN_X) != 0x1C) return 0xFE;
    if (rb(D64_CHR_HBUF_ORIGIN_Y) != 0x5C) return 0xFE;
    wb(D64_ISO_MIRROR_SHOWN, rb(state));
    ww(D64_ISO_MIRROR_OLD_POS_OP, (uint16_t)(state + 1));
    ww(D64_ISO_MIRROR_NEW_POS_OP, (uint16_t)(state + 1));
    ww(D64_ISO_MIRROR_OLD_SIZE_OP, (uint16_t)(state + 3));
    ww(D64_ISO_MIRROR_NEW_SIZE_OP, (uint16_t)(state + 3));
    z = rb((uint16_t)(chr + 4));
    base = iso_floor_base(z);
    if ((uint8_t)(z - base) >= 8) return 0xFE;
    if (base != 0x16) return 0xFE;
    x = rb((uint16_t)(chr + 2));
    if ((uint8_t)(x - 0x20) >= 0x0A) return 0xFE;
    y = rb((uint16_t)(chr + 3));
    if ((uint8_t)(y - 0x62) >= 0x0A) return 0xFE;
    orient = rb((uint16_t)(chr + 1));
    flags = rb(chr);
    wb(chr, (uint8_t)(flags ^ 0x02));
    wb((uint16_t)(chr + 2), (uint8_t)(0x21 - (uint8_t)(x - 0x21)));
    o = orient;
    if (!(o & 0x01)) o ^= 0x02;
    wb((uint16_t)(chr + 1), o);
    if (rb((uint16_t)(chr + 5)) & 0x80) wb((uint16_t)(chr + 2), (uint8_t)(rb((uint16_t)(chr + 2)) - 1));
    ww(D64_CHR_CUR_FLIP, D64_ISO_MIRROR_DRAW_CALLBACK);
    ww(D64_CHR_CUR_ANIM, anim);
    wb((uint16_t)(spr + 0x0B), (uint8_t)(rb((uint16_t)(spr + 0x0B)) | 0x80));
    chr_animate(chr, spr);
    pos = rw((uint16_t)(spr + 1));
    size = rw((uint16_t)(spr + 5));
    old_pos = rw(rw(D64_ISO_MIRROR_OLD_POS_OP));
    old_size = rw(rw(D64_ISO_MIRROR_OLD_SIZE_OP));
    ww(rw(D64_ISO_MIRROR_NEW_POS_OP), pos);
    ww(rw(D64_ISO_MIRROR_NEW_SIZE_OP), size);
    if (rb(D64_ISO_MIRROR_SHOWN) != 0xFE) { pos = old_pos; size = old_size; }
    wb((uint16_t)(spr + 3), (uint8_t)pos);
    wb((uint16_t)(spr + 4), (uint8_t)(pos >> 8));
    wb((uint16_t)(spr + 9), (uint8_t)size);
    wb((uint16_t)(spr + 0x0A), (uint8_t)(size >> 8));
    wb((uint16_t)(chr + 2), x);
    wb((uint16_t)(chr + 1), orient);
    wb(chr, flags);
    return 0x00;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4F03(void)
{
    uint16_t ix = cpu.ix, iy = cpu.iy;
    cpu.l = iso_mirror_reflect(HL, BC, DE, ix, iy);
    cpu.ix = ix; cpu.iy = iy;
    z80_ret();
}

static int r_4F03(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = 1;
    if (cz->l != zz->l) { ok = 0; snprintf(msg + strlen(msg), n - strlen(msg), " L C %02X Z80 %02X", cz->l, zz->l); }
    if (cz->ix != zz->ix || cz->iy != zz->iy) { ok = 0; snprintf(msg + strlen(msg), n - strlen(msg), " IX/IY"); }
    return ok;
}
#endif

/* 4EF4 iso_mirror_character (PC 1000:5828): [state] := iso_mirror_reflect(...); when not shown (FEh)
 * clears bit 7 of the sprite's +0Bh.  In: as 4F03. */
void iso_mirror_character(uint16_t buf, uint16_t state, uint16_t anim, uint16_t spr, uint16_t chr)
{
    uint8_t l = iso_mirror_reflect(buf, state, anim, spr, chr);
    wb(state, l);
    if (l != 0xFE) return;
    wb((uint16_t)(spr + 0x0B), (uint8_t)(rb((uint16_t)(spr + 0x0B)) & 0x7F));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4EF4(void)
{
    uint16_t ix = cpu.ix, iy = cpu.iy;
    iso_mirror_character(HL, BC, DE, ix, iy);
    cpu.ix = ix; cpu.iy = iy;
    z80_ret();
}

static int r_ixiy(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    if (cz->ix == zz->ix && cz->iy == zz->iy) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " IX/IY C %04X/%04X Z80 %04X/%04X", cz->ix, cz->iy, zz->ix, zz->iy);
    return 0;
}
#endif

/* 4ECA iso_mirror_update (PC 1000:57FF): while the mirror is closed (28DDh != 0), the reflections of
 * Guillermo (record 2B87, sprite 29A4, buffer 855C, state 28DE) and Adso (2B96, 29B8, 8656, 28E3). */
void iso_mirror_update(void)
{
    if (!rb(D64_OBJ_MIRROR_CLOSED)) return;
    iso_mirror_character(D64_ISO_MIRROR_BUF_GUILLERMO, D64_ISO_MIRROR_STATE_GUILLERMO, D64_CHR_ANIM_GUILLERMO,
                         D64_SPR_GUILLERMO, D64_CHR_GUILLERMO);
    iso_mirror_character(D64_ISO_MIRROR_BUF_ADSO, D64_ISO_MIRROR_STATE_ADSO, D64_CHR_ANIM_ADSO,
                         D64_SPR_ADSO, D64_CHR_ADSO);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4ECA(void)
{
    uint16_t ix = cpu.ix, iy = cpu.iy;
    bool closed = rb(D64_OBJ_MIRROR_CLOSED) != 0;
    iso_mirror_update();
    if (closed) { cpu.ix = D64_SPR_ADSO; cpu.iy = D64_CHR_ADSO; } else { cpu.ix = ix; cpu.iy = iy; }
    z80_ret();
}
#endif

/* ================================================================ the clock and the score bar */

/* 4FEF hud_scroll_hour_name (PC 1000:5980): once per frame while hud_hour_scroll_steps > 0: one step
 * less; the 12-byte box of the hour name (8 rows at E583h) scrolls 2 bytes left and a character is drawn
 * at its right (txt_cursor := B40Dh): a space in the first two steps, then the next letter of the name
 * (hud_hour_name_ptr). */
void hud_scroll_hour_name(void)
{
    uint8_t a = rb(D64_HUD_HOUR_SCROLL_STEPS), ch = 0x20, r, i;
    uint16_t hl;
    if (!a) return;
    --a;
    wb(D64_HUD_HOUR_SCROLL_STEPS, a);
    if (a < 7) {
        uint16_t p = rw(D64_HUD_HOUR_NAME_PTR);
        ch = rb(p);
        ww(D64_HUD_HOUR_NAME_PTR, (uint16_t)(p + 1));
    }
    ww(D64_TXT_CURSOR, D64_TXT_CURSOR_HOUR_NAME);
    hl = D64_SCR_HOUR_NAME;
    for (r = 8; r; --r) {
        for (i = 0; i < 0x0C; ++i) wscr((uint16_t)(hl - 2 + i), rscr((uint16_t)(hl + i)));   /* LDIR to HL-2 */
        hl = vid_next_line(hl);
    }
    (void)txt_draw_char(ch);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_4FEF(void) { hud_scroll_hour_name(); z80_ret(); }
#endif

/* 5028 ai_clock_init (PC 1000:59DC): a new game: game_day := [BF4F], game_hour := [BF4E] (the 64K game
 * keeps them as data).  Out: A = the hour. */
uint8_t ai_clock_init(void)
{
    wb(D64_GAME_DAY, rb(D64_GAME_START_DAY));
    wb(D64_GAME_HOUR, rb(D64_GAME_START_HOUR));
    return rb(D64_GAME_START_HOUR);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5028(void) { cpu.a = ai_clock_init(); z80_ret(); }
#endif

/* 5060 ai_clock_load_duration (PC 1000:5A23): ai_hour_frames_left := ai_hour_durations[7 (day-1) + hour]
 * << 8 (0 = only the scripts end the hour).  Out: HL = the value. */
uint16_t ai_clock_load_duration(void)
{
    uint8_t d = (uint8_t)(rb(D64_GAME_DAY) - 1);
    uint16_t p = (uint16_t)(D64_AI_HOUR_DURATIONS + (uint8_t)(7 * d));
    uint16_t v;
    p = (uint16_t)(p + rb(D64_GAME_HOUR));
    v = (uint16_t)(rb(p) << 8);
    ww(D64_AI_HOUR_FRAMES_LEFT, v);
    return v;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5060(void) { SET_HL(ai_clock_load_duration()); z80_ret(); }
#endif

/* 50D9 hud_draw_day_numeral (PC 1000:5ABF): one glyph of the day numeral, 2 bytes x 8 rows at scr:
 * code 2 'I' (AB49h), 1 'V' (AB39h), 0 blank (FF FF read again each row: the opcode at 50FEh becomes
 * DEC BC instead of INC BC).  In: HL = scr, DE -> code.  Out: HL + 2, DE + 1. */
void hud_draw_day_numeral(uint16_t scr, uint8_t code)
{
    uint16_t src = D64_HUD_GFX_ROMAN_I;
    uint8_t r;
    bool blank = false;
    wb(D64_HUD_DAY_GLYPH_STEP, 0x03);                               /* INC BC */
    if (code != 2) {
        src = D64_HUD_GFX_ROMAN_V;
        if (code == 0) {
            wb(D64_HUD_DAY_GLYPH_STEP, 0x0B);                       /* DEC BC */
            src = D64_HUD_GFX_ROMAN_BLANK;
            blank = true;
        }
    }
    for (r = 8; r; --r) {
        wscr(scr, rb(src));
        wscr((uint16_t)(scr + 1), rb((uint16_t)(src + 1)));
        if (!blank) src = (uint16_t)(src + 2);
        scr = vid_next_line(scr);
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_50D9(void)
{
    uint16_t hl = HL, de = DE;
    hud_draw_day_numeral(hl, rb(de));
    SET_HL((uint16_t)(hl + 2));
    SET_DE((uint16_t)(de + 1));
    z80_ret();
}

static int r_50D9(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = resultado_hl(cz, zz, msg, n);
    if (cz->d != zz->d || cz->e != zz->e) { ok = 0; snprintf(msg + strlen(msg), n - strlen(msg), " DE"); }
    return ok;
}
#endif

/* 50AF hud_set_and_draw_day (PC 1000:5A88): game_day := day and its three numeral glyphs (hud_roman_days
 * + 3 (day-1)) at ED09h; then game_hour := 0, hud_hour_scroll_steps := 9 and ai_clock_load_duration (the
 * 64K tail of the new day).  In: A = day. */
void hud_set_and_draw_day(uint8_t day)
{
    uint16_t g;
    uint8_t k;
    wb(D64_GAME_DAY, day);
    g = (uint16_t)(D64_HUD_ROMAN_DAYS + (uint8_t)(3 * (uint8_t)(day - 1)));
    for (k = 0; k < 3; ++k) hud_draw_day_numeral((uint16_t)(D64_SCR_DAY_NUMERAL + 2 * k), rb((uint16_t)(g + k)));
    wb(D64_GAME_HOUR, 0x00);
    wb(D64_HUD_HOUR_SCROLL_STEPS, 0x09);
    ai_clock_load_duration();
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_50AF(void) { hud_set_and_draw_day(cpu.a); z80_ret(); }
#endif

/* 5094 ai_clock_advance_hour (PC 1000:5A6A): hour + 1, hud_hour_scroll_steps := 9 and the duration;
 * after COMPLETAS: hud_hour_name_ptr := the first name, day + 1 (8 -> 1) and hud_set_and_draw_day (which
 * sets the hour 0).  The jump to 50B2 for day < 8 skips the store of the same day. */
void ai_clock_advance_hour(void)
{
    uint8_t a = (uint8_t)(rb(D64_GAME_HOUR) + 1);
    if (a != 7) {
        wb(D64_GAME_HOUR, a);
        wb(D64_HUD_HOUR_SCROLL_STEPS, 0x09);
        ai_clock_load_duration();
        return;
    }
    ww(D64_HUD_HOUR_NAME_PTR, D64_HUD_HOUR_NAMES);
    a = (uint8_t)(rb(D64_GAME_DAY) + 1);
    wb(D64_GAME_DAY, a);
    hud_set_and_draw_day(a < 8 ? a : 1);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5094(void) { ai_clock_advance_hour(); z80_ret(); }
#endif

/* 5035 ai_clock_redraw (PC 1000:59E7): the clock after a start: day palette for PRIMA..VISPERAS (hour-1
 * < 5), night palette otherwise, the day (hud_set_and_draw_day), game_hour := hour - 1,
 * hud_hour_name_ptr := the name of the hour (4B12h + 7 hour), and the hour entered again through
 * ai_clock_advance_hour (a JR). */
void ai_clock_redraw(void)
{
    uint8_t h1 = (uint8_t)(rb(D64_GAME_HOUR) - 1);
    if (h1 < 5) vid_palette_day();
    if (!(h1 < 5)) vid_palette_night();
    hud_set_and_draw_day(rb(D64_GAME_DAY));
    wb(D64_GAME_HOUR, h1);
    ww(D64_HUD_HOUR_NAME_PTR, (uint16_t)(D64_HUD_HOUR_NAMES + (uint8_t)(7 * (uint8_t)(h1 + 1))));
    ai_clock_advance_hour();
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5035(void) { ai_clock_redraw(); z80_ret(); }
#endif

/* 507D ai_clock_tick (PC 1000:5A49): once per frame: sys_key_pressed(6) and util_return_zero (the CPC's
 * 'Enter skips the hour' test, dead: always ZF=1), then ai_hour_frames_left counts down when not 0 and
 * the hour advances when it reaches 0. */
void ai_clock_tick(void)
{
    uint16_t f;
    {
        uint8_t code;
        (void)sys_key_pressed(0x06, &code);
    }
    if (!util_return_zero()) { ai_clock_advance_hour(); return; }
    f = rw(D64_AI_HOUR_FRAMES_LEFT);
    if (!f) return;
    --f;
    ww(D64_AI_HOUR_FRAMES_LEFT, f);
    if (f) return;
    ai_clock_advance_hour();
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_507D(void) { ai_clock_tick(); z80_ret(); }
#endif

/* 510C ai_timers_tick (PC 1000:5B06): once per frame: ai_clock_tick, ai_lamp_event := ai_lamp_tick(),
 * ai_night_ending := ai_night_end_tick().  BC, DE, HL preserved.  Out: A = ai_night_ending. */
uint8_t ai_timers_tick(void)
{
    uint8_t c;
    ai_clock_tick();
    wb(D64_AI_LAMP_EVENT, ai_lamp_tick());
    c = ai_night_end_tick();
    wb(D64_AI_NIGHT_ENDING, c);
    return c;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_510C(void)
{
    uint16_t bc = BC, de = DE, hl = HL;
    cpu.a = ai_timers_tick();
    SET_BC(bc); SET_DE(de); SET_HL(hl);
    z80_ret();
}

static int r_510C(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = resultado_a(cz, zz, msg, n);
    if (cz->b != zz->b || cz->c != zz->c || cz->d != zz->d || cz->e != zz->e || cz->h != zz->h || cz->l != zz->l) {
        ok = 0; snprintf(msg + strlen(msg), n - strlen(msg), " BC/DE/HL");
    }
    return ok;
}
#endif

/* 5164 hud_fill_bar (PC 1000:5B6D): writes pattern into n consecutive bytes of the screen from *scr,
 * 6 pixel rows each; *scr advances n.  In: A = n, D = pattern, HL = scr.  Out: HL. */
void hud_fill_bar(uint8_t n, uint8_t pattern, uint16_t *scr)
{
    for (; n; --n) {
        uint16_t hl = *scr;
        uint8_t r;
        for (r = 6; r; --r) { wscr(hl, pattern); hl = vid_next_line(hl); }
        *scr = (uint16_t)(*scr + 1);
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5164(void)
{
    uint16_t hl = HL;
    hud_fill_bar(cpu.a, cpu.d, &hl);
    SET_HL(hl);
    z80_ret();
}
#endif

/* 5129 hud_obsequium_sub (PC 1000:5B25): `CALL 5129 <db amount>`: hud_obsequium -= amount; on underflow
 * it becomes 0 and, unless the game is over, ai_abbot_state := 0Bh (the abbot expels Guillermo); then
 * the bar (CDB4h): obsequium/4 bytes 0Fh, one byte hud_obsequium_tail[obsequium & 3], the rest of the 8
 * bytes FFh.  In: the inline byte. */
void hud_obsequium_sub(uint8_t amount)
{
    uint8_t a = rb(D64_HUD_OBSEQUIUM), c, e;
    uint16_t scr = D64_SCR_OBSEQUIUM_BAR;
    if (a < amount) {
        if (!rb(D64_GAME_GUILLERMO_DEAD)) wb(D64_AI_ABBOT_STATE, 0x0B);
        a = 0;
    } else a = (uint8_t)(a - amount);
    wb(D64_HUD_OBSEQUIUM, a);
    e = rb((uint16_t)(D64_HUD_OBSEQUIUM_TAIL + (a & 0x03)));
    c = (uint8_t)(a >> 2);
    hud_fill_bar(c, 0x0F, &scr);
    hud_fill_bar(1, e, &scr);
    hud_fill_bar((uint8_t)(7 - c), 0xFF, &scr);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5129(void)
{
    uint16_t ret = rw(cpu.sp);
    ww(cpu.sp, (uint16_t)(ret + 1));                    /* POP HL / INC HL / PUSH HL: past the inline byte */
    hud_obsequium_sub(rb(ret));
    z80_ret();
}
#endif

/* 5124 hud_obsequium_minus_2 (PC 1000:5B20): hud_obsequium_sub(2) (the inline byte at 5127), the
 * reprimand of the abbot and Bernardo. */
void hud_obsequium_minus_2(void)
{
    hud_obsequium_sub(0x02);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5124(void) { hud_obsequium_minus_2(); z80_ret(); }
#endif

/* 5199 obj_set_mirror_numeral (PC 1000:5BAD): obj_mirror_numeral := n and its three letters
 * (obj_mirror_numerals + 3 (n-1): IXX, XIX, XXI) over the dictionary word at B59Eh, so phrase 00 shows the
 * stair numeral.  In: A = n. */
void obj_set_mirror_numeral(uint8_t n)
{
    uint16_t src = (uint16_t)(D64_OBJ_MIRROR_NUMERALS + (uint8_t)(3 * (uint8_t)(n - 1)));
    uint8_t i;
    wb(D64_OBJ_MIRROR_NUMERAL, n);
    for (i = 0; i < 3; ++i) wb((uint16_t)(D64_TXT_WORD_AAA + i), rb((uint16_t)(src + i)));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5199(void) { obj_set_mirror_numeral(cpu.a); z80_ret(); }
#endif

/* 5184 obj_read_manuscript (PC 1000:5B93): Guillermo holds the glasses and the parchment: the stair
 * numeral is chosen once at random (LD A,R at 518Ah: the platform's random byte; R AND 3, 0 -> 1) and
 * set again every time, then phrase 00 'SECRETUM FINIS AFRICAE...' (hud_say, inline byte 5197h).
 * (The PC version had replaced the random read by a RET: always 1.) */
void obj_read_manuscript(void)
{
    uint8_t a = rb(D64_OBJ_MIRROR_NUMERAL);
    if (!a) {
        a = (uint8_t)(plat_aleatorio() & 0x03);
        if (!a) a = 1;
    }
    obj_set_mirror_numeral(a);
    (void)hud_say(0x00);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5184(void)
{
    /* the R the Z80 reads at 518Ah: LD A,(nn), AND A, JR NZ and the two fetches of LD A,R after the entry */
    cpu.r = (uint8_t)((cpu.r & 0x80) | ((cpu.r + 5) & 0x7F));
    obj_read_manuscript();
    z80_ret();
}
#endif

/* ================================================================ the scripts */

/* RST 10h <var> <expr> (38FCh): the operand at 390Dh := the address of the variable (from the table at
 * 386Ah), then the variable := the value of the expression. */
static void scr_set(uint16_t var, uint8_t v)
{
    ww(D64_AI_SCRIPT_DEST_PTR, var);
    wb(var, v);
}

/* 51E7 game_update_camera_and_bonus (PC 1000:3F72): chooses the character the idle camera follows
 * (ai_camera_target: 4 Berengario, 3 abbot, 2 Malaquias, 5 Severino, else 0 Guillermo) and sets bonus
 * bits in game_bonus / game_bonus2. */
void game_update_camera_and_bonus(void)
{
    if ((rb(D64_AI_BERENGAR_DEST) == 0xFD && rb(D64_BERENGAR_X) < 0x50 && rb(D64_AI_BERENGAR_SLOT_BUSY) == 0)
        || rb(D64_AI_BERENGAR_DEST) == 0xFE) {                                          /* 51E7 */
        scr_set(D64_AI_CAMERA_TARGET, 0x04);                                            /* 51F9 */
        return;
    }
    if ((rb(D64_GAME_HOUR) == 0x03 && rb(D64_AI_ABBOT_REACHED) >= 0x02) || rb(D64_AI_ABBOT_STATE) == 0x15
        || rb(D64_AI_PARCHMENT_REPORTED) == 0x01 || rb(D64_AI_ABBOT_STATE) == 0x0B) {    /* 51FD */
        scr_set(D64_AI_CAMERA_TARGET, 0x03);                                            /* 5213 */
        return;
    }
    if (rb(D64_AI_MALACHI_DEST) == 0xFE || (rb(D64_GAME_HOUR) == 0x05 && rb(D64_AI_MALACHI_STATE) < 0x06)) {   /* 5217 */
        scr_set(D64_AI_CAMERA_TARGET, 0x02);                                            /* 5226 */
        return;
    }
    if (rb(D64_AI_SEVERIN_DEST) == 0xFF) {                                              /* 522A */
        scr_set(D64_AI_CAMERA_TARGET, 0x05);                                            /* 5231 */
        return;
    }
    scr_set(D64_AI_CAMERA_TARGET, 0x00);                                                /* 5235 */
    if ((rb(D64_GUILLERMO_OBJECTS) & 0x10) == 0x10) {                                   /* 5238 the parchment */
        if (rb(D64_GAME_DAY) == 0x03 && rb(D64_GAME_HOUR) == 0x00)                      /* 5240 */
            scr_set(D64_GAME_BONUS, (uint8_t)(rb(D64_GAME_BONUS) | 0x10));              /* 524A */
        if ((rb(D64_GUILLERMO_OBJECTS) & 0x20) == 0x20)                                 /* 524F the glasses */
            scr_set(D64_GAME_BONUS, (uint8_t)(rb(D64_GAME_BONUS) | 0x01));              /* 5259 */
        if (rb(D64_ISO_ROOM_NUMBER) == 0x0D && rb(D64_AI_CAMERA_TARGET) == 0x00)        /* 525E the abbot's cell */
            scr_set(D64_GAME_BONUS, (uint8_t)(rb(D64_GAME_BONUS) | 0x20));              /* 5268 */
    }
    if (rb(D64_GAME_HOUR) == 0x00 && rb(D64_GUILLERMO_X) < 0x60)                        /* 526E */
        scr_set(D64_GAME_BONUS2, (uint8_t)(rb(D64_GAME_BONUS2) | 0x01));                /* 5278 */
    if (rb(D64_GUILLERMO_Z) >= 0x16) {                                                  /* 527D the library */
        if ((rb(D64_GUILLERMO_OBJECTS) & 0x20) == 0x20)                                 /* 5283 */
            scr_set(D64_GAME_BONUS2, (uint8_t)(rb(D64_GAME_BONUS2) | 0x80));            /* 528D */
        if ((rb(D64_GAME_ADSO_LAMP) & 0x80) == 0x80)                                    /* 5293 */
            scr_set(D64_GAME_BONUS2, (uint8_t)(rb(D64_GAME_BONUS2) | 0x20));            /* 529D */
        scr_set(D64_GAME_BONUS2, (uint8_t)(rb(D64_GAME_BONUS2) | 0x10));                /* 52A3 */
    }
    if (rb(D64_ISO_ROOM_NUMBER) == 0x72)                                                /* 52A8 the mirror room */
        scr_set(D64_GAME_BONUS, (uint8_t)(rb(D64_GAME_BONUS) | 0x02));                  /* 52AE */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_51E7(void) { game_update_camera_and_bonus(); z80_ret(); }
#endif

/* 52B4 ai_malachi_think (PC 1000:406D, 40A8, 40B3, 41FE): the script of Malaquias (chr = IY, his record;
 * places = IX, his places table).  Dead or dying, or the abbot expelling Guillermo: still; noche and
 * completas: his cell; visperas: takes key 3, chases Guillermo out of the upper floors and warns the
 * abbot, closes the left-wing doors, kitchen, church, day 5 dies; prima: church; tercia: his desk or, day 5,
 * Severino's cell; the other hours at his desk blocking the passage to the library. */
void ai_malachi_think(uint16_t chr, uint16_t places)
{
    if (rb(D64_AI_MALACHI_DYING) == 2) { ai_stay(); return; }                      /* 52B4 */
    if (rb(D64_AI_MALACHI_DYING) == 1) {                                                /* 52BD */
        ai_malaquias_rise();                                                              /* 52C3 ai_malaquias_rise */
        ai_stay();
        return;
    }
    if (rb(D64_AI_ABBOT_STATE) == 0x0B) { ai_stay(); return; }                      /* 52C9 */
    if (rb(D64_GAME_HOUR) == 0 || rb(D64_GAME_HOUR) == 6) {                             /* 52D2 */
        scr_set(D64_AI_MALACHI_DEST, 0x07);                                             /* 52DC his cell */
        scr_set(D64_AI_MALACHI_STATE, 0x08);
        return;
    }
    if (rb(D64_GAME_HOUR) == 5) {                                                       /* 52E3 visperas */
        if (rb(D64_AI_MALACHI_STATE) == 0x0C) {                                         /* 52EA */
            scr_set(D64_AI_MALACHI_DEST, 0xFE);                                         /* 52F0 to the abbot */
            if (rb(D64_AI_MALACHI_REACHED) == 0xFE) {                                   /* 52F4 */
                scr_set(D64_AI_ABBOT_STATE, 0x0B);                                      /* 52FB */
                scr_set(D64_AI_MALACHI_STATE, 0x06);
            }
            return;
        }
        if (rb(D64_AI_MALACHI_STATE) == 0) {                                            /* 5302 */
            scr_set(D64_OBJ_MALACHI_TAKEMASK, 0x02);                                    /* 5308 may take key 3 */
            scr_set(D64_AI_MALACHI_DEST, 0x06);                                         /* 530B the key table */
            if (rb(D64_AI_MALACHI_REACHED) != 0x06) return;                             /* 530E */
            scr_set(D64_AI_MALACHI_STATE, 0x02);                                        /* 5314 */
        }
        if (rb(D64_AI_MALACHI_STATE) < 0x04) {                                          /* 531A */
            if (!(rb(D64_GUILLERMO_Z) >= 0x0C)) {                                       /* 5320 Guillermo downstairs */
                scr_set(D64_AI_MALACHI_STATE, 0x04);                                    /* 532C */
                return;
            }
            scr_set(D64_AI_MALACHI_DEST, 0xFF);                                         /* 5326 follows Guillermo */
            if (rb(D64_AI_MALACHI_STATE) == 0x02) {                                     /* 5330 */
                if (ai_guillermo_is_close(chr)) {                                   /* 5336 */
                    hud_say_now(0x09);                                            /* 533B DEBEIS ABANDONAR EDIFICIO */
                    scr_set(D64_AI_MALACHI_STATE, 0x03);
                    scr_set(D64_AI_MALACHI_WARN_COUNT, 0x00);
                }
                return;
            }
            if (rb(D64_AI_MALACHI_STATE) == 0x03) {                                     /* 5346 */
                scr_set(D64_AI_MALACHI_WARN_COUNT, (uint8_t)(rb(D64_AI_MALACHI_WARN_COUNT) + 1));   /* 534C */
                if (rb(D64_AI_MALACHI_WARN_COUNT) >= 0xFA) {                            /* 5351 */
                    hud_say_now(0x0A);                                            /* 5358 ADVERTIRE AL ABAD */
                    scr_set(D64_AI_MALACHI_STATE, 0x0C);
                }
                return;
            }
        }
        if (rb(D64_AI_MALACHI_STATE) == 0x04) {                                         /* 5360 */
            scr_set(D64_AI_MALACHI_DEST, 0x04);                                         /* 5366 the left-wing doors */
            if (rb(D64_AI_MALACHI_REACHED) == 0x04) {                                   /* 5369 */
                if (rb(D64_BERENGAR_X) < 0x62 && rb(D64_AI_BERENGAR_SLOT_BUSY) == 0) {  /* 536F */
                    ai_stay();
                    return;
                }
                scr_set(D64_AI_MALACHI_STATE, 0x05);                                    /* 537A */
                scr_set(D64_OBJ_DOOR_WING1, (uint8_t)(rb(D64_OBJ_DOOR_WING1) & 0x7F));  /* 537D closes the doors */
                scr_set(D64_OBJ_DOOR_WING2, (uint8_t)(rb(D64_OBJ_DOOR_WING2) & 0x7F));
            }
            return;
        }
        if (rb(D64_AI_MALACHI_STATE) == 0x05) {                                         /* 5388 */
            scr_set(D64_AI_MALACHI_DEST, 0x05);                                         /* 538E the kitchen */
            scr_set(D64_OBJ_DOOR_CHECK_MASK, 0xDF);
            if (rb(D64_GUILLERMO_X) < 0x60) scr_set(D64_AI_MALACHI_STATE, 0x0C);        /* 5395 */
            (void)ai_next_state_on_arrival(places);                                       /* 539E JP 39E5 */
            return;
        }
        if (rb(D64_AI_MALACHI_STATE) == 0x06) {                                         /* 53A1 */
            scr_set(D64_AI_MALACHI_DEST, 0x00);                                         /* 53A7 the church */
            (void)ai_next_state_on_arrival(places);                                       /* 53AA (state 7 goes on below) */
        }
        if (rb(D64_AI_MALACHI_STATE) == 0x0B) {                                         /* 53AD */
            if (rb(D64_TXT_PHRASE_BUSY) == 0) scr_set(D64_AI_MALACHI_DYING, 0x01);      /* 53B3 */
            return;
        }
        if (rb(D64_AI_MALACHI_STATE) == 0x07) {                                         /* 53BD */
            if (rb(D64_GAME_DAY) != 0x05) return;                                       /* 53C3 */
            if (rb(D64_ISO_ROOM_NUMBER) == 0x22 || rb(D64_ISO_ROOM_NUMBER) == 0x23) {   /* 53C9 */
                scr_set(D64_AI_MALACHI_REACHED, 0x01);                                  /* 53D3 */
                scr_set(D64_AI_MALACHI_STATE, 0x0B);
                hud_say_now(0x1F);                                                /* 53D9 ERA VERDAD, TENIA EL PODER... */
            }
        }
        return;
    }
    if (rb(D64_GAME_HOUR) == 1) {                                                       /* 53DF prima */
        scr_set(D64_AI_MALACHI_STATE, 0x09);                                            /* 53E5 */
        scr_set(D64_AI_MALACHI_DEST, 0x00);
        return;
    }
    if (rb(D64_AI_MALACHI_REACHED) == 0x02) {                                           /* 53EC at his desk */
        scr_set(D64_AI_MALACHI_STATE, 0x00);                                            /* 53F2 */
        scr_set(D64_OBJ_MALACHI_TAKEMASK, 0x00);
        obj_malachi_leaves_key3();                                                              /* 53F8 obj_malachi_leaves_key3 */
    }
    if (rb(D64_AI_MALACHI_STATE) == 0) {                                                /* 53FB */
        if (!ai_guillermo_is_close(chr)) {                                          /* 5402 */
            scr_set(D64_AI_MALACHI_DEST, 0x02);                                         /* 5465 */
            return;
        }
        if (rb(D64_AI_MALACHI_DEST) != 0x03) {                                          /* 5408 */
            (void)chr_cmd_discard(chr);                                                   /* 5455 */
            if (!key_down(0x00)) { ai_stay(); return; }                     /* 5458 the advance key */
            scr_set(D64_AI_MALACHI_DEST, 0x03);                                         /* 5461 blocks the passage */
            return;
        }
        if (!(rb(D64_AI_MONK_FLAGS) & 0x80)) {                                          /* 540E */
            if (rb(D64_GUILLERMO_Y) < 0x38) {                                           /* 5415 */
                scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x80));    /* 541B */
                hud_say_now(0x33);                                                /* 5421 LO SIENTO, VENERABLE HERMANO... */
            }
            return;
        }
        if (!(rb(D64_AI_MONK_FLAGS) & 0x40)) {                                          /* 5427 */
            if (rb(D64_GAME_DAY) == 0x02 && rb(D64_TXT_PHRASE_BUSY) == 0) {             /* 542E */
                scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x40));    /* 5436 */
                (void)hud_say(0x34);                                                    /* 543C SI LO DESEAIS, BERENGARIO... */
            }
            return;
        }
        if (!(rb(D64_AI_MONK_FLAGS) & 0x10)) {                                          /* 5443 */
            /* 5402 found Guillermo close and nothing moved since: this test is always true (544F is dead,
             * as in the PC's 4290) */
            if (ai_guillermo_is_close(chr)) return;                                 /* 5449 */
            scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x10));        /* 544F */
        }
        return;
    }
    if (rb(D64_GAME_HOUR) != 2) return;                                                 /* 5469 tercia */
    if (rb(D64_AI_MALACHI_STATE) == 0x09 && rb(D64_GAME_DAY) == 0x05) {                 /* 546F */
        scr_set(D64_AI_MALACHI_DEST, 0x08);                                             /* 5479 Severino's cell */
        if (rb(D64_AI_MALACHI_REACHED) == 0x08 && rb(D64_AI_SEVERIN_REACHED) == 0x02) { /* 547C */
            scr_set(D64_AI_SEVERIN_SLOT_BUSY, 0x01);                                    /* 5486 */
            scr_set(D64_AI_MALACHI_STATE, 0x0A);
        }
        return;
    }
    scr_set(D64_AI_MALACHI_STATE, 0x0A);                                                /* 548D */
    scr_set(D64_AI_MALACHI_DEST, 0x02);
}

#ifndef JUEGO_PURO  /* the hybrid host */
/* the scripts' wrappers: IY = the character, IX = its places table.  The IX and IY a script leaves (a
 * callee such as 3D87 or 0C9A changes them) are read by no caller: the drivers reload both (chr_update,
 * 2475/247C), so they are not compared. */
static void w_52B4(void) { ai_malachi_think(cpu.iy, cpu.ix); z80_ret(); }
#endif

/* 5495 ai_berengar_think (PC 1000:42ED, 44C4, 457A): the script of the Berengario slot (Jorge on day 3,
 * Bernardo Gui on days 4-5).  chr = IY.  The 64K calls of 3EE6 (the PC's ai_stop_hour_countdown) do
 * not return (see ai_stop_hour_countdown_z80). */
void ai_berengar_think(uint16_t chr)
{
    if (rb(D64_AI_BERENGAR_SLOT_BUSY) == 1) { ai_stay(); return; }                 /* 5495 */
    if (rb(D64_GAME_DAY) == 3) {                                                        /* 549E Jorge */
        if (rb(D64_GAME_HOUR) == 1) { ai_stay(); return; }                          /* 54A4 */
        if (rb(D64_GAME_HOUR) == 2) {                                                   /* 54AD */
            if (rb(D64_AI_BERENGAR_STATE) == 0x1E) {                                    /* 54B3 */
                if (rb(D64_TXT_PHRASE_BUSY) == 0) scr_set(D64_AI_BERENGAR_STATE, 0x1F); /* 54B9 */
            } else if (rb(D64_AI_BERENGAR_STATE) == 0x1F) {                             /* 54C5 */
                if (ai_guillermo_is_close(chr)) {                                   /* 54CB */
                    (void)hud_say(0x32);                                                /* 54D0 SED BIENVENIDO... */
                    scr_set(D64_AI_ADVANCE_HOUR, 0x01);
                }
            } else if (ai_guillermo_is_close(chr)) {                                /* 54DA */
                hud_say_now(0x31);                                                /* 54DF VENERABLE JORGE... */
                scr_set(D64_AI_BERENGAR_STATE, 0x1E);
            }
            ai_stay();                                                              /* 54C2 / 54D7 / 54E6 */
            return;
        }
        if (rb(D64_GAME_HOUR) == 3) {                                                   /* 54E9 */
            scr_set(D64_AI_BERENGAR_DEST, 0x03);                                        /* 54EF */
            scr_set(D64_AI_BERENGAR_STATE, 0x00);
            if (rb(D64_BERENGAR_X) == 0x60) (void)hud_say(0x27);                        /* 54F5 */
            if (rb(D64_AI_BERENGAR_REACHED) == 0x03) scr_set(D64_AI_BERENGAR_SLOT_BUSY, 0x01);   /* 54FF */
            return;
        }
    }
    if (rb(D64_GAME_HOUR) == 3) { scr_set(D64_AI_BERENGAR_DEST, 0x01); return; }       /* 5509 refectory */
    if (rb(D64_GAME_HOUR) == 1) { scr_set(D64_AI_BERENGAR_DEST, 0x00); return; }       /* 5513 church */
    if (rb(D64_GAME_DAY) == 5) {                                                        /* 551D */
        if (rb(D64_AI_BERENGAR_REACHED) == 0x04) {                                      /* 5523 */
            scr_set(D64_AI_BERENGAR_SLOT_BUSY, 0x01);                                   /* 5529 */
            scr_set(D64_BERENGAR_X, 0x00);
        }
        scr_set(D64_AI_BERENGAR_DEST, 0x04);                                            /* 552F abbey exit */
    }
    if (rb(D64_GAME_HOUR) == 6) { scr_set(D64_AI_BERENGAR_DEST, 0x03); return; }       /* 5532 */
    if (rb(D64_GAME_HOUR) == 0) {                                                       /* 553C noche */
        if (rb(D64_GAME_DAY) == 3) {                                                    /* 5543 */
            if (rb(D64_AI_BERENGAR_STATE) == 0x06) {                                    /* 554A */
                scr_set(D64_OBJ_BERENGAR_TAKEMASK, 0x80);                               /* 5550 may take the book */
                if (rb(D64_AI_BERENGAR_REACHED) == 0x03) {                              /* 5554 */
                    scr_set(D64_AI_BERENGAR_DEST, 0x05);
                    return;
                }
                scr_set(D64_AI_BERENGAR_DEST, 0xFD);                                    /* 555E the book */
                if ((rb(D64_OBJ_BERENGAR_OBJECTS) & 0x80) == 0x80) {                    /* 5562 */
                    if (rb(D64_AI_BERENGAR_REACHED) == 0x06) scr_set(D64_AI_ADVANCE_HOUR, 0x01);   /* 556C */
                    scr_set(D64_AI_BERENGAR_DEST, 0x06);                                /* 5575 */
                }
                return;
            }
            if (rb(D64_AI_BERENGAR_REACHED) == 0x03) {                                  /* 5579 */
                scr_set(D64_AI_BERENGAR_STATE, 0x06);                                   /* 557F */
                chr_berengar_hooded();                                                      /* 5582 chr_berengar_hooded */
                return;
            }
        }
        scr_set(D64_AI_BERENGAR_DEST, 0x03);                                            /* 5586 */
        return;
    }
    if (rb(D64_GAME_HOUR) == 5) {                                                       /* 558A visperas */
        if (rb(D64_GAME_DAY) == 0x02 && rb(D64_AI_MALACHI_STATE) < 0x04) { ai_stay(); return; }   /* 5590 */
        scr_set(D64_AI_BERENGAR_STATE, 0x01);                                           /* 559D */
        scr_set(D64_AI_BERENGAR_DEST, 0x00);
        return;
    }
    if (rb(D64_GAME_DAY) < 3) {                                                         /* 55A4 days 1-2 */
        if (rb(D64_AI_BERENGAR_STATE) == 0x04) {                                        /* 55AB waits for the parchment */
            scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));           /* 55B1 */
            if (rb(D64_AI_WAIT_COUNT) < 0x41 && rb(D64_ISO_ROOM_NUMBER) == 0x40) {      /* 55B6 */
                if (!(rb(D64_GUILLERMO_OBJECTS) & 0x10)) scr_set(D64_AI_BERENGAR_STATE, 0x00);   /* 55C1 */
                return;
            }
            scr_set(D64_AI_BERENGAR_STATE, 0x05);                                       /* 55CB */
            ai_stop_hour_countdown();                                               /* 55CE */
            return;
        }
        if (rb(D64_AI_BERENGAR_STATE) == 0x05) {                                        /* 55D2 tells the abbot */
            scr_set(D64_AI_BERENGAR_DEST, 0xFE);                                        /* 55D8 */
            if (rb(D64_AI_BERENGAR_REACHED) == 0xFE) {                                  /* 55DC */
                scr_set(D64_AI_WAIT_COUNT, 0xC9);                                       /* 55E3 */
                scr_set(D64_AI_BERENGAR_STATE, 0x00);
                scr_set(D64_AI_PARCHMENT_REPORTED, 0x01);
                scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x01));
            }
            return;
        }
        if (rb(D64_AI_BERENGAR_REACHED) == 0x02) {                                      /* 55F3 */
            if (ai_parchment_check()) {                                                 /* 55F9 CALL 3F56 */
                scr_set(D64_AI_WAIT_COUNT, 0x00);                                       /* 55FE */
                scr_set(D64_AI_BERENGAR_STATE, 0x04);
                if (ai_guillermo_is_close(chr)) {                                   /* 5604 */
                    (void)hud_say(0x04);                                                /* 5609 DEJAD EL MANUSCRITO... */
                    return;
                }
                scr_set(D64_AI_BERENGAR_STATE, 0x05);                                   /* 560F */
                ai_stop_hour_countdown();                                           /* 5612 */
                return;
            }
        }
        if ((rb(D64_AI_MONK_FLAGS) & 0x40) == 0x40 && rb(D64_GUILLERMO_Z) >= 0x0D) {    /* 5616 */
            if (!(rb(D64_AI_MONK_FLAGS) & 0x10)) {                                      /* 5624 */
                scr_set(D64_AI_BERENGAR_DEST, 0xFF);                                    /* 562A */
                if (!ai_guillermo_is_close(chr)) return;                            /* 562E */
                if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                     /* 5633 */
                    scr_set(D64_AI_BERENGAR_REACHED, 0xFF);                             /* 5639 */
                    (void)chr_cmd_discard(chr);                                           /* 563D */
                    scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x10));
                    (void)hud_say(0x35);                                                /* 5645 AQUI TRABAJAN LOS MEJORES COPISTAS */
                }
                ai_stay();                                                          /* 5649 */
                return;
            }
            if (!(rb(D64_AI_MONK_FLAGS) & 0x08)) {                                      /* 564F */
                scr_set(D64_AI_BERENGAR_DEST, 0x02);                                    /* 5655 */
                if (ai_guillermo_is_close(chr)) {                                   /* 5658 */
                    if (rb(D64_AI_BERENGAR_REACHED) == 0x02 && rb(D64_TXT_PHRASE_BUSY) == 0) {   /* 565D */
                        scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x08));
                        (void)hud_say(0x36);                                            /* 566A AQUI TRABAJABA VENANCIO */
                    }
                    return;
                }
                if (rb(D64_AI_BERENGAR_REACHED) == 0x02)                                /* 566F */
                    scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x80));
            }
        }
        scr_set(D64_AI_BERENGAR_STATE, 0x00);                                           /* 567B */
        scr_set(D64_AI_BERENGAR_DEST, 0x02);                                            /* his desk */
        return;
    }
    if (rb(D64_AI_BERENGAR_STATE) == 0x14) {                                            /* 5682 days 3-7 */
        if (rb(D64_AI_BERENGAR_DEST) == rb(D64_AI_BERENGAR_REACHED))                    /* 5688 */
            scr_set(D64_AI_BERENGAR_DEST, (uint8_t)(rb(D64_AI_RANDOM) & 0x03));
        return;
    }
    if (rb(D64_GAME_DAY) != 4) return;                                                  /* 5694 Bernardo */
    if (rb(D64_AI_BERENGAR_DEST) == 0xFE && (rb(D64_OBJ_ABBOT_OBJECTS) & 0x10) == 0x10) {   /* 569B */
        scr_set(D64_AI_BERENGAR_STATE, 0x14);                                           /* 56A8 */
        scr_set(D64_AI_BERENGAR_DEST, 0x01);
        scr_set(D64_AI_ABBOT_STATE, 0x15);
        return;
    }
    if ((rb(D64_OBJ_BERENGAR_OBJECTS) & 0x10) == 0x10) {                                /* 56B2 he has the parchment */
        scr_set(D64_AI_BERENGAR_DEST, 0xFE);                                            /* 56BA */
        ai_stop_hour_countdown();                                                   /* 56BE */
        scr_set(D64_OBJ_BERENGAR_TAKEMASK, 0x00);                                       /* 56C1 */
        return;
    }
    if (rb(D64_AI_PARCHMENT_AT_ABBOT) == 0x01 || (rb(D64_OBJ_ABBOT_OBJECTS) & 0x10) == 0x10
        || rb(D64_AI_ABBOT_STATE) == 0x0B) {                                            /* 56C5 */
        scr_set(D64_AI_BERENGAR_DEST, 0x02);                                            /* 56D5 */
        scr_set(D64_AI_BERENGAR_STATE, 0x14);
        return;
    }
    scr_set(D64_AI_PARCHMENT_AT_ABBOT, 0x00);                                           /* 56DC */
    ai_stop_hour_countdown();                                                       /* 56DF: does not return here */
    if ((rb(D64_GUILLERMO_OBJECTS) & 0x10) == 0x10) {                                   /* 56E2 */
        if (rb(D64_AI_BERENGAR_STATE) == 0x07) {                                        /* 56EA */
            scr_set(D64_AI_BERENGAR_DEST, 0xFF);                                        /* 56F0 */
            if (ai_guillermo_is_close(chr) && rb(D64_TXT_PHRASE_BUSY) == 0) {       /* 56F4 */
                (void)hud_say(0x05);                                                    /* 56FF DADME EL MANUSCRITO */
                hud_obsequium_minus_2();                                                /* 5703 */
            }
            return;
        }
        if (ai_guillermo_is_close(chr)) { scr_set(D64_AI_BERENGAR_DEST, 0x03); return; }   /* 5708 */
        scr_set(D64_AI_BERENGAR_STATE, 0x07);                                           /* 5711 */
        return;
    }
    scr_set(D64_AI_BERENGAR_DEST, 0xFC);                                                /* 5717 the parchment */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5495(void) { ai_berengar_think(cpu.iy); z80_ret(); }
#endif

/* 571C ai_severin_think (PC 1000:4642, 4772): the script of the Severino slot (Jorge on days 6-7).
 * chr = IY.  Days 6-7: the final scene in the finis Africae (states 0B-10); days 1-5: ceremonies,
 * Berengario's cell at night, his introductions and the book. */
void ai_severin_think(uint16_t chr)
{
    if (rb(D64_AI_SEVERIN_SLOT_BUSY) == 1) { ai_stay(); return; }                  /* 571C */
    if (rb(D64_GAME_DAY) >= 6) {                                                        /* 5725 Jorge */
        if (rb(D64_AI_SEVERIN_STATE) == 0x0B) {                                         /* 572C */
            if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                         /* 5732 */
                obj_jorge_drops_book();                                                      /* 5738 obj_jorge_drops_book */
                scr_set(D64_AI_SEVERIN_STATE, 0x0C);
            }
            ai_stay();                                                              /* 573E */
            return;
        }
        if (rb(D64_AI_SEVERIN_STATE) == 0x0C) {                                         /* 5741 */
            if (rb(D64_GUILLERMO_OBJECTS) & 0x80) {                                     /* 5747 Guillermo has the book */
                (void)hud_say(0x2E);                                                    /* 5751 ES EL COENA CIPRIANI... */
                scr_set(D64_AI_SEVERIN_STATE, 0x0D);
            }
            ai_stay();                                                              /* 574E / 5758 */
            return;
        }
        if (rb(D64_AI_SEVERIN_STATE) == 0x0D) {                                         /* 575B */
            if (!(rb(D64_GUILLERMO_OBJECTS) & 0x40)) {                                  /* 5761 without the gloves */
                if (rb(D64_GAME_GUILLERMO_DEAD) == 0) {                                 /* 5768 */
                    if (rb(D64_ISO_ROOM_NUMBER) == 0x72 || rb(D64_TXT_PHRASE_BUSY) == 0)   /* 576E */
                        scr_set(D64_GAME_BOOK_POISON_COUNT, 0xFF);                      /* 5776 */
                    else
                        scr_set(D64_GAME_BOOK_POISON_COUNT, 0x01);                      /* 577C */
                }
            } else if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                  /* 5782 */
                (void)hud_say(0x23);                                                    /* 5788 */
                scr_set(D64_AI_SEVERIN_STATE, 0x0E);
            }
            ai_stay();                                                              /* 577F / 578F */
            return;
        }
        if (rb(D64_AI_SEVERIN_STATE) == 0x0E) {                                         /* 5792 */
            if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                         /* 5798 */
                scr_set(D64_AI_WAIT_COUNT, 0x00);
                scr_set(D64_AI_SEVERIN_STATE, 0x0F);
                (void)hud_say(0x2F);                                                    /* 57A4 FUE UNA BUENA IDEA... */
            }
            ai_stay();                                                              /* 57A8 */
            return;
        }
        if (rb(D64_AI_SEVERIN_STATE) == 0x0F) {                                         /* 57AB */
            scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));           /* 57B1 */
            if (rb(D64_AI_WAIT_COUNT) == 0x28) {                                        /* 57B6 */
                play_area_ff();                                                      /* 57BC clears the play area */
                scr_set(D64_AI_SEVERIN_DEST, 0x04);                                     /* 57BF */
                obj_jorge_takes_book();                                                      /* 57C2 obj_jorge_takes_book */
                scr_set(D64_AI_UNUSED_3CAD, 0x00);
                scr_set(D64_AI_SEVERIN_STATE, 0x10);
                return;
            }
            ai_stay();                                                              /* 57CC */
            return;
        }
        if (rb(D64_AI_SEVERIN_STATE) == 0x10) {                                         /* 57CF */
            if (rb(D64_AI_SEVERIN_REACHED) == 0x04 && rb(D64_ISO_ROOM_NUMBER) == 0x67 && rb(D64_GUILLERMO_Z) < 0x1E) {   /* 57D5 */
                scr_set(D64_GAME_INVESTIGATION_OPEN, 0x00);                             /* 57E3 */
                scr_set(D64_AI_SEVERIN_SLOT_BUSY, 0x01);
                hud_say_now(0x24);                                                /* 57E9 SE ESTA COMIENDO EL LIBRO */
                scr_set(D64_GAME_GUILLERMO_DEAD, 0x01);
            }
            return;
        }
        if (rb(D64_ISO_ROOM_NUMBER) == 0x73) {                                          /* 57F1 */
            scr_set(D64_GAME_BONUS, (uint8_t)(rb(D64_GAME_BONUS) | 0x08));              /* 57F7 */
            hud_say_now(0x21);                                                    /* 57FC SOIS VOS, GUILLERMO... */
            scr_set(D64_AI_SEVERIN_STATE, 0x0B);
        }
        ai_stay();                                                                  /* 5803 */
        return;
    }
    if (rb(D64_GAME_HOUR) == 0 || rb(D64_GAME_HOUR) == 6) {                             /* 5806 */
        scr_set(D64_AI_SEVERIN_REACHED, 0x02);                                          /* 5810 */
        scr_set(D64_AI_SEVERIN_DEST, 0x02);
        return;
    }
    if (rb(D64_GAME_HOUR) == 1) {                                                       /* 5817 prima */
        if (!(rb(D64_TXT_PHRASE_BUSY) >= 0x01 && rb(D64_AI_SEVERIN_DEST) == 0xFF)) {    /* 581D */
            scr_set(D64_AI_SEVERIN_DEST, 0x00);                                         /* 5829 */
            if (rb(D64_GAME_DAY) == 0x05 && rb(D64_AI_SEVERIN_BOOK_TOLD) == 0) {        /* 582C */
                if (rb(D64_GUILLERMO_X) < 0x60) {                                       /* 5836 */
                    scr_set(D64_AI_SEVERIN_BOOK_TOLD, 0x01);                            /* 583C */
                    return;
                }
                scr_set(D64_AI_SEVERIN_DEST, 0xFF);                                     /* 5840 */
                if (rb(D64_AI_SEVERIN_REACHED) == 0xFF) {                               /* 5844 */
                    hud_say_now(0x0F);                                            /* 584B ESCUCHAD HERMANO... */
                    scr_set(D64_AI_SEVERIN_BOOK_TOLD, 0x01);
                }
            }
        }
        return;
    }
    if (rb(D64_GAME_HOUR) == 3) { scr_set(D64_AI_SEVERIN_DEST, 0x01); return; }        /* 5853 refectory */
    if (!(rb(D64_GAME_HOUR) < 5)) { scr_set(D64_AI_SEVERIN_DEST, 0x00); return; }      /* 585D, 58F3 */
    if (!(rb(D64_AI_MONK_FLAGS) & 0x02) && rb(D64_AI_SEVERIN_REACHED) >= 0x02 && rb(D64_GAME_DAY) >= 0x02
        && rb(D64_AI_ABBOT_DEST) < 0xFF) {                                              /* 5864 */
        if (!(rb(D64_AI_MONK_FLAGS) & 0x04) && rb(D64_TXT_PHRASE_BUSY) == 0 && ai_guillermo_is_close(chr)) {   /* 5877 */
            scr_set(D64_AI_MONK_FLAGS, 0x04);                                           /* 5884 (an assignment, as the original) */
            scr_set(D64_AI_SEVERIN_DEST, 0xFF);
            (void)hud_say(0x37);                                                        /* 588B */
            return;
        }
        if ((rb(D64_AI_MONK_FLAGS) & 0x04) == 0x04) {                                   /* 5890 */
            scr_set(D64_AI_SEVERIN_DEST, 0xFF);                                         /* 5898 */
            if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                         /* 589C */
                scr_set(D64_AI_SEVERIN_DEST, 0x02);
                scr_set(D64_AI_SEVERIN_REACHED, 0x03);
                scr_set(D64_AI_MONK_FLAGS, (uint8_t)(rb(D64_AI_MONK_FLAGS) | 0x02));
            }
            return;
        }
    }
    if (rb(D64_AI_SEVERIN_REACHED) == 0xFF) {                                           /* 58AE */
        if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                             /* 58B5 */
            (void)hud_say(0x26);                                                        /* 58BB */
            scr_set(D64_AI_ADVANCE_HOUR, 0x01);
        }
        return;
    }
    if (rb(D64_AI_SEVERIN_REACHED) != 0x02) { scr_set(D64_AI_SEVERIN_DEST, 0x02); return; }   /* 58C3, 58EF */
    if (rb(D64_GAME_DAY) == 0x05) { ai_stay(); return; }                            /* 58C9 */
    if (rb(D64_GAME_HOUR) == 0x02 && rb(D64_GAME_DAY) == 0x04) {                        /* 58D2 */
        scr_set(D64_AI_SEVERIN_DEST, 0xFF);                                             /* 58DC */
        if (ai_guillermo_is_close(chr)) (void)hud_say(0x2C);                        /* 58E0 ESPERAD, HERMANO */
        return;
    }
    scr_set(D64_AI_SEVERIN_DEST, 0x03);                                                 /* 58EA */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_571C(void) { ai_severin_think(cpu.iy); z80_ret(); }
#endif

/* 5A3B ai_adso_tell_guillermo (PC 1000:4A5E): when Adso's state is not yet ai_ready_for_ceremony, he
 * says the phrase ai_phrase_param (ai_say_phrase_param 3A58) if Guillermo is close, and state := it. */
static void ai_adso_tell_guillermo(uint16_t chr)
{
    if (rb(D64_AI_ADSO_STATE) == rb(D64_AI_READY_FOR_CEREMONY)) return;                 /* 5A3B */
    if (ai_guillermo_is_close(chr)) ai_say_phrase_param();                              /* 5A42 ai_say_phrase_param */
    scr_set(D64_AI_ADSO_STATE, rb(D64_AI_READY_FOR_CEREMONY));                          /* 5A4A */
}

/* 58F7 ai_adso_think (PC 1000:48AB): Adso's script (chr = IY): the lamp and darkness warnings (dawn,
 * lamp low / exhausted, the dark library), the ceremonies (he tells Guillermo where to go), Guillermo's
 * cell at completas, the night in the cell (sleep? S/N) and following Guillermo otherwise. */
void ai_adso_think(uint16_t chr)
{
    if ((rb(D64_GUILLERMO_OBJECTS) & 0x10) == 0x10) scr_set(D64_AI_PARCHMENT_AT_ABBOT, 0x00);   /* 58F7 */
    if (rb(D64_AI_NIGHT_ENDING) == 0x01) (void)hud_say(0x27);                           /* 5902 PRONTO AMANECERA */
    if (rb(D64_AI_LAMP_EVENT) == 0x01) {                                                /* 590C */
        scr_set(D64_AI_LAMP_EVENT, 0x00);
        hud_say_now(0x28);                                                        /* 5915 LA LAMPARA SE AGOTA */
    }
    if (rb(D64_AI_LAMP_EVENT) == 0x02) {                                                /* 5919 */
        scr_set(D64_AI_LAMP_EVENT, 0x00);
        scr_set(D64_AI_DARK_COUNT, 0x32);
        scr_set(D64_AI_LAMP_IN_USE, 0x00);
        play_area_ff();                                                              /* 5928 clears the play area */
        obj_lamp_reset();                                                              /* 592B obj_lamp_reset */
        hud_say_now(0x2A);                                                        /* 592E SE HA AGOTADO LA LAMPARA */
    }
    if (rb(D64_GAME_GUILLERMO_DEAD) == 0) {                                             /* 5932 */
        if (rb(D64_AI_DARK_COUNT) >= 0x01) {                                            /* 5938 */
            if (rb(D64_GUILLERMO_Z) < 0x18) {                                           /* 593E out of the library */
                scr_set(D64_AI_DARK_COUNT, 0x00);                                       /* 5945 */
                return;
            }
            scr_set(D64_AI_DARK_COUNT, (uint8_t)(rb(D64_AI_DARK_COUNT) - 1));           /* 5949 */
            if (rb(D64_AI_DARK_COUNT) == 0x01) {                                        /* 594E */
                scr_set(D64_GAME_GUILLERMO_DEAD, 0x01);                                 /* 5954 */
                hud_say_now(0x2B);                                                /* 5957 JAMAS CONSEGUIREMOS SALIR */
                return;
            }
        } else if (rb(D64_ADSO_Z) >= 0x18) {                                            /* 595E in the library */
            scr_set(D64_AI_ADSO_DEST, 0xFF);                                            /* 5965 */
            if (!(rb(D64_GAME_ADSO_LAMP) & 0x80)) {                                     /* 5969 without the lamp */
                hud_say_now(0x13);                                                /* 5970 DEBEMOS ENCONTRAR UNA LAMPARA */
                scr_set(D64_AI_DARK_COUNT, 0x64);
                return;
            }
            scr_set(D64_AI_LAMP_IN_USE, 0x01);                                          /* 5978 */
            return;
        } else {
            scr_set(D64_AI_LAMP_IN_USE, 0x00);                                          /* 597C */
            scr_set(D64_AI_DARK_COUNT, 0x00);
        }
    }
    if (rb(D64_GAME_HOUR) == 3) {                                                       /* 5982 sexta: refectory */
        scr_set(D64_AI_ADSO_DEST, 0x01);
        scr_set(D64_AI_READY_FOR_CEREMONY, 0x07);
        scr_set(D64_AI_PHRASE_PARAM, 0x0C);
        ai_adso_tell_guillermo(chr);                                                    /* 5991 JP 5A3B */
        return;
    }
    if (rb(D64_GAME_HOUR) == 5 || rb(D64_GAME_HOUR) == 1) {                             /* 5994 church */
        scr_set(D64_AI_ADSO_DEST, 0x00);
        scr_set(D64_AI_READY_FOR_CEREMONY, 0x01);
        scr_set(D64_AI_PHRASE_PARAM, 0x0B);
        ai_adso_tell_guillermo(chr);                                                    /* 59A7 JP 5A3B */
        return;
    }
    if (rb(D64_GAME_HOUR) == 6) {                                                       /* 59AA completas */
        scr_set(D64_AI_ADSO_STATE, 0x06);
        scr_set(D64_AI_ADSO_DEST, 0x02);
        return;
    }
    if (rb(D64_GAME_HOUR) != 0) { scr_set(D64_AI_ADSO_DEST, 0xFF); return; }           /* 59B7, 5A36 */
    if (rb(D64_AI_ADSO_STATE) == 0x04) {                                                /* 59BE asks to sleep */
        if (rb(D64_ISO_ROOM_NUMBER) == 0x37) scr_set(D64_AI_ADVANCE_HOUR, 0x02);        /* 59C4 */
        if (rb(D64_TXT_PHRASE_BUSY) != 0) return;                                       /* 59CD */
        if (rb(D64_AI_SLEEP_ANSWER_COUNT) >= 0x64) {                                    /* 59D3 */
            scr_set(D64_AI_ADVANCE_HOUR, 0x02);                                         /* 59D9 */
            return;
        }
        scr_set(D64_AI_SLEEP_ANSWER_COUNT, (uint8_t)(rb(D64_AI_SLEEP_ANSWER_COUNT) + 1));   /* 59DD */
        hud_blink_yes_no();                                                              /* 59E2 hud_blink_yes_no */
        if ((rb(D64_AI_SLEEP_ANSWER_COUNT) & 0x01) != 0x01) return;                     /* 59E5 */
        if (key_down(0x3C)) { scr_set(D64_AI_ADVANCE_HOUR, 0x02); return; }     /* 59ED 'S' */
        if (key_down(0x2E)) scr_set(D64_AI_ADSO_STATE, 0x05);                   /* 59F4 'N' */
        return;
    }
    scr_set(D64_AI_ADSO_DEST, 0xFF);                                                    /* 5A04 */
    if (rb(D64_AI_ADSO_STATE) == 0x05) {                                                /* 5A08 */
        if (rb(D64_ISO_ROOM_NUMBER) == 0x3E) return;                                    /* 5A0E */
        scr_set(D64_AI_ADSO_STATE, 0x06);                                               /* 5A16 */
    }
    if (rb(D64_AI_ADSO_STATE) == 0x06) {                                                /* 5A19 */
        if (ai_guillermo_is_close(chr) && rb(D64_ISO_ROOM_NUMBER) == 0x3E) {        /* 5A1F */
            scr_set(D64_AI_SLEEP_ANSWER_COUNT, 0x00);                                   /* 5A2B */
            scr_set(D64_AI_ADSO_STATE, 0x04);
            (void)hud_say(0x12);                                                        /* 5A31 ¿DORMIMOS?, MAESTRO */
        }
        return;
    }
    scr_set(D64_AI_ADSO_DEST, 0xFF);                                                    /* 5A36 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_58F7(void) { ai_adso_think(cpu.iy); z80_ret(); }
#endif

/* 5A4F ai_hour_change_events (PC 1000:4A76): once per hour (game_hour != ai_last_hour_done): the
 * idle-frame count := 0 (3D07 with its inline byte 00) and the actions of the new hour (a switch through
 * 3A5D): noche, prima, tercia, sexta, nona, visperas, completas.  Entered by a JP from ai_hour_update
 * (3A37). */
void ai_hour_change_events(void)
{
    uint8_t h = rb(D64_GAME_HOUR);
    if (h == rb(D64_AI_LAST_HOUR_DONE)) return;                                         /* 5A4F */
    scr_set(D64_AI_LAST_HOUR_DONE, h);                                                  /* 5A58 */
    game_set_c004_inline(0x00);                                                       /* 5A5B CALL 3D07 <00> */
    switch (rb(D64_GAME_HOUR)) {                                                        /* 5A5F, 5A61 CALL 3A5D */
    case 0:                                                                             /* 5A75 noche */
        if (rb(D64_GAME_DAY) == 0x05) {
            obj_place_glasses();                                                          /* 5A7B obj_place_glasses */
            obj_place_key1();                                                          /* 5A7E obj_place_key1 */
        }
        if (rb(D64_GAME_DAY) == 0x06) {                                                 /* 5A81 */
            obj_place_key3();                                                          /* 5A87 obj_place_key3 */
            chr_jorge_appears();                                                          /* 5A8A chr_jorge_appears */
            scr_set(D64_AI_SEVERIN_SLOT_BUSY, 0x00);
        }
        return;
    case 1:                                                                             /* 5A91 prima */
        (void)vid_spiral_wipe();                                                              /* vid_spiral_wipe */
        scr_set(D64_OBJ_DOOR_CHECK_MASK, 0xEF);
        vid_palette_day();                                                          /* 5A98 */
        obj_open_left_wing_doors();                                                              /* 5A9B obj_open_left_wing_doors */
        snd_play_hour_bells();                                                              /* 5A9E snd_stub_event */
        if (rb(D64_GAME_DAY) >= 0x03) {                                                 /* 5AA1 */
            obj_lamp_reset();                                                          /* obj_lamp_reset */
            obj_place_lamp();                                                          /* obj_place_lamp */
        }
        if (rb(D64_GAME_DAY) == 0x02) obj_remove_glasses();                                /* 5AAD obj_remove_glasses */
        if (rb(D64_GAME_DAY) == 0x03) {                                                 /* 5AB6 */
            obj_book_to_jorge();                                                          /* obj_book_to_jorge */
            chr_berengar_vanishes();                                                          /* chr_berengar_vanishes */
            scr_set(D64_OBJ_BERENGAR_OBJECTS, 0x00);
            scr_set(D64_OBJ_ABBOT_OBJECTS, 0x00);
            if (!(rb(D64_GUILLERMO_OBJECTS) & 0x10)) {                                  /* 5AC8 */
                obj_place_parchment();                                                      /* obj_place_parchment */
                scr_set(D64_AI_PARCHMENT_AT_ABBOT, 0x01);
            }
        }
        if (rb(D64_GAME_DAY) == 0x05 && !(rb(D64_GUILLERMO_OBJECTS) & 0x08))            /* 5AD4 */
            obj_remove_key1();                                                          /* obj_remove_key1 */
        return;
    case 2:                                                                             /* 5AE2 tercia */
        (void)vid_spiral_wipe();
        snd_play_tercia_bells();                                                              /* snd_stub_bells */
        return;
    case 3:                                                                             /* 5AE9 sexta */
        snd_play_hour_bells();
        if (rb(D64_GAME_DAY) == 0x04) {                                                 /* 5AEC */
            chr_bernardo_arrives();                                                          /* chr_bernardo_arrives */
            scr_set(D64_AI_BERENGAR_SLOT_BUSY, 0x00);
            scr_set(D64_OBJ_BERENGAR_TAKEMASK, 0x10);
        }
        return;
    case 4:                                                                             /* 5AFC nona */
        (void)vid_spiral_wipe();
        if (rb(D64_GAME_DAY) == 0x03) {                                                 /* 5AFF */
            scr_set(D64_AI_BERENGAR_SLOT_BUSY, 0x01);
            scr_set(D64_BERENGAR_X, 0x00);
        }
        snd_play_tercia_bells();                                                              /* 5B0B */
        return;
    case 5:                                                                             /* 5B0F visperas */
        snd_play_hour_bells();
        return;
    case 6:                                                                             /* 5B13 completas */
        (void)vid_spiral_wipe();
        vid_palette_night();
        scr_set(D64_OBJ_DOOR_CHECK_MASK, 0xDF);
        snd_play_tercia_bells();
        return;
    default:                                                                            /* past the table: 5A74 RET */
        return;
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5A4F(void) { ai_hour_change_events(); z80_ret(); }
#endif

/* 5FEE ai_ready_ber_adso_sev_mal (PC 1000:51C8): ai_ready_for_ceremony := the OR of the places reached by
 * Berengario, Adso, Severino and Malaquias (00 = all of them at place 0). */
void ai_ready_ber_adso_sev_mal(void)
{
    scr_set(D64_AI_READY_FOR_CEREMONY, (uint8_t)(rb(D64_AI_BERENGAR_REACHED) | rb(D64_AI_ADSO_REACHED)
                                                 | rb(D64_AI_SEVERIN_REACHED) | rb(D64_AI_MALACHI_REACHED)));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5FEE(void) { ai_ready_ber_adso_sev_mal(); z80_ret(); }
#endif

/* 5FF8 ai_ready_adso_sev_mal (PC 1000:51D5): the same without Berengario. */
void ai_ready_adso_sev_mal(void)
{
    scr_set(D64_AI_READY_FOR_CEREMONY, (uint8_t)(rb(D64_AI_ADSO_REACHED) | rb(D64_AI_SEVERIN_REACHED)
                                                 | rb(D64_AI_MALACHI_REACHED)));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5FF8(void) { ai_ready_adso_sev_mal(); z80_ret(); }
#endif

/* 5FDD ai_abbot_count_vespers (PC 1000:51AE): switch (day - 1) through 3A5D: who must be in the church at
 * visperas: days 1, 2, 4 and past the table (the code after the table) all four monks, day 3 without
 * Berengario, day 5 6000h, day 6 6012h (ai_ready_vespers_day5, ai_ready_adso).  In: C = day - 1, ZF = (C == 0). */
void ai_abbot_count_vespers(uint8_t day_index)
{
    switch (day_index) {
    case 2: ai_ready_adso_sev_mal(); return;
    case 4: ai_ready_vespers_day5(); return;
    case 5: ai_ready_adso(); return;
    default: ai_ready_ber_adso_sev_mal(); return;
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5FDD(void) { ai_abbot_count_vespers(cpu.zf ? 0 : cpu.c); z80_ret(); }
#endif

/* 5FC2 (PC abbot_offended): unless the abbot is already offended (state >= 80h): obsequium - 2,
 * chr_cmd_discard, state + 80h, 'OS ORDENO QUE VENGAIS' and ai_stay. */
static void abbot_offended(uint16_t chr)
{
    if (rb(D64_AI_ABBOT_STATE) >= 0x80) return;                                         /* 5FC2 */
    hud_obsequium_minus_2();                                                            /* 5FCA */
    (void)chr_cmd_discard(chr);
    scr_set(D64_AI_ABBOT_STATE, (uint8_t)(rb(D64_AI_ABBOT_STATE) + 0x80));              /* 5FD0 */
    hud_say_now(0x08);                                                            /* 5FD6 */
    ai_stay();                                                                      /* 5FDA */
}

/* 5F25 (PC abbot_announce): the announcement of tercia/nona on days 2-7 (phrase in ai_phrase_param):
 * state 10h wanders between his places (5F38); at tercia the announcement scene (5F76). */
static void abbot_announce(uint16_t chr)
{
    if (rb(D64_AI_ABBOT_STATE) == 0x10) {                                               /* 5F25, 5F38 */
        if (rb(D64_AI_BERENGAR_DEST) == 0xFE || rb(D64_AI_MALACHI_DEST) == 0xFE) {
            if (rb(D64_AI_ABBOT_DEST) == rb(D64_AI_ABBOT_REACHED)) { ai_stay(); return; }   /* 5F44 */
            scr_set(D64_AI_ABBOT_DEST, 0x02);                                           /* 5F4D */
            if ((rb(D64_OBJ_BERENGAR_OBJECTS) & 0x10) == 0x10) scr_set(D64_AI_ABBOT_DEST, 0x03);   /* 5F50 */
            return;
        }
        if ((rb(D64_OBJ_ABBOT_OBJECTS) & 0x10) == 0x10) scr_set(D64_AI_ABBOT_DEST, 0x02);   /* 5F5C */
        if (rb(D64_AI_ABBOT_REACHED) == rb(D64_AI_ABBOT_DEST))                          /* 5F67 */
            scr_set(D64_AI_ABBOT_DEST, (uint8_t)((rb(D64_AI_RANDOM) & 0x03) + 0x02));
        return;
    }
    if (rb(D64_GAME_HOUR) != 0x02) return;                                              /* 5F2E */
    if (rb(D64_AI_ABBOT_STATE) == 0x0E) {                                               /* 5F76 */
        (void)hud_say(0x14);                                                            /* 5F7C VENID AQUI, FRAY GUILLERMO */
        scr_set(D64_AI_ABBOT_STATE, 0x11);
    }
    if (rb(D64_AI_ABBOT_STATE) == 0x11 && rb(D64_TXT_PHRASE_BUSY) == 0) {               /* 5F83 */
        scr_set(D64_AI_ABBOT_STATE, 0x12);
        scr_set(D64_AI_WAIT_COUNT, 0x00);
    }
    if (rb(D64_AI_ABBOT_STATE) == 0x12) {                                               /* 5F95 */
        scr_set(D64_AI_ABBOT_STATE, 0x0F);
        scr_set(D64_AI_ABBOT_DEST, 0x00);
        ai_say_phrase_param();                                                              /* 5FA1 ai_say_phrase_param */
        return;
    }
    if (rb(D64_AI_ABBOT_STATE) == 0x0F) {                                               /* 5FA5 */
        if (rb(D64_TXT_PHRASE_BUSY) == 0) { scr_set(D64_AI_ABBOT_STATE, 0x10); return; }   /* 5FAB */
        if (ai_guillermo_is_close(chr)) return;                                     /* 5FB5 */
        scr_set(D64_AI_ABBOT_STATE, 0x12);                                              /* 5FBB */
        abbot_offended(chr);                                                            /* 5FBE JP 5FC2 */
    }
}

/* 5B21 ai_abbot_think (PC 1000:4B74, 4BA0, 4E30): the abbot's script (chr = IY, places = IX): the rules
 * (Guillermo in the left wing at prima or on day 1, in the library after noche, in the abbot's cell),
 * expulsion (state 0Bh), offended (state >= 80h), the parchment, the ceremonies of visperas, prima and
 * sexta, completas (to Guillermo's cell), noche (looks for Guillermo), the welcome tour of day 1 nona,
 * and the announcements of days 2-7. */
void ai_abbot_think(uint16_t chr, uint16_t places)
{
    if (rb(D64_GUILLERMO_X) < 0x60 && (rb(D64_GAME_HOUR) == 0x01 || rb(D64_GAME_DAY) == 0x01))   /* 5B21 */
        scr_set(D64_AI_ABBOT_STATE, 0x0B);                                              /* 5B2F */
    if (rb(D64_GAME_HOUR) >= 0x01 && rb(D64_GUILLERMO_Z) >= 0x16) {                     /* 5B32 */
        scr_set(D64_AI_ABBOT_DEST, 0x09);                                               /* 5B3C */
        scr_set(D64_AI_ABBOT_STATE, 0x0B);
        return;
    }
    if (rb(D64_AI_ABBOT_STATE) == 0x0B) {                                               /* 5B43 expels Guillermo */
        scr_set(D64_AI_ABBOT_DEST, 0xFF);                                               /* 5B49 */
        if (!ai_guillermo_is_close(chr)) return;                                    /* 5B4D */
        if (rb(D64_GAME_GUILLERMO_DEAD) == 0x01) return;                                /* 5B52 */
        if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                             /* 5B59 */
            (void)hud_say(0x0E);                                                        /* 5B5F NO HABEIS RESPETADO MIS ORDENES */
            scr_set(D64_GAME_GUILLERMO_DEAD, 0x01);
        }
        return;
    }
    if (rb(D64_ISO_ROOM_NUMBER) == 0x0D && rb(D64_AI_CAMERA_TARGET) == 0) {             /* 5B67 his cell */
        if (ai_guillermo_is_close(chr)) {                                           /* 5B6F */
            (void)hud_say(0x29);                                                        /* 5B74 HABEIS ENTRADO EN MI CELDA */
            scr_set(D64_AI_ABBOT_DEST, 0xFF);
            scr_set(D64_AI_ABBOT_STATE, 0x0B);
            return;
        }
        scr_set(D64_AI_ABBOT_DEST, 0x02);                                               /* 5B80 */
        return;
    }
    if (rb(D64_AI_ABBOT_DEST) == rb(D64_AI_ABBOT_REACHED) && rb(D64_AI_ABBOT_REACHED) == 0x02
        && (rb(D64_OBJ_ABBOT_OBJECTS) & 0x10) == 0x10) {                                /* 5B84 in his cell with the parchment */
        scr_set(D64_AI_PARCHMENT_AT_ABBOT, 0x01);                                       /* 5B94 */
        obj_abbot_drops_parchment();                                                              /* 5B97 obj_abbot_drops_parchment */
        if (rb(D64_AI_ABBOT_STATE) == 0x15 && !(rb(D64_OBJ_ABBOT_OBJECTS) & 0x10)) {    /* 5B9A */
            scr_set(D64_AI_ADVANCE_HOUR, 0x01);                                         /* 5BA4 */
            scr_set(D64_AI_ABBOT_STATE, 0x10);
        }
    }
    if (rb(D64_AI_ABBOT_STATE) == 0x15) { scr_set(D64_AI_ABBOT_DEST, 0x02); return; }   /* 5BAA */
    if (rb(D64_AI_ABBOT_STATE) >= 0x80) {                                               /* 5BB4 offended */
        if (rb(D64_TXT_PHRASE_BUSY) != 0) { scr_set(D64_AI_ABBOT_DEST, 0xFF); return; } /* 5BBB, 5BC8 */
        scr_set(D64_AI_ABBOT_STATE, (uint8_t)(rb(D64_AI_ABBOT_STATE) & 0x7F));          /* 5BC1 */
    }
    if (rb(D64_GAME_HOUR) == 0x05) {                                                    /* 5BCD visperas */
        scr_set(D64_AI_ABBOT_STATE, 0x05);
        (void)ai_check_guillermo_at_mass();                                                              /* 5BD6 ai_check_guillermo_at_mass */
        scr_set(D64_AI_ABBOT_DEST, 0x00);
        scr_set(D64_AI_PHRASE_PARAM, 0x17);
        ai_abbot_count_vespers((uint8_t)(rb(D64_GAME_DAY) - 1));                        /* 5BDF, 5BE3 */
        ai_abbot_wait_ceremony();                                                              /* 5BE6 ai_abbot_wait_ceremony */
        return;
    }
    if (rb(D64_GAME_HOUR) == 0x01) {                                                    /* 5BEA prima */
        scr_set(D64_AI_ABBOT_STATE, 0x0E);
        (void)ai_check_guillermo_at_mass();                                                              /* 5BF3 */
        scr_set(D64_AI_ABBOT_DEST, 0x00);
        scr_set(D64_AI_PHRASE_PARAM, 0x17);
        ai_abbot_count_prima((uint8_t)(rb(D64_GAME_DAY) - 2) == 0, (uint8_t)(rb(D64_GAME_DAY) - 2));   /* 5BFC, 5C00 CALL 6016 */
        ai_abbot_wait_ceremony();                                                              /* 5C03 */
        return;
    }
    if (rb(D64_GAME_HOUR) == 0x03) {                                                    /* 5C07 sexta */
        scr_set(D64_AI_ABBOT_DEST, 0x01);
        (void)ai_check_guillermo_at_refectory();                                                              /* 5C10 ai_check_guillermo_at_refectory */
        scr_set(D64_AI_ABBOT_STATE, 0x10);
        scr_set(D64_AI_PHRASE_PARAM, 0x19);
        scr_set(D64_AI_READY_FOR_CEREMONY, 0x01);
        ai_abbot_count_sexta((uint8_t)(rb(D64_GAME_DAY) - 2) == 0, (uint8_t)(rb(D64_GAME_DAY) - 2));   /* 5C1C, 5C20 CALL 6040 */
        ai_abbot_wait_ceremony();                                                              /* 5C23 */
        return;
    }
    if (rb(D64_GAME_HOUR) == 0x06 && rb(D64_AI_ABBOT_STATE) == 0x05) {                  /* 5C27 */
        scr_set(D64_AI_ABBOT_STATE, 0x06);
        if (rb(D64_ISO_ROOM_NUMBER) == 0x22) (void)hud_say(0x0D);                       /* 5C34 PODEIS IR A VUESTRAS CELDAS */
        return;
    }
    if (rb(D64_AI_PARCHMENT_REPORTED) == 0x01) {                                        /* 5C3F wants the parchment */
        scr_set(D64_AI_ABBOT_DEST, 0xFF);
        obj_abbot_wants_parchment();                                                              /* 5C49 (a RET) */
        if ((rb(D64_OBJ_ABBOT_OBJECTS) & 0x10) == 0x10) {                               /* 5C4C */
            scr_set(D64_AI_ABBOT_STATE, 0x15);
            scr_set(D64_AI_ABBOT_REACHED, 0xFF);
            scr_set(D64_AI_PARCHMENT_REPORTED, 0x00);
            return;
        }
        if (!ai_guillermo_is_close(chr)) { scr_set(D64_AI_WAIT_COUNT, 0xC9); return; }   /* 5C5F, 5C7C */
        if (rb(D64_AI_WAIT_COUNT) >= 0xC8) {                                            /* 5C64 */
            hud_obsequium_minus_2();                                                    /* 5C6B */
            (void)hud_say(0x05);                                                        /* 5C6E DADME EL MANUSCRITO */
            scr_set(D64_AI_WAIT_COUNT, 0x00);
        }
        scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));               /* 5C75 */
        return;
    }
    if (rb(D64_GAME_HOUR) == 0x06) {                                                    /* 5C81 completas */
        if (rb(D64_AI_ABBOT_STATE) == 0x06) {                                           /* 5C88 */
            if (rb(D64_TXT_PHRASE_BUSY) == 0) {
                scr_set(D64_AI_WAIT_COUNT, 0x00);
                scr_set(D64_AI_ABBOT_DEST, 0x05);
                (void)ai_next_state_on_arrival(places);                                   /* 5C9A */
            }
            return;
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x07) {                                           /* 5C9E */
            if (rb(D64_ISO_ROOM_NUMBER) == 0x3E) { scr_set(D64_AI_ABBOT_STATE, 0x09); return; }   /* 5CA4 */
            if (ai_guillermo_is_close(chr)) {                                       /* 5CAF */
                scr_set(D64_AI_ABBOT_STATE, 0x08);
                (void)hud_say(0x10);                                                    /* 5CB7 ENTRAD EN VUESTRA CELDA */
                return;
            }
            scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));           /* 5CBC */
            if (rb(D64_AI_WAIT_COUNT) >= 0x32) scr_set(D64_AI_ABBOT_STATE, 0x08);       /* 5CC1 */
            return;
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x08) {                                           /* 5CCB */
            if (rb(D64_ISO_ROOM_NUMBER) == 0x3E) { scr_set(D64_AI_ABBOT_STATE, 0x09); return; }   /* 5CD1 */
            scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));           /* 5CDC */
            if (rb(D64_AI_WAIT_COUNT) >= 0x32) scr_set(D64_AI_WAIT_COUNT, 0x32);        /* 5CE1 */
            if (ai_guillermo_is_close(chr)) {                                       /* 5CEA */
                if (rb(D64_AI_WAIT_COUNT) == 0x32) {                                    /* 5CEF */
                    hud_obsequium_minus_2();                                            /* 5CF5 */
                    (void)hud_say(0x10);
                    scr_set(D64_AI_WAIT_COUNT, 0x00);
                }
                return;
            }
            scr_set(D64_AI_ABBOT_DEST, 0xFF);                                           /* 5D00 */
            return;
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x09) {                                           /* 5D05 */
            if (rb(D64_ISO_ROOM_NUMBER) == 0x3E) {                                      /* 5D0B */
                scr_set(D64_AI_ABBOT_DEST, 0x06);
                (void)ai_next_state_on_arrival(places);                                   /* 5D15 */
                return;
            }
            (void)chr_cmd_discard(chr);                                                   /* 5D1A */
            scr_set(D64_AI_ABBOT_STATE, 0x08);
            scr_set(D64_AI_ABBOT_DEST, 0xFF);
            return;
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x0A) {                                           /* 5D25 */
            scr_set(D64_AI_ADVANCE_HOUR, 0x01);
            scr_set(D64_OBJ_DOOR_CHECK_MASK, (uint8_t)(rb(D64_OBJ_DOOR_CHECK_MASK) & 0xF7));
        }
        return;
    }
    if (rb(D64_GAME_HOUR) == 0x00) {                                                    /* 5D35 noche */
        scr_set(D64_AI_ABBOT_DEST, 0x02);                                               /* 5D3C his cell */
        if (rb(D64_AI_ABBOT_STATE) == 0x0A && rb(D64_AI_ABBOT_REACHED) == 0x02) {       /* 5D3F */
            scr_set(D64_AI_WAIT_COUNT, 0x00);
            scr_set(D64_AI_ABBOT_STATE, 0x0C);
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x0C) {                                           /* 5D4F */
            if (rb(D64_GUILLERMO_X) >= 0x60) {                                          /* 5D55 */
                scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));       /* 5D5B */
                if (rb(D64_AI_WAIT_COUNT) >= 0xFA
                    || (rb(D64_GAME_DAY) == 0x05 && (rb(D64_GUILLERMO_OBJECTS) & 0x08) == 0x08))   /* 5D60 */
                    scr_set(D64_AI_ABBOT_STATE, 0x0D);
            }
            return;
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x0D) {                                           /* 5D75 looks for Guillermo */
            if (rb(D64_GUILLERMO_X) < 0x60 || rb(D64_ISO_ROOM_NUMBER) == 0x3E) {        /* 5D7B */
                scr_set(D64_AI_ABBOT_STATE, 0x0C);
                scr_set(D64_AI_WAIT_COUNT, 0x32);
                return;
            }
            if (ai_guillermo_is_close(chr)) scr_set(D64_AI_ABBOT_STATE, 0x0B);      /* 5D8D */
            scr_set(D64_AI_ABBOT_DEST, 0xFF);                                           /* 5D95 */
        }
        return;
    }
    if (rb(D64_GAME_DAY) == 0x01) {                                                     /* 5D9B day 1 */
        if (rb(D64_GAME_HOUR) != 0x04) return;                                          /* 5DA2 nona: the welcome */
        if (rb(D64_AI_ABBOT_STATE) == 0x04) {                                           /* 5DA9 */
            scr_set(D64_AI_ABBOT_DEST, 0x02);
            if (rb(D64_AI_ABBOT_REACHED) == 0x02) scr_set(D64_AI_ADVANCE_HOUR, 0x01);   /* 5DB2 */
            return;
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x00) {                                           /* 5DBC */
            if (ai_guillermo_is_close(chr)) {                                       /* 5DC2 */
                (void)hud_say(0x01);                                                    /* 5DC7 */
                scr_set(D64_AI_ABBOT_STATE, 0x01);
                scr_set(D64_AI_ABBOT_DEST, 0xFF);
                return;
            }
            scr_set(D64_AI_ABBOT_DEST, 0x03);                                           /* 5DD5 */
            return;
        }
        if (!ai_guillermo_is_close(chr)) { abbot_offended(chr); return; }          /* 5DD9, 5E4C */
        if (rb(D64_AI_ABBOT_STATE) == 0x01) {                                           /* 5DDF */
            if (rb(D64_AI_ABBOT_DEST) == 0x04 && rb(D64_TXT_PHRASE_BUSY) == 0)          /* 5DE5 */
                scr_set(D64_AI_ABBOT_STATE, 0x02);
            else if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                    /* 5DF2 */
                scr_set(D64_AI_ABBOT_DEST, 0x04);
                (void)hud_say(0x02);                                                    /* 5DFB */
            }
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x02) {                                           /* 5DFF */
            scr_set(D64_AI_ABBOT_DEST, 0x04);
            if (rb(D64_AI_ABBOT_REACHED) == 0x04 && rb(D64_TXT_PHRASE_BUSY) == 0)       /* 5E08 */
                scr_set(D64_AI_ABBOT_STATE, 0x03);
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x03) {                                           /* 5E13 */
            if (rb(D64_AI_ABBOT_DEST) == 0x05 && rb(D64_TXT_PHRASE_BUSY) == 0)          /* 5E19 */
                scr_set(D64_AI_ABBOT_STATE, 0x1F);
            else if (rb(D64_TXT_PHRASE_BUSY) == 0) {                                    /* 5E26 */
                scr_set(D64_AI_ABBOT_DEST, 0x05);
                (void)hud_say(0x03);                                                    /* 5E2F */
            }
        }
        if (rb(D64_AI_ABBOT_STATE) == 0x1F) {                                           /* 5E33 */
            scr_set(D64_AI_ABBOT_DEST, 0x05);
            if (rb(D64_AI_ABBOT_REACHED) == 0x05 && rb(D64_TXT_PHRASE_BUSY) == 0) {     /* 5E3C */
                scr_set(D64_AI_ABBOT_STATE, 0x04);
                (void)hud_say(0x07);                                                    /* 5E47 */
            }
        }
        return;
    }
    if (rb(D64_GAME_DAY) == 0x02) {                                                     /* 5E50 */
        scr_set(D64_AI_PHRASE_PARAM, 0x16);
        abbot_announce(chr);                                                            /* 5E59 JP 5F25 */
        return;
    }
    if (rb(D64_GAME_DAY) == 0x03) {                                                     /* 5E5C */
        if (rb(D64_AI_ABBOT_STATE) == 0x10 && rb(D64_GAME_HOUR) == 0x02) {              /* 5E62 presents Jorge */
            if (ai_guillermo_is_close(chr)) { scr_set(D64_AI_ABBOT_DEST, 0x07); return; }   /* 5E6C */
            if (rb(D64_AI_BERENGAR_STATE) >= 0x1E)                                      /* 5E75 */
                scr_set(D64_AI_BERENGAR_STATE, (uint8_t)(rb(D64_AI_BERENGAR_STATE) - 1));
            scr_set(D64_AI_ADVANCE_HOUR, 0x00);                                         /* 5E80 */
            abbot_offended(chr);                                                        /* 5E83 JP 5FC2 */
            return;
        }
        scr_set(D64_AI_PHRASE_PARAM, 0x30);                                             /* 5E86 */
        abbot_announce(chr);
        return;
    }
    if (rb(D64_GAME_DAY) == 0x04) {                                                     /* 5E8C */
        scr_set(D64_AI_PHRASE_PARAM, 0x11);
        abbot_announce(chr);
        return;
    }
    if (rb(D64_GAME_DAY) == 0x05) {                                                     /* 5E98 */
        if (rb(D64_GAME_HOUR) != 0x04) {                                                /* 5E9E */
            scr_set(D64_AI_PHRASE_PARAM, 0x1D);                                         /* 5EFD */
            abbot_announce(chr);
            return;
        }
        if (rb(D64_AI_ABBOT_REACHED) == 0x08) {                                         /* 5EA4 at Severino's cell */
            if (rb(D64_AI_WAIT_COUNT) == 0x00) snd_play_severino();                       /* 5EAA snd_stub_counter */
            scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));           /* 5EB3 */
            if (rb(D64_AI_WAIT_COUNT) < 0x1E) return;                                   /* 5EB8 */
            scr_set(D64_AI_ABBOT_STATE, 0x10);                                          /* 5EBF */
            (void)hud_say(0x1C);                                                        /* 5EC2 */
            scr_set(D64_AI_ADVANCE_HOUR, 0x01);
            return;
        }
        if (rb(D64_AI_ABBOT_DEST) == 0x08 || rb(D64_AI_ABBOT_STATE) >= 0x13) {          /* 5ECA */
            scr_set(D64_AI_WAIT_COUNT, 0x00);                                           /* 5ED4 */
            if (rb(D64_AI_ABBOT_STATE) == 0x13) {                                       /* 5ED7 */
                if (ai_guillermo_is_close(chr)) { scr_set(D64_AI_ABBOT_DEST, 0x08); return; }   /* 5EDD */
                abbot_offended(chr);                                                    /* 5EE6 JP 5FC2 */
                return;
            }
            if (rb(D64_TXT_PHRASE_BUSY) == 0) scr_set(D64_AI_ABBOT_STATE, 0x13);        /* 5EE9 */
            return;
        }
        hud_say_now(0x1B);                                                        /* 5EF5 */
        scr_set(D64_AI_ABBOT_DEST, 0x08);
        return;
    }
    if (rb(D64_GAME_DAY) == 0x06) {                                                     /* 5F03 */
        scr_set(D64_AI_PHRASE_PARAM, 0x1E);
        abbot_announce(chr);
        return;
    }
    if (rb(D64_GAME_DAY) == 0x07) {                                                     /* 5F0F */
        scr_set(D64_AI_PHRASE_PARAM, 0x25);
        if (rb(D64_GAME_HOUR) == 0x02) scr_set(D64_GAME_GUILLERMO_DEAD, 0x01);          /* 5F18 time is over */
        abbot_announce(chr);
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_5B21(void) { ai_abbot_think(cpu.iy, cpu.ix); z80_ret(); }
#endif

/* ================================================================ the table */

/* ================================================================ 6000-60F2: the abbot's ceremonies
 * (scripts past 5FFFh, in the original's postfix language as the others: written here as C; the ending
 * loaded from the tape covers them, see game_ending) */

/* 6000 ai_ready_vespers_day5 (PC ai_*): day 5 at visperas (5FDD): when Malaquias is dying or dead
 * (ai_malachi_dying >= 1) the abbot's phrase is 20h and the monks are ready (ai_ready_for_ceremony := 0);
 * else they are not (1). */
void ai_ready_vespers_day5(void)
{
    if (rb(D64_AI_MALACHI_DYING) >= 0x01) {                                             /* 6000 RST 08 [AC] > 1 */
        scr_set(D64_AI_PHRASE_PARAM, 0x20);                                             /* 6006 */
        scr_set(D64_AI_READY_FOR_CEREMONY, 0x00);                                       /* 600A */
        return;
    }
    scr_set(D64_AI_READY_FOR_CEREMONY, 0x01);                                           /* 600E */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_6000(void) { ai_ready_vespers_day5(); z80_ret(); }
#endif

/* 6012 ai_ready_adso: ai_ready_for_ceremony := ai_adso_reached (only Adso is waited for). */
void ai_ready_adso(void)
{
    scr_set(D64_AI_READY_FOR_CEREMONY, rb(D64_AI_ADSO_REACHED));                        /* 6012 */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_6012(void) { ai_ready_adso(); z80_ret(); }
#endif

/* the entry 3A5D (util_jump_table_inline) selects in a table of n words after t0: zero -> 0 (t0); else
 * sel 1..n; sel 0 or past the table -> n + 1 (the code after the table) */
static uint8_t table_entry(bool zero, uint8_t sel, uint8_t n)
{
    if (zero) return 0;
    if (sel >= 1 && sel <= n) return sel;
    return (uint8_t)(n + 1);
}

/* 6016 ai_abbot_count_prima: who must be in the church at prima (CALL 3A5D, sel = day - 2 with its ZF):
 * day 2 (and days past the table: the code after it, 6027) phrase 15h and all four monks; day 3 phrase
 * 18h and Adso, Severino, Malaquias; day 4 phrase 1Ah and the same; day 5 all four; day 6 Adso alone;
 * day 7 phrase 17h and Adso alone.  In: ZF (zero), C (sel). */
void ai_abbot_count_prima(bool zero, uint8_t sel)
{
    switch (table_entry(zero, sel, 5)) {
    case 1: scr_set(D64_AI_PHRASE_PARAM, 0x18); ai_ready_adso_sev_mal(); return;      /* 602D (40 18: a literal) */
    case 2: scr_set(D64_AI_PHRASE_PARAM, 0x1A); ai_ready_adso_sev_mal(); return;      /* 6034 */
    case 3: ai_ready_ber_adso_sev_mal(); return;                                        /* 5FEE */
    case 4: ai_ready_adso(); return;                                                    /* 6012 */
    case 5: scr_set(D64_AI_PHRASE_PARAM, 0x17); ai_ready_adso(); return;               /* 603A */
    default: scr_set(D64_AI_PHRASE_PARAM, 0x15); ai_ready_ber_adso_sev_mal(); return; /* 6027 */
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_6016(void) { ai_abbot_count_prima(cpu.zf, cpu.c); z80_ret(); }
#endif

/* 6040 ai_abbot_count_sexta: who must be in the refectory at sexta (CALL 3A5D, sel = day - 2): day 2
 * Berengario, Adso and Severino at their places 1 (then ai_ready_for_ceremony := 0); days 3-4 Adso and
 * Severino; days 5-6 ai_ready_for_ceremony := 00 when Adso is there, else FFh; other days nothing.
 * In: ZF (zero), C (sel). */
void ai_abbot_count_sexta(bool zero, uint8_t sel)
{
    switch (table_entry(zero, sel, 4)) {
    case 0:                                                                             /* 6050 */
        if (rb(D64_AI_BERENGAR_REACHED) == 0x01 && rb(D64_AI_ADSO_REACHED) == 0x01 && rb(D64_AI_SEVERIN_REACHED) == 0x01)
            scr_set(D64_AI_READY_FOR_CEREMONY, 0x00);                                   /* 605E */
        return;
    case 1: case 2:                                                                     /* 6062 */
        if (rb(D64_AI_ADSO_REACHED) == 0x01 && rb(D64_AI_SEVERIN_REACHED) == 0x01)
            scr_set(D64_AI_READY_FOR_CEREMONY, 0x00);                                   /* 606C */
        return;
    case 3: case 4:                                                                     /* 6070 */
        scr_set(D64_AI_READY_FOR_CEREMONY, rb(D64_AI_ADSO_REACHED) == 0x01 ? 0x00 : 0xFF);
        return;
    default:                                                                            /* 604F RET */
        return;
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_6040(void) { ai_abbot_count_sexta(cpu.zf, cpu.c); z80_ret(); }
#endif

/* 6076 ai_abbot_wait_ceremony: the abbot at the ceremony.  Not at his place (ai_abbot_reached !=
 * ai_abbot_dest): ai_wait_count := 0.  The monks not ready: nothing.  Guillermo not at his place
 * (ai_guillermo_in_place 0): after C8h frames the abbot expels him (state 0Bh, ai_advance_hour := 1), else
 * the count goes on.  At his place or in the room (1, 2): after 32h frames 'phrase 06h' and obsequium - 2;
 * with no phrase on: in the room (2) every 1Eh frames phrase 2Dh and obsequium - 2, at his place (1) the
 * phrase of the ceremony (ai_say_phrase_param) and ai_advance_hour := 1; then, if the hour is to advance
 * while he is only in the room, phrase 2Dh at once and obsequium - 2. */
void ai_abbot_wait_ceremony(void)
{
    if (rb(D64_AI_ABBOT_REACHED) != rb(D64_AI_ABBOT_DEST)) {                            /* 6076 */
        scr_set(D64_AI_WAIT_COUNT, 0x00);                                               /* 60EF */
        return;
    }
    if (rb(D64_AI_READY_FOR_CEREMONY) != 0x00) return;                                  /* 607C (JR 60ED -> 60F2 RET) */
    if (rb(D64_AI_GUILLERMO_IN_PLACE) < 0x01) {                                         /* 6082 */
        if (rb(D64_AI_WAIT_COUNT) >= 0xC8) {                                            /* 60DA (40 C8: a literal) */
            scr_set(D64_AI_ABBOT_STATE, 0x0B);                                          /* 60E1 */
            scr_set(D64_AI_ADVANCE_HOUR, 0x01);
            return;
        }
        scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));               /* 60E8, JR 60F2 */
        return;
    }
    if (rb(D64_AI_WAIT_COUNT) >= 0x32) {                                                /* 6088 */
        scr_set(D64_AI_WAIT_COUNT, 0x00);                                               /* 608E */
        (void)hud_say(0x06);                                                            /* 6091 CALL 4B7C <06> */
        hud_obsequium_minus_2();                                                        /* 6095 */
        return;                                                                         /* 6098 JR 60D9 */
    }
    if (rb(D64_TXT_PHRASE_BUSY) == 0x00) {                                              /* 609A */
        if (rb(D64_AI_GUILLERMO_IN_PLACE) == 0x02) {                                    /* 60A0 */
            scr_set(D64_AI_WAIT_COUNT, (uint8_t)(rb(D64_AI_WAIT_COUNT) + 1));           /* 60A6 */
            if (rb(D64_AI_WAIT_COUNT) >= 0x1E) {                                        /* 60AB */
                scr_set(D64_AI_WAIT_COUNT, 0x00);                                       /* 60B1 */
                (void)hud_say(0x2D);                                                    /* 60B4 CALL 4B7C <2D> */
                hud_obsequium_minus_2();                                                /* 60B8 */
            }
            return;                                                                     /* 60BB */
        }
        ai_say_phrase_param();                                                          /* 60BC CALL 3A58 */
        scr_set(D64_AI_ADVANCE_HOUR, 0x01);                                             /* 60BF */
    }
    if (rb(D64_AI_ADVANCE_HOUR) == 0x01 && rb(D64_AI_GUILLERMO_IN_PLACE) == 0x02) {     /* 60C2 */
        scr_set(D64_AI_WAIT_COUNT, 0x00);                                               /* 60CC */
        scr_set(D64_AI_ADVANCE_HOUR, 0x00);
        hud_say_now(0x2D);                                                              /* 60D2 CALL 4B71 <2D> */
        hud_obsequium_minus_2();                                                        /* 60D6 */
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_6076(void) { ai_abbot_wait_ceremony(); z80_ret(); }

/* ================================================================ the table */

const traducida_t traducidas_logica_b[] = {
    { 0x4C46, "obj_pick_up_objects", w_4C46, r_4C46 },
    { 0x4D2A, "hud_draw_guillermo_objects", w_4D2A, sin_resultados },
    { 0x4D30, "hud_draw_objects", w_4D30, sin_resultados },
    { 0x4D97, "obj_update_key_permissions", w_4D97, resultado_a },
    { 0x4DC3, "obj_drop_on_space", w_4DC3, sin_resultados },
    { 0x4DCD, "obj_drop_object", w_4DCD, sin_resultados },
    { 0x4EA5, "obj_front_position", w_4EA5, r_4EA5 },
    { 0x4ECA, "iso_mirror_update", w_4ECA, r_ixiy },
    { 0x4EF4, "iso_mirror_character", w_4EF4, r_ixiy },
    { 0x4F03, "iso_mirror_reflect", w_4F03, r_4F03 },
    { 0x4FC9, "iso_mirror_draw_callback", w_4FC9, sin_resultados },
    { 0x4FEF, "hud_scroll_hour_name", w_4FEF, sin_resultados },
    { 0x5028, "ai_clock_init", w_5028, resultado_a },
    { 0x5035, "ai_clock_redraw", w_5035, sin_resultados },
    { 0x5060, "ai_clock_load_duration", w_5060, resultado_hl },
    { 0x507D, "ai_clock_tick", w_507D, sin_resultados },
    { 0x5094, "ai_clock_advance_hour", w_5094, sin_resultados },
    { 0x50AF, "hud_set_and_draw_day", w_50AF, sin_resultados },
    { 0x50D9, "hud_draw_day_numeral", w_50D9, r_50D9 },
    { 0x510C, "ai_timers_tick", w_510C, r_510C },
    { 0x5124, "hud_obsequium_minus_2", w_5124, sin_resultados },
    { 0x5129, "hud_obsequium_sub", w_5129, sin_resultados },
    { 0x5164, "hud_fill_bar", w_5164, resultado_hl },
    { 0x5184, "obj_read_manuscript", w_5184, sin_resultados },
    { 0x5199, "obj_set_mirror_numeral", w_5199, sin_resultados },
    { 0x51E7, "game_update_camera_and_bonus", w_51E7, sin_resultados },
    { 0x52B4, "ai_malachi_think", w_52B4, sin_resultados },
    { 0x5495, "ai_berengar_think", w_5495, sin_resultados },
    { 0x571C, "ai_severin_think", w_571C, sin_resultados },
    { 0x58F7, "ai_adso_think", w_58F7, sin_resultados },
    { 0x5A4F, "ai_hour_change_events", w_5A4F, sin_resultados },
    { 0x5B21, "ai_abbot_think", w_5B21, sin_resultados },
    { 0x5FDD, "ai_abbot_count_vespers", w_5FDD, sin_resultados },
    { 0x5FEE, "ai_ready_ber_adso_sev_mal", w_5FEE, sin_resultados },
    { 0x5FF8, "ai_ready_adso_sev_mal", w_5FF8, sin_resultados },
    { 0x6000, "ai_ready_vespers_day5", w_6000, sin_resultados },
    { 0x6012, "ai_ready_adso", w_6012, sin_resultados },
    { 0x6016, "ai_abbot_count_prima", w_6016, sin_resultados },
    { 0x6040, "ai_abbot_count_sexta", w_6040, sin_resultados },
    { 0x6076, "ai_abbot_wait_ceremony", w_6076, sin_resultados },
    { 0, NULL, NULL, NULL }
};
#endif

