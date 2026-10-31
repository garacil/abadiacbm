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

/* abadia64ks, group "personajes" (CPC 64 KiB 2226-2FAC): the characters' movement, the probe of the
 * height buffer, the animation and the projection to sprites, the command streams of the characters the
 * AI moves, the height buffer of a room, the keyboard and the key tests, the sprite flips and the input
 * step of the main loop.  Each function cites its 64K address and the full game's function (PC rebuild,
 * c/src) it corresponds to; the 64K code is the reference.  Data: datos_personajes.h.
 *
 * Every call is a C call (juego64.h).  Functions that do not return to their caller (261E
 * chr_project_or_hide, 2632 chr_project, 280D chr_read_command) are written in C for their C callers but
 * are not in the table: their Z80 originals stay in use when Z80 code calls them.
 *
 * The SP: 2236 and 2265 reach spr_draw_all (447D) by JP, which stores SP: they take `sp`, their entry SP
 * (pointing at their return address); so does 2226, for the path searches of the drivers. */
#include <stdio.h>
#include <string.h>
#include "juego64.h"
#include "datos_personajes.h"

/* the camera rotation of chr_project: the CALL nn at 2655 whose operand [2656] iso_update_camera_room sets
 * to 20AE, 20A9, 20AF or 20B8 */
static uint16_t camera_rotate(uint16_t xy)
{
    switch (rw(D64_CHR_CAMERA_TRANSFORM)) {
    case 0x20A9: return iso_rotate_cam1(xy);
    case 0x20AF: return iso_rotate_cam2(xy);
    case 0x20B8: return iso_rotate_cam3(xy);
    default: return iso_rotate_cam0(xy);                 /* 20AE */
    }
}

/* ================================================================== the main loop's steps */

/* 2226 game_run_npc_behaviours (PC 1000:2059): one step of every NPC: Adso 04EB, Malachi 036D, the
 * Abbot 038E, Berengar 04A0, Severin 04C1.  In: sp (each driver is CALLed: sp - 2). */
void game_run_npc_behaviours(uint16_t sp)
{
    ai_update_adso((uint16_t)(sp - 2));
    ai_update_malachi((uint16_t)(sp - 2));
    ai_update_abbot((uint16_t)(sp - 2));
    ai_update_berengar((uint16_t)(sp - 2));
    ai_update_severin((uint16_t)(sp - 2));
}

/* 223D (label inside 2236, also the JR target of 2274): dark room.  Clears the redraw bit 7 of every
 * active sprite record (FE inactive, FF end); then, if Adso's sprite is active and he carries the lamp
 * (bit 7 of [2944]), the light sprite is shown (BCh) and the sprites are drawn (JP 447D). */
static void spr_dark_hide_all(uint16_t sp)
{
    uint16_t p;
    uint8_t b;
    for (p = D64_SPR_TABLE;; p = (uint16_t)(p + 0x14)) {
        b = rb(p);
        if (b == 0xFF) break;
        if (b != 0xFE) wb(p, (uint8_t)(b & 0x7F));
    }
    if (rb(D64_SPR_TABLE + 0x14) == 0xFE) return;
    if (!(rb(D64_GAME_ADSO_LAMP) & 0x80)) return;
    wb(D64_SPR_LIGHT, 0xBC);
    spr_draw_all(sp);                   /* JP 447D */
}

/* 2236 spr_draw_or_darken (PC 1000:2069): sprite step of the main loop.  Lit room ([11DC] = 0): the
 * sprites are drawn (JP 447D spr_draw_all); dark room: 223D.  In: sp. */
void spr_draw_or_darken(uint16_t sp)
{
    if (rb(D64_ISO_ROOM_DARK) == 0) {
        spr_draw_all(sp);               /* JP Z,447D */
        return;
    }
    spr_dark_hide_all(sp);
}

/* 2265 spr_place_light (PC 1000:20A4): after a room change.  Hides the light sprite; lit room: nothing
 * more.  Dark room without Adso's sprite: 223D.  Else puts the light on Adso: x = max(0, (x & FC) - 8),
 * y = max(0, (y & F8) - 18h) in bytes 1-4, depth bytes 12h/13h = FE, and the operands of the light
 * drawer: [4756] = x & 3, [4782] = 4 - (x & 3), [4738]/[479E] = EFh/9Fh (swapped when (y & 7) < 4), and
 * the byte [476D] = 00 (NOP) or 29h (ADD HL,HL) when Adso's graphics are flipped (bit 0 of [2B9C]).
 * In: sp (for 223D). */
void spr_place_light(uint16_t sp)
{
    uint8_t x, y, a;
    uint16_t fill_a, fill_b;
    wb(D64_SPR_LIGHT, 0xFE);
    if (rb(D64_ISO_ROOM_DARK) == 0) return;
    if (rb(D64_SPR_TABLE + 0x14) == 0xFE) {
        spr_dark_hide_all(sp);
        return;
    }
    x = rb(D64_SPR_TABLE + 0x15);
    wb(D64_SPR_LIGHT_DX, (uint8_t)(x & 3));
    wb(D64_SPR_LIGHT_DX_REST, (uint8_t)(4 - (x & 3)));
    wb(D64_SPR_LIGHT + 0x12, 0xFE);
    wb(D64_SPR_LIGHT + 0x13, 0xFE);
    a = (uint8_t)(x & 0xFC);
    a = a >= 8 ? (uint8_t)(a - 8) : 0;
    wb(D64_SPR_LIGHT + 1, a);
    wb(D64_SPR_LIGHT + 3, a);
    y = rb(D64_SPR_TABLE + 0x16);
    fill_a = 0xEF;
    fill_b = 0x9F;
    if ((y & 7) < 4) { fill_a = 0x9F; fill_b = 0xEF; }
    ww(D64_SPR_LIGHT_FILL_A, fill_a);
    ww(D64_SPR_LIGHT_FILL_B, fill_b);
    a = (uint8_t)(y & 0xF8);
    a = a >= 0x18 ? (uint8_t)(a - 0x18) : 0;
    wb(D64_SPR_LIGHT + 2, a);
    wb(D64_SPR_LIGHT + 4, a);
    wb(D64_SPR_LIGHT_FLIP_PATCH, (uint8_t)((rb(D64_CHR_ADSO + 6) & 1) ? 0x29 : 0x00));
}

/* 22D4 vid_clear_play_area (PC 1000:29DD): the play area filled with colour 0 (A = 0, JP 16B2
 * vid_fill_play_area). */
void vid_clear_play_area(void)
{
    uint16_t de;
    (void)vid_fill_play_area(0, &de);
}

/* ================================================================== the height buffer and the probe */

/* 22D8 chr_step_table (PC 1000:2189): the orientation entry of the step table of character chr:
 * 23C2 (1-cell characters, bit 7 of [chr+5]) or 23A2 (2x2) + 8 [chr+1] (falls into 22E7).  Entry: word
 * inner stride, word outer stride, word start offset of the 4x4 probe, byte dx, byte dy.  Out: HL. */
uint16_t chr_step_table(uint16_t chr)
{
    uint16_t base = (rb((uint16_t)(chr + 5)) & 0x80) ? D64_CHR_STEP_TABLE_1X1 : D64_CHR_STEP_TABLE_2X2;
    return util_add_bx_8al(base, rb((uint16_t)(chr + 1)));
}

/* 22E7 util_add_bx_8al (PC 1000:2198): p + 8n with the product on 8 bits (ADD A,A x3).  In: HL = p,
 * A = n.  Out: HL (A = H). */
uint16_t util_add_bx_8al(uint16_t p, uint8_t n)
{
    return (uint16_t)(p + (uint8_t)(n << 3));
}

/* 22F0 chr_to_hbuf_coords (PC 1000:21A9): world position (L = x, H = y) -> height-buffer coordinates
 * (y - [22F2], x - [22FE]).  Returns true (CF) when a coordinate is outside 2..15h, leaving the partial
 * result: y fails -> unchanged; x fails -> H converted, L unchanged.  In/out: *pos = HL. */
bool chr_to_hbuf_coords(uint16_t *pos)
{
    uint8_t y = (uint8_t)(*pos >> 8), x = (uint8_t)*pos;
    uint8_t oy = rb(D64_CHR_HBUF_ORIGIN_Y), ox = rb(D64_CHR_HBUF_ORIGIN_X);
    if (y < oy) return true;
    y = (uint8_t)(y - oy);
    if (y < 2 || y >= 0x16) return true;
    *pos = (uint16_t)(y << 8 | x);
    if (x < ox) return true;
    x = (uint8_t)(x - ox);
    if (x < 2 || x >= 0x16) return true;
    *pos = (uint16_t)(y << 8 | x);
    return false;
}

/* 2309 chr_probe_ahead_flat (PC 1000:21D6): chr_probe_cells with the height 0 over the floor (B = the
 * fallback A).  In: IY = chr, A = fallback, C = *ahead2, HL = *step.  Out: A, C, HL as 2320. */
uint8_t chr_probe_ahead_flat(uint16_t chr, uint8_t fallback, uint8_t *ahead2, uint16_t *step)
{
    return chr_probe_cells(chr, 0, fallback, ahead2, step);
}

/* 230D chr_probe_ahead (PC 1000:21DC): if the floor of [chr+4] (iso_floor_base) is not the floor of the
 * height buffer [290B], returns the fallback A (CF; C and HL unchanged); else chr_probe_cells with the
 * height over that floor.  In: IY = chr, A = fallback, C = *ahead2, HL = *step.  Out: A, C, HL. */
uint8_t chr_probe_ahead(uint16_t chr, uint8_t fallback, uint8_t *ahead2, uint16_t *step)
{
    uint8_t z = rb((uint16_t)(chr + 4));
    uint8_t base = iso_floor_base(z);
    if (rb(D64_CHR_SHOWN_FLOOR) != base) return fallback;
    return chr_probe_cells(chr, (uint8_t)(rb((uint16_t)(chr + 4)) - base), fallback, ahead2, step);
}

/* 2320 chr_probe_cells (PC 1000:21F6; entered from 2309 and 230D): samples the 4x4 window of the height
 * buffer in front of character chr into 2916 (a cell >= 10h is a character mark, kept & 30h; else its
 * height minus rel_height, kept in the operand [2374]); the strides come from the step table entry
 * through the operands [2378] and [237F].  Off the 20x20 centre of the buffer: returns the fallback (B),
 * *ahead2 (C) and *step (HL) unchanged.  Else *ahead2 = [2917], *step = the entry + 6 (dx, dy), and
 * returns [291B] for a 1-cell character, or for a 2x2 one [2918] if equal to [2917], else 2.
 * In: IY = chr, A = rel_height, B = fallback, C, HL.  Out: A, C, HL. */
uint8_t chr_probe_cells(uint16_t chr, uint8_t rel_height, uint8_t fallback, uint8_t *ahead2, uint16_t *step)
{
    uint16_t pos, cell, entry, row, p, out;
    uint8_t x, y, i, j, v;
    wb(D64_CHR_PROBE_HEIGHT, rel_height);
    pos = (uint16_t)(rb((uint16_t)(chr + 3)) << 8 | rb((uint16_t)(chr + 2)));
    if (chr_to_hbuf_coords(&pos)) return fallback;
    x = (uint8_t)pos;
    y = (uint8_t)(pos >> 8);
    cell = (uint16_t)(rw(D64_CHR_HBUF_PTR) + 24u * y + x);     /* x, y in 2..15h: no 8-bit wrap in 2335-233C */
    entry = chr_step_table(chr);
    wb(D64_CHR_PROBE_INNER, rb(entry));
    wb(D64_CHR_PROBE_INNER + 1, rb((uint16_t)(entry + 1)));
    wb(D64_CHR_PROBE_OUTER, rb((uint16_t)(entry + 2)));
    wb(D64_CHR_PROBE_OUTER + 1, rb((uint16_t)(entry + 3)));
    row = (uint16_t)(rw((uint16_t)(entry + 4)) + cell);
    out = D64_CHR_PROBE;
    for (i = 0; i < 4; ++i) {
        p = row;
        for (j = 0; j < 4; ++j) {
            v = rb(p);
            v = v >= 0x10 ? (uint8_t)(v & 0x30) : (uint8_t)(v - rb(D64_CHR_PROBE_HEIGHT));
            wb(out, v);
            out = (uint16_t)(out + 1);
            p = (uint16_t)(p + rw(D64_CHR_PROBE_INNER));
        }
        row = (uint16_t)(row + rw(D64_CHR_PROBE_OUTER));
    }
    *step = (uint16_t)(entry + 6);
    *ahead2 = rb(D64_CHR_PROBE + 1);
    if (rb((uint16_t)(chr + 5)) & 0x80) return rb(D64_CHR_PROBE + 5);
    v = rb(D64_CHR_PROBE + 2);
    return v == *ahead2 ? v : 2;
}

/* 2444 chr_mark_hbuf (PC 1000:2315): writes the mark into the height-buffer cell of character chr
 * (iso_grid_cell_of 092E; nothing when it is off the buffer or off the floor shown): low nibble kept,
 * mark ORed; a 2x2 character also marks the cells -1, -18h, -19h.  In: IY = chr, C = mark, IX.
 * Out: IX = the cell (unchanged when off the buffer). */
uint16_t chr_mark_hbuf(uint16_t chr, uint8_t mark, uint16_t ix)
{
    uint16_t cell;
    cell = ix;
    if (iso_grid_cell_of(chr, &cell)) return ix;
    wb(cell, (uint8_t)((rb(cell) & 0x0F) | mark));
    if (rb((uint16_t)(chr + 5)) & 0x80) return cell;
    wb((uint16_t)(cell - 1), (uint8_t)((rb((uint16_t)(cell - 1)) & 0x0F) | mark));
    wb((uint16_t)(cell - 0x18), (uint8_t)((rb((uint16_t)(cell - 0x18)) & 0x0F) | mark));
    wb((uint16_t)(cell - 0x19), (uint8_t)((rb((uint16_t)(cell - 0x19)) & 0x0F) | mark));
    return cell;
}

/* 2873 chr_fill_height_buffer (PC 1000:27E9): clears the 24x24 height buffer [28DB] (240h bytes, by an
 * overlapping LDIR), sets the window origin from the room of chr (07FF iso_grid_set_origin, which
 * returns the floor base 0/0Bh/16h), [3454] = 7B98 / 9E40 / 9F60 (the floor's height data) and fills
 * the buffer (JP 3456 chr_hbuf_fill_room).  In: IY = chr. */
void chr_fill_height_buffer(uint16_t chr)
{
    uint16_t buf = rw(D64_CHR_HBUF_PTR), i, heights;
    uint8_t base;
    wb(buf, 0);
    for (i = 0; i < 0x23F; ++i) wb((uint16_t)(buf + 1 + i), rb((uint16_t)(buf + i)));
    base = iso_grid_set_origin(chr);    /* 07FF: A = the floor base */
    heights = base == 0 ? D64_CHR_FLOOR0_HEIGHTS : base == 0x0B ? D64_CHR_FLOOR1_HEIGHTS : D64_CHR_FLOOR2_HEIGHTS;
    ww(D64_CHR_FLOOR_HEIGHTS_PTR, heights);
    chr_hbuf_fill_room();               /* JP 3456 */
}

/* ================================================================== moving a character */

/* 274B chr_load_params (PC 1000:2681): copies the 5 words of the chr_table entry to the addresses listed
 * at 2741 (the operands 2477 sprite, 247E record, 24A6 behaviour, 25AE flip, 25D9 animation).
 * In: HL = entry. */
void chr_load_params(uint16_t entry)
{
    uint8_t i;
    uint16_t dst;
    for (i = 0; i < 5; ++i) {
        dst = rw((uint16_t)(D64_CHR_PARAM_TARGETS + 2 * i));
        wb(dst, rb(entry));
        wb((uint16_t)(dst + 1), rb((uint16_t)(entry + 1)));
        entry = (uint16_t)(entry + 2);
    }
}

/* 2605 spr_save_old_rect (PC 1000:2527): sprite spr: old x, y [spr+3,4] = [spr+1,2]; old width,
 * height [spr+9,0A] = [spr+5,6].  In: IX = spr.  Out: A = [spr+6]. */
uint8_t spr_save_old_rect(uint16_t spr)
{
    wb((uint16_t)(spr + 3), rb((uint16_t)(spr + 1)));
    wb((uint16_t)(spr + 4), rb((uint16_t)(spr + 2)));
    wb((uint16_t)(spr + 9), rb((uint16_t)(spr + 5)));
    wb((uint16_t)(spr + 0x0A), rb((uint16_t)(spr + 6)));
    return rb((uint16_t)(spr + 6));
}

/* 2472 chr_update (PC 1000:2349): moves one character and updates its sprite.  entry = its 10-byte
 * chr_table record: chr_load_params; sprite = [2477], record = [247E]; spr_save_old_rect; the
 * character's mark leaves the height buffer; [3EED] (Malachi rising) is read and cleared;
 * chr_think_or_step; the mark [chr+0E] goes back (JR 2444).  In: HL = entry.  Out: IY = the record,
 * IX = what the last chr_mark_hbuf leaves. */
uint16_t chr_update(uint16_t entry)
{
    uint16_t spr, chr;
    bool rising;
    chr_load_params(entry);
    spr = rw(D64_CHR_CUR_SPRITE);
    spr_save_old_rect(spr);
    chr = rw(D64_CHR_CUR_DATA);
    chr_mark_hbuf(chr, 0, spr);
    rising = rb(D64_CHR_MALACHI_RISING) != 0;
    wb(D64_CHR_MALACHI_RISING, 0);
    chr_think_or_step(rising, chr, spr);
    return chr_mark_hbuf(chr, rb((uint16_t)(chr + 0x0E)), spr);
}

/* 2556 (label inside 2553, also the JP target of 24A2): [chr] = ([chr] + 1) & 3 (the animation
 * counter, bit 0 = half step), then chr_animate (JR 257C). */
static void chr_advance_anim(uint16_t chr, uint16_t spr)
{
    wb(chr, (uint8_t)((rb(chr) + 1) & 3));
    chr_animate(chr, spr);
}

/* 249A chr_think_or_step (PC 1000:2370): rising (NZ, Malachi rising when dying): only chr_animate.  A
 * step in progress (bit 0 of [chr]): finish it (2556).  Else the behaviour routine [24A6] by JP (HL):
 * 23E2 Guillermo, 278F Adso and the monks.  In: ZF, IY = chr, IX = spr. */
void chr_think_or_step(bool rising, uint16_t chr, uint16_t spr)
{
    uint16_t b;
    if (rising) { chr_animate(chr, spr); return; }
    if (rb(chr) & 1) { chr_advance_anim(chr, spr); return; }
    b = rw(D64_CHR_CUR_BEHAVIOUR);
    if (b == D64_CHR_GUILLERMO_BEHAVIOUR) {
#ifdef ABADIA_AUTOPILOT
        extern void meta_guillermo_behaviour(uint16_t, uint16_t, uint16_t);
        meta_guillermo_behaviour(chr, spr, b);
#else
        chr_guillermo_behaviour(chr, spr, b);
#endif
    }
    else if (b == D64_CHR_AI_FOLLOW_COMMANDS) chr_ai_follow_commands(chr, spr);
    /* any other routine: none in the 64K chr_table */
}

/* 23E2 chr_guillermo_behaviour (PC 1000:22A7; NOP then 23E3): behaviour routine of Guillermo.  A fall
 * in progress ([23E4] != 0, the mirror trap): the counter is decremented (1 -> stays, nothing); 13h with
 * the step [2406] = 2: x - 1 and chr_animate; new value 1: sprite inactive; else sprite y += [2406],
 * redraw, [2912] = FF.  Normal: nothing while the camera follows another character ([37DC]); key 8
 * (left) newly pressed: chr_turn +1; key 1 (right): chr_turn -1; key 0 (up) down: chr_probe_ahead and
 * chr_try_advance.  The fallbacks the probe returns off the floor shown are what the registers hold
 * there: A = the bit sys_key_down found, C = the key code it tested last, HL = this routine's address
 * (`self`, from the JP (HL)).  In: IY = chr, IX = spr, HL = self. */
void chr_guillermo_behaviour(uint16_t chr, uint16_t spr, uint16_t self)
{
    uint8_t st = rb(D64_CHR_GUILLERMO_STATE), a, code, found, ahead1;
    uint16_t step;
    if (st != 0) {
        st = (uint8_t)(st - 1);
        if (st == 0) return;
        wb(D64_CHR_GUILLERMO_STATE, st);
        a = st;
        if (st == 0x13) {
            a = rb(D64_CHR_GUILLERMO_FALL_DY);
            if (a == 2) {
                wb((uint16_t)(chr + 2), (uint8_t)(rb((uint16_t)(chr + 2)) - 1));
                chr_animate(chr, spr);
                return;
            }
        }
        if (a == 1) {
            wb(spr, 0xFE);
            return;
        }
        wb((uint16_t)(spr + 2), (uint8_t)(rb((uint16_t)(spr + 2)) + rb(D64_CHR_GUILLERMO_FALL_DY)));
        wb(spr, (uint8_t)((rb(spr) & 0x3F) | 0x80));
        wb(D64_CHR_MOVED, 0xFF);
        return;
    }
    if (rb(D64_GAME_CAMERA_OTHER) != 0) return;
    if (sys_key_pressed(8, &code)) { chr_turn(chr, spr, 1); return; }
    if (sys_key_pressed(1, &code)) { chr_turn(chr, spr, 0xFF); return; }
    found = sys_key_down(0, &code);
    if (!found) return;
    step = self;
    ahead1 = chr_probe_ahead(chr, found, &code, &step);
    chr_try_advance(chr, spr, ahead1, code, step);
}

/* 24A9 chr_try_advance (PC 1000:2384): advances character chr if the heights allow it.  ahead1 (A),
 * ahead2 (C) = relative heights of the two cells ahead, step (HL) = the dx, dy bytes of the orientation
 * entry.  Clears bit 4 (descending) of [chr+5]; 2x2: chr_try_advance_2x2.  1-cell: blocked by a
 * character mark (10h/20h) in the second cell; turned across a slope (bit 5): moves only on level
 * ground; else climbs (1) or descends (FF, bit 4 set) one unit, any other difference blocks; two equal
 * cells ahead: becomes 2x2 ([chr+5] &= 10h) and steps once, or twice for the orientations 0 and 3;
 * [2912] = FF; animates (2556).  In: IY = chr, IX = spr. */
void chr_try_advance(uint16_t chr, uint16_t spr, uint8_t ahead1, uint8_t ahead2, uint16_t step)
{
    uint8_t a;
    wb((uint16_t)(chr + 5), (uint8_t)(rb((uint16_t)(chr + 5)) & 0xEF));
    if (!(rb((uint16_t)(chr + 5)) & 0x80)) {
        chr_try_advance_2x2(chr, spr, ahead1, step);
        return;
    }
    if (ahead2 == 0x10 || ahead2 == 0x20) return;
    a = ahead1;
    if (rb((uint16_t)(chr + 5)) & 0x20) {
        if (chr_orientation_parity(chr) != 0) a = ahead2;
        if (a != 0) return;
        chr_step_and_animate(chr, spr, step);
        return;
    }
    wb((uint16_t)(chr + 4), (uint8_t)(rb((uint16_t)(chr + 4)) + 1));
    if (a != 1) {
        wb((uint16_t)(chr + 4), (uint8_t)(rb((uint16_t)(chr + 4)) - 1));
        if (a != 0xFF) return;
        wb((uint16_t)(chr + 5), (uint8_t)(rb((uint16_t)(chr + 5)) | 0x10));
        wb((uint16_t)(chr + 4), (uint8_t)(rb((uint16_t)(chr + 4)) - 1));
    }
    if (a != ahead2) {
        chr_step_level(chr, spr, step);
        return;
    }
    wb((uint16_t)(chr + 5), (uint8_t)(rb((uint16_t)(chr + 5)) & 0x10));
    chr_apply_step(chr, step);
    if (chr_orientation_parity(chr) == 0) chr_apply_step(chr, step);
    wb(D64_CHR_MOVED, 0xFF);
    chr_advance_anim(chr, spr);
}

/* 2503 chr_orientation_parity (PC 1000:23FA): 0 (ZF) for the orientations ([chr+1] & 3) 0 and 3, else
 * (o ^ 3).  In: IY = chr.  Out: A, ZF. */
uint8_t chr_orientation_parity(uint16_t chr)
{
    uint8_t o = (uint8_t)(rb((uint16_t)(chr + 1)) & 3);
    return o == 0 ? 0 : (uint8_t)(o ^ 3);
}

/* 250C chr_try_advance_2x2 (PC 1000:2405): 2x2 character: ahead1 = 1 climbs (height + 1, [chr+5] = 80h:
 * 1-cell), FF descends (height - 1, [chr+5] = 90h), 0 is a level step (2549), anything else blocks.
 * After climbing or descending steps once, or twice for the orientations 1 and 2; [2912] = FF; animates
 * (2556).  In: A = ahead1, HL = step, IY = chr, IX = spr. */
void chr_try_advance_2x2(uint16_t chr, uint16_t spr, uint8_t ahead1, uint16_t step)
{
    uint8_t flags;
    if (ahead1 == 1) {
        wb((uint16_t)(chr + 4), (uint8_t)(rb((uint16_t)(chr + 4)) + 1));
        flags = 0x80;
    } else if (ahead1 == 0xFF) {
        wb((uint16_t)(chr + 4), (uint8_t)(rb((uint16_t)(chr + 4)) - 1));
        flags = 0x90;
    } else {
        if (ahead1 == 0) chr_step_level(chr, spr, step);
        return;
    }
    wb((uint16_t)(chr + 5), flags);
    chr_apply_step(chr, step);
    if (chr_orientation_parity(chr) != 0) chr_apply_step(chr, step);
    wb(D64_CHR_MOVED, 0xFF);
    chr_advance_anim(chr, spr);
}

/* 2539 chr_apply_step (PC 1000:2437): [chr+2] += [step] (dx), [chr+3] += [step+1] (dy).  In: HL = step,
 * IY = chr.  Out: A = the new [chr+3] (HL = step + 1). */
uint8_t chr_apply_step(uint16_t chr, uint16_t step)
{
    wb((uint16_t)(chr + 2), (uint8_t)(rb(step) + rb((uint16_t)(chr + 2))));
    wb((uint16_t)(chr + 3), (uint8_t)(rb((uint16_t)(step + 1)) + rb((uint16_t)(chr + 3))));
    return rb((uint16_t)(chr + 3));
}

/* 2549 chr_step_level (PC 1000:2449): a level step.  Its SUB C / INC A / CP 3 is dead (the JR at 254D
 * is unconditional; 254F is never reached): chr_step_and_animate. */
void chr_step_level(uint16_t chr, uint16_t spr, uint16_t step)
{
    chr_step_and_animate(chr, spr, step);
}

/* 2553 chr_step_and_animate (PC 1000:2455): chr_apply_step, then 2556 (counter + 1, chr_animate).
 * In: HL = step, IY = chr, IX = spr. */
void chr_step_and_animate(uint16_t chr, uint16_t spr, uint16_t step)
{
    chr_apply_step(chr, step);
    chr_advance_anim(chr, spr);
}

/* 2561 chr_turn (PC 1000:2462): turns character chr by delta (C = +1 or FF): [chr] = 0; a 1-cell
 * character toggles bit 5 of [chr+5]; [chr+1] = ([chr+1] + delta) & 3; falls into chr_animate. */
void chr_turn(uint16_t chr, uint16_t spr, uint8_t delta)
{
    wb(chr, 0);
    if (rb((uint16_t)(chr + 5)) & 0x80) wb((uint16_t)(chr + 5), (uint8_t)(rb((uint16_t)(chr + 5)) ^ 0x20));
    wb((uint16_t)(chr + 1), (uint8_t)((rb((uint16_t)(chr + 1)) + delta) & 3));
    chr_animate(chr, spr);
}

/* the flip routine of the character being animated ([25AE], CALL NZ at 25AD) */
static void chr_flip(uint16_t routine, uint16_t spr)
{
    switch (routine) {
    case 0x2EE7: spr_flip_adso(); break;
    case 0x2F00: spr_flip_malachi(); break;
    case 0x2F10: spr_flip_abbot(); break;
    case 0x2F20: spr_flip_berengar(); break;
    case 0x2F30: spr_flip_severin(); break;
    case 0x2F40: spr_flip_guillermo(); break;
    case 0x4FC9: iso_mirror_draw_callback(spr); break;   /* the mirror image (iso_mirror_reflect) */
    default: break;                     /* no other routine is ever stored */
    }
}

/* 257C chr_animate (PC 1000:247D): selects the animation frame (chr_select_frame), [2912] = FF,
 * projects the character (chr_project_or_hide: when it is not visible the sprite is marked as leaving
 * and the Z80 returns from here through its stack) and copies the 4-byte frame (graphics word, width,
 * height) into [spr+7], [spr+8], [spr+5], [spr+6]; [spr] = 80h | depth; if the camera-relative
 * orientation (iso_orient_relative of [chr+1], >> 1) differs from the flip state [chr+6], the flip
 * routine [25AE]; [2912] = FF.  In: IY = chr, IX = spr. */
void chr_animate(uint16_t chr, uint16_t spr)
{
    uint16_t frame;
    uint8_t depth;
    frame = chr_select_frame(chr, spr);
    wb(D64_CHR_MOVED, 0xFF);
    if (chr_project_or_hide(chr, spr, &depth)) return;
    chr_show_frame(chr, spr, frame, depth);
}

/* 2589 chr_show_frame (label inside chr_animate, the JP target of 2096 in spr_update_char_sprite): the
 * 4-byte frame (graphics word, width, height) into [spr+7], [spr+8], [spr+5], [spr+6]; [spr] = 80h |
 * depth; if the camera-relative orientation (iso_orient_relative of [chr+1], >> 1) differs from the flip
 * state [chr+6], the flip routine [25AE]; [2912] = FF.  In: IY = chr, IX = spr, HL = frame, C = depth. */
void chr_show_frame(uint16_t chr, uint16_t spr, uint16_t frame, uint8_t depth)
{
    uint8_t o;
    wb((uint16_t)(spr + 7), rb(frame));
    wb((uint16_t)(spr + 8), rb((uint16_t)(frame + 1)));
    wb((uint16_t)(spr + 5), rb((uint16_t)(frame + 2)));
    wb((uint16_t)(spr + 6), rb((uint16_t)(frame + 3)));
    wb(spr, (uint8_t)(0x80 | depth));
    o = iso_orient_relative(rb((uint16_t)(chr + 1)));
    if ((uint8_t)(o >> 1) ^ rb((uint16_t)(chr + 6))) chr_flip(rw(D64_CHR_CUR_FLIP), spr);
    wb(D64_CHR_MOVED, 0xFF);
}

/* 25B6 chr_select_frame (PC 1000:24BE): the 4-byte animation entry of character chr, sprite spr.  o =
 * the camera-relative orientation, n = [chr]; the low nibble of [spr+0B] = 4o | n; index = 4 (((o+1) & 2)
 * 2 | n) (frames 0-3 for o = 0, 3; 4-7 for 1, 2).  A real table [25D9]: table + index.  The monks
 * ([25D9] = C0xx): the shared body table 2D30 + index, whose first word becomes the monk's face
 * [2BE8 + xx] (+32h on the frames with index bit 4).  In: IY = chr, IX = spr.  Out: HL. */
uint16_t chr_select_frame(uint16_t chr, uint16_t spr)
{
    uint8_t n = rb(chr), o, idx;
    uint16_t anim, entry, face;
    o = iso_orient_relative(rb((uint16_t)(chr + 1)));
    wb((uint16_t)(spr + 0x0B), (uint8_t)((rb((uint16_t)(spr + 0x0B)) & 0xF0) | (uint8_t)((uint8_t)(o << 2) | n)));
    idx = (uint8_t)((uint8_t)(((uint8_t)((uint8_t)(o + 1) & 2) << 1) | n) << 2);
    anim = rw(D64_CHR_CUR_ANIM);
    if (((anim >> 8) & 0xC0) != 0xC0) return (uint16_t)(idx + anim);
    entry = (uint16_t)(D64_CHR_ANIM_MONK + idx);
    face = rw(util_add_bx_al(D64_SPR_MONK_FACES, (uint8_t)anim));
    if (idx & 0x10) face = (uint16_t)(face + 0x32);
    ww(entry, face);
    return entry;
}

/* 2623 spr_mark_leaving (PC 1000:2545): the sprite spr stops being visible.  Nothing if it is inactive
 * (FE); else [spr] = 80h (redraw) and bit 7 of [spr+5] set (erase the old area).  In: IX = spr.
 * Out: A = the old [spr]. */
uint8_t spr_mark_leaving(uint16_t spr)
{
    uint8_t a = rb(spr);
    if (a == 0xFE) return a;
    wb(spr, 0x80);
    wb((uint16_t)(spr + 5), (uint8_t)(rb((uint16_t)(spr + 5)) | 0x80));
    return a;
}

/* 261E chr_project_or_hide (PC 1000:2540): chr_project.  Visible: false with *depth (the Z80's
 * chr_project drops its own return address, so its RET lands at 2588 in chr_animate).  Not visible:
 * spr_mark_leaving and true (the Z80 POPs its return address and chr_animate's saved HL, and the RET of
 * 2623 leaves chr_animate).  Not in the table: it does not return to its caller. */
bool chr_project_or_hide(uint16_t chr, uint16_t spr, uint8_t *depth)
{
    uint16_t screen;
    if (chr_project(chr, spr, depth, &screen)) return false;
    spr_mark_leaving(spr);
    return true;
}

/* 2632 chr_project (PC 1000:2556): projects character chr onto the screen.  Local x = [chr+2] - [2636],
 * y = [chr+3] - [2640], each < 28h; the floor of [chr+4] must be [264E]; h = height over it.  The camera
 * rotation [2656] turns (x, y); the result goes to [spr+12h,13h] (depth against the tiles).  Visible when
 * r = x+y-h-6 is in 8..39h (pixel row 4(r+1)) and the column 2(x-y)+28h in 0..4Fh: then the Z80 POPs its
 * return address (it returns to its caller's caller) and the depth is max(0, x+y-10h).  Test mode
 * ([2684] = C9h, set by 0AC2): returns there with *screen = row:column and the depth (in A; C is x+y
 * then).  Normal mode ([2684] = NOP): adds the per-orientation offset of the table [28D5] (+16 per
 * camera-relative orientation, +2 per frame chosen from [chr], [chr+5]) and [chr+7]/[chr+8], stores the
 * sprite x (bytes) and y (pixels) in [spr+1,2] (and [spr+3,4] when the sprite was inactive); depth in C.
 * Returns true when visible.  Not in the table: it does not return to its caller when visible. */
bool chr_project(uint16_t chr, uint16_t spr, uint8_t *depth, uint16_t *screen)
{
    uint8_t x, y, base, h, sum, r, row, col, ch, f5, s, o;
    uint16_t xy, dx;
    if (rb((uint16_t)(chr + 2)) < rb(D64_CHR_ROOM_ORIGIN_X)) return false;
    x = (uint8_t)(rb((uint16_t)(chr + 2)) - rb(D64_CHR_ROOM_ORIGIN_X));
    if (x >= 0x28) return false;
    if (rb((uint16_t)(chr + 3)) < rb(D64_CHR_ROOM_ORIGIN_Y)) return false;
    y = (uint8_t)(rb((uint16_t)(chr + 3)) - rb(D64_CHR_ROOM_ORIGIN_Y));
    if (y >= 0x28) return false;
    base = iso_floor_base(rb((uint16_t)(chr + 4)));
    if (base != rb(D64_CHR_ROOM_FLOOR)) return false;
    h = (uint8_t)(rb((uint16_t)(chr + 4)) - base);
    xy = camera_rotate((uint16_t)(y << 8 | x));
    x = (uint8_t)xy;
    y = (uint8_t)(xy >> 8);
    wb((uint16_t)(spr + 0x12), x);
    wb((uint16_t)(spr + 0x13), y);
    sum = (uint8_t)(y + x);
    if (sum < h) return false;
    r = (uint8_t)(sum - h);
    if (r < 6) return false;
    r = (uint8_t)(r - 6);
    if (r < 8 || r >= 0x3A) return false;
    row = (uint8_t)((uint8_t)(r + 1) << 2);
    col = (uint8_t)((uint8_t)((uint8_t)(x - y) << 1) + 0x50);
    if (col < 0x28) return false;
    col = (uint8_t)(col - 0x28);
    if (col >= 0x50) return false;
    /* visible (POP DE at 267D) */
    *depth = sum >= 0x10 ? (uint8_t)(sum - 0x10) : 0;
    if (rb(D64_CHR_PROJECT_TEST) == 0xC9) {
        *screen = (uint16_t)(row << 8 | col);
        return true;
    }
    ch = 0;
    f5 = rb((uint16_t)(chr + 5));
    if (f5 & 0x80) {                    /* 26CD: the frames of a 1-cell character (stairs) */
        ch = (uint8_t)(ch + 2);
        if (f5 & 0x20) goto half;
        ch = (uint8_t)(ch + 2);
        s = (uint8_t)(f5 & 3);
        if (s == 0) {
            if (!(rb(chr) & 1)) goto frame;
            ch++;
        } else {
            ch = (uint8_t)(ch + 3);
            if (!(f5 & 0x40)) ch = (uint8_t)(ch + 4);
            if (s == 1) ch = (uint8_t)(ch + 2);
        }
        if (f5 & 0x10) ch++;            /* 26E5: descending */
        goto frame;
    }
half:                                   /* 268F: half step */
    if (rb(chr) & 1) ch++;
frame:                                  /* 2696 */
    dx = rw(D64_CHR_SPRITE_OFFSETS);
    o = iso_orient_relative(rb((uint16_t)(chr + 1)));
    o = (uint8_t)(((uint8_t)(o >> 4) | (uint8_t)(o << 4)) & 0x30);
    o = (uint8_t)(o + ch + ch);
    dx = (uint16_t)(dx + o);
    col = (uint8_t)(rb(dx) + col + rb((uint16_t)(chr + 7)));
    dx = (uint16_t)(dx + 1);
    row = (uint8_t)(rb(dx) + row + rb((uint16_t)(chr + 8)));
    wb((uint16_t)(spr + 1), col);
    wb((uint16_t)(spr + 2), row);
    if (rb(spr) == 0xFE) {
        wb((uint16_t)(spr + 3), col);
        wb((uint16_t)(spr + 4), row);
    }
    *screen = (uint16_t)(row << 8 | col);
    return true;
}

/* ================================================================== the command streams */

/* 2765 chr_command_bit (PC 1000:26A5): the next bit (MSB first) of the command stream of character chr:
 * when the bit counter [chr+9] is 0, [chr+0A] = [word [chr+0C] + index [chr+0B]] and the index
 * advances; counter = (counter + 1) & 7; [chr+0A] <<= 1.  In: IY = chr.  Out: CF = the bit shifted out
 * (A = the new [chr+0A]). */
bool chr_command_bit(uint16_t chr)
{
    uint8_t v;
    uint16_t addr;
    if (rb((uint16_t)(chr + 9)) == 0) {
        addr = (uint16_t)(rw((uint16_t)(chr + 0x0C)) + rb((uint16_t)(chr + 0x0B)));
        wb((uint16_t)(chr + 0x0B), (uint8_t)(rb((uint16_t)(chr + 0x0B)) + 1));
        wb((uint16_t)(chr + 0x0A), rb(addr));
    }
    wb((uint16_t)(chr + 9), (uint8_t)((rb((uint16_t)(chr + 9)) + 1) & 7));
    v = rb((uint16_t)(chr + 0x0A));
    wb((uint16_t)(chr + 0x0A), (uint8_t)(v << 1));
    return (v & 0x80) != 0;
}

/* 28AD chr_backup_args (PC 1000:2834): the arguments of the LDIR that copies the character's position
 * block to or from the backup: *src = chr + 2 (HL), *dst = 28B9 (DE), *len = 10 (BC).  In: IY = chr. */
void chr_backup_args(uint16_t chr, uint16_t *src, uint16_t *dst, uint16_t *len)
{
    *src = (uint16_t)(chr + 2);
    *dst = D64_CHR_BACKUP;
    *len = 10;
}

/* 280D chr_read_command (PC 1000:277A): decodes one command from the bit stream of character chr into
 * *cmd (C) and returns false.  1-cell: '1b' -> b.  2x2: '1' -> 1.  Both: '01b' -> 2+b (turn), '001b' ->
 * 4+b, '0000' -> 0 for a 1-cell character, or the stream restarts ([chr+0B] = [chr+9] = 0) and is read
 * again (2x2).  '0001' = end of the commands: bit 7 of [chr+9] set and true (the Z80 POPs its return
 * address and the step pushed by 278F and returns from 278F).  Not in the table. */
bool chr_read_command(uint16_t chr, uint8_t *cmd)
{
    uint8_t c;
    for (;;) {
        if (rb((uint16_t)(chr + 5)) & 0x80) {
            if (chr_command_bit(chr)) {
                *cmd = chr_command_bit(chr) ? 1 : 0;
                return false;
            }
        } else if (chr_command_bit(chr)) {
            *cmd = 1;
            return false;
        }
        c = 1;                          /* 2823 */
        if (chr_command_bit(chr)) {
            *cmd = (uint8_t)((c << 1) | (chr_command_bit(chr) ? 1 : 0));
            return false;
        }
        c = (uint8_t)(c << 1);          /* 2831 */
        if (chr_command_bit(chr)) {
            *cmd = (uint8_t)((c << 1) | (chr_command_bit(chr) ? 1 : 0));
            return false;
        }
        if (chr_command_bit(chr)) {     /* 284E: the end */
            wb((uint16_t)(chr + 9), (uint8_t)(rb((uint16_t)(chr + 9)) | 0x80));
            return true;
        }
        if (rb((uint16_t)(chr + 5)) & 0x80) {
            *cmd = 0;
            return false;
        }
        wb((uint16_t)(chr + 0x0B), 0);
        wb((uint16_t)(chr + 9), 0);
    }
}

/* 278F chr_ai_follow_commands (PC 1000:26D6): behaviour routine of Adso and the monks.  Nothing when bit 7
 * of [chr+9] (no commands).  Saves the 10 bytes [chr+2..0B] to 28B9, reads a command (280D; the end of
 * the stream returns from here): 3 turns +1, 2 turns -1; otherwise (A, C) = the height differences
 * assumed when the character is off the floor shown (2x2: 1 -> (0,FF), 5 -> (FF,FF), others (1,FF);
 * 1-cell: 0 -> (0,0) if bit 5 of [chr+5] else (1,2), 1 -> (FF,FE), 4 -> (1,1), others (FF,FF)),
 * [2912] = 0, chr_probe_ahead and chr_try_advance with the step entry + 6; if [2912] is still 0 the 10
 * bytes are restored.  In: IY = chr, IX = spr. */
void chr_ai_follow_commands(uint16_t chr, uint16_t spr)
{
    uint16_t step, src, dst, len, i, bx;
    uint8_t cmd, al, cl;
    if (rb((uint16_t)(chr + 9)) & 0x80) return;
    step = (uint16_t)(chr_step_table(chr) + 6);
    chr_backup_args(chr, &src, &dst, &len);
    for (i = 0; i < len; ++i) wb((uint16_t)(dst + i), rb((uint16_t)(src + i)));
    cmd = 0;
    if (chr_read_command(chr, &cmd)) return;
    if (cmd == 3) { chr_turn(chr, spr, 1); return; }
    if (cmd == 2) { chr_turn(chr, spr, 0xFF); return; }
    if (!(rb((uint16_t)(chr + 5)) & 0x80)) {
        cl = 0xFF;
        al = cmd == 1 ? 0 : cmd == 5 ? 0xFF : 1;
    } else if (cmd == 0) {
        if (rb((uint16_t)(chr + 5)) & 0x20) { al = 0; cl = 0; }
        else { cl = 2; al = 1; }
    } else if (cmd == 1) {
        cl = 0xFE; al = 0xFF;
    } else if (cmd == 4) {
        cl = 1; al = 1;
    } else {
        cl = 0xFF; al = 0xFF;
    }
    wb(D64_CHR_MOVED, 0);
    bx = step;
    al = chr_probe_ahead(chr, al, &cl, &bx);
    chr_try_advance(chr, spr, al, cl, bx);
    if (rb(D64_CHR_MOVED) != 0) return;
    chr_backup_args(chr, &src, &dst, &len);
    for (i = 0; i < len; ++i) wb((uint16_t)(src + i), rb((uint16_t)(dst + i)));
}

/* ================================================================== rooms, the clock */

/* 2855 iso_select_room (PC 1000:27C8): [290E] = room; [11DA] = the address of record `room` of the room
 * table 6100 (each record starts with its length byte).  The DI / EI and the LD BC,7FC7h / 7FC0h around
 * the walk are what is left of the 6128's bank switching (the OUTs are gone).  In: A = room. */
void iso_select_room(uint8_t room)
{
    uint16_t p = D64_ISO_ROOM_TABLE;
    uint8_t n;
    wb(D64_ISO_ROOM_NUMBER, room);
    if (room != 0) {
        plat_di();
        for (n = room; n; --n) p = (uint16_t)(p + rb(p));
        plat_ei();
    }
    ww(D64_ISO_ROOM_PTR, p);
}

/* 2899 sys_tick (PC 1000:281E): the 300 Hz interrupt handler (RST 38h jumps here; 0039 is set by
 * 20F8): DI; the tick counter [289C] + 1, kept at FFh; f_0CD0 (the sound); txt_phrase_tick; EI; RETI.
 * A and the flags are preserved (PUSH AF / POP AF). */
void sys_tick(void)
{
    uint8_t t;
    plat_di();
    t = (uint8_t)(rb(D64_SYS_TICKS) + 1);
    if (t != 0) wb(D64_SYS_TICKS, t);
    snd_interrupt();                    /* 28A3 CALL 0CD0 */
    txt_phrase_tick();                  /* CALL 368A */
    plat_ei();
}

/* ================================================================== the keyboard */

/* 2D50 sys_read_keyboard (PC 1000:2D6F): reads the 10 rows of the keyboard matrix (plat_teclado_fila,
 * the PPI/PSG port sequence of 2D51-2D96) into the keys-down bitmap 2DE8 (0 = down) and updates the
 * pending presses 2DF2: pending = (pending & ~(now | before)) | now (a bit goes to 0 on a new press and
 * stays 0 until sys_key_pressed consumes it).  Returns with the interrupts off (DI; the caller does EI). */
void sys_read_keyboard(void)
{
    uint8_t row, now, held;
    uint16_t down = D64_SYS_KEYS_DOWN, pending = D64_SYS_KEYS_PENDING;
    plat_di();
    for (row = 0; row < 10; ++row) {
        now = plat_teclado_fila(row);
        held = (uint8_t)~(now | rb(down));
        wb(down, now);
        wb(pending, (uint8_t)((rb(pending) & held) | now));
        down = (uint16_t)(down + 1);
        pending = (uint16_t)(pending + 1);
    }
}

/* 2E98 sys_key_bit (PC 1000:2F58; listed as sys_test_key): *byte = bitmap + key / 8, *mask = 2EB3 +
 * key % 8; returns ~[*byte] & [*mask] (not 0: the key is down / has a pending press).  In: A = key,
 * DE = bitmap.  Out: A (ZF), C = key, DE = *byte, HL = *mask. */
uint8_t sys_key_bit(uint8_t key, uint16_t bitmap, uint16_t *byte, uint16_t *mask)
{
    *byte = (uint16_t)(bitmap + (uint8_t)(key >> 3));
    *mask = (uint16_t)(D64_SYS_BIT_MASKS + (key & 7));
    return (uint8_t)(~rb(*byte) & rb(*mask));
}

/* 2E42 sys_test_key (PC 1000:2EEB): is key (a CPC key number) down in the bitmap?  Keys 8 (left), 2Fh
 * (space), 0, 1, 2 (up, right, down) also accept their aliases (lists ending in FF at 2E2E, 2E32, 2E36 +
 * 4k); any other key is tried alone (2E2C = key, FF).  Writes the operand [2E6A] (the bitmap) and
 * [2E2C].  Out: A = the nonzero bit of the first code found, or 0 (ZF); *code (C), *byte (DE), *mask
 * (HL) = of that code, or of the last one tried.  In: A = key, DE = bitmap. */
uint8_t sys_test_key(uint8_t key, uint16_t bitmap, uint8_t *code, uint16_t *byte, uint16_t *mask)
{
    uint16_t list;
    uint8_t r;
    ww(D64_SYS_KEY_BITMAP, bitmap);
    wb(D64_SYS_KEY_SINGLE, key);
    if (key == 8) list = D64_SYS_KEY_ALIAS_LEFT;
    else if (key == 0x2F) list = D64_SYS_KEY_ALIAS_SPACE;
    else if (key >= 3) list = D64_SYS_KEY_SINGLE;
    else list = util_add_bx_al(D64_SYS_KEY_ALIAS_012, (uint8_t)(key * 4));
    for (;;) {
        *code = rb(list);
        list = (uint16_t)(list + 1);
        r = sys_key_bit(*code, rw(D64_SYS_KEY_BITMAP), byte, mask);
        if (r != 0) return r;
        if (rb(list) >= 0xFF) return 0;
    }
}

/* 2E7D sys_key_pressed (PC 1000:2F30): edge test: not 0 (NZ) when key has a pending press in 2DF2; the
 * pending bit of the code tested last is set (the press is consumed).  In: A = key.  Out: A, ZF, C =
 * *code (the code tested last); HL, DE preserved. */
uint8_t sys_key_pressed(uint8_t key, uint8_t *code)
{
    uint16_t byte, mask;
    uint8_t r = sys_test_key(key, D64_SYS_KEYS_PENDING, code, &byte, &mask);
    wb(byte, (uint8_t)(rb(byte) | rb(mask)));
    return r;
}

/* 2E8D sys_key_down (PC 1000:2F4D): level test: not 0 (NZ) when key (or an alias) is down in 2DE8.
 * In: A = key.  Out: A, ZF, C = *code; HL, DE preserved. */
uint8_t sys_key_down(uint8_t key, uint8_t *code)
{
    uint16_t byte, mask;
    return sys_test_key(key, D64_SYS_KEYS_DOWN, code, &byte, &mask);
}

/* ================================================================== the input step and the mirror */

/* 2DFC game_check_qr_mirror (PC 1000:2EAB): 0 unless Guillermo stands at x = 22h, height 1Ah with the
 * keys Q (43h) and R (32h) down; then 1, 2, 3 for y = 6Dh, 69h, 65h (the three steps), 0 for any other
 * y.  Out: E (IX = 2B87). */
uint8_t game_check_qr_mirror(void)
{
    uint8_t y, code;
    if (rb(D64_CHR_GUILLERMO + 2) != 0x22) return 0;
    if (rb(D64_CHR_GUILLERMO + 4) != 0x1A) return 0;
    if (!sys_key_down(0x43, &code)) return 0;
    if (!sys_key_down(0x32, &code)) return 0;
    y = rb(D64_CHR_GUILLERMO + 3);
    if (y == 0x6D) return 1;
    if (y == 0x69) return 2;
    if (y == 0x65) return 3;
    return 0;
}

/* 2D99 game_input_and_mirror (PC 1000:2DD8): input step of the main loop: sys_read_keyboard, EI.  While
 * the mirror is closed ([28DD]): game_check_qr_mirror; with Q+R down on a step 1-3: a numeral [290D] other
 * than 4 sets bit 2 of [2910]; the numeral = the step opens the mirror (height byte FF at [[2EDE]], byte
 * 51h at [[2EE5]], between DI and EI); numeral 4 or another step is the trap ([37E4] = 1, [23E4] = 14h,
 * byte 6Bh two bytes before [[2EE5]], 4B71 with its inline phrase 22h at 2DCC, then JR 2DDD).  Both:
 * [28C6] = 0 (the room is rebuilt), [28DD] = 0, snd_stub_mirror_open (0C6D).  The 64K has no
 * equivalent of the PC's [B843] = 0. */
void game_input_and_mirror(void)
{
    uint8_t step, numeral;
    uint16_t p;
    sys_read_keyboard();
    plat_ei();
    if (rb(D64_OBJ_MIRROR_CLOSED) == 0) return;
    step = game_check_qr_mirror();
    if (step == 0) return;
    numeral = rb(D64_OBJ_MIRROR_NUMERAL);
    if (numeral != 4) {
        wb(D64_GAME_BONUS, (uint8_t)(rb(D64_GAME_BONUS) | 4));
        if (numeral == step) {          /* 2DCF: the mirror opens */
            plat_di();
            wb(rw(D64_OBJ_MIRROR_HEIGHT_PTR), 0xFF);
            wb(rw(D64_OBJ_MIRROR_ENTRY_PTR), 0x51);
            plat_ei();
            goto fin;
        }
    }
    wb(D64_GAME_GUILLERMO_DEAD, 1);     /* 2DB7: the trap */
    wb(D64_CHR_GUILLERMO_STATE, 0x14);
    p = (uint16_t)(rw(D64_OBJ_MIRROR_ENTRY_PTR) - 2);
    wb(p, 0x6B);
    hud_say_now(0x22);                  /* 2DC9 CALL 4B71 <22h> */
fin:
    wb(D64_CHR_ROOM_X, 0);
    wb(D64_OBJ_MIRROR_CLOSED, 0);
    snd_play_mirror_open();             /* 2DE4 CALL 0C6D */
}

/* 2EBB obj_init_mirror (PC 1000:2F86): start of a game: [28DD] = 1 (the mirror is closed), [290D] = 0
 * (no numeral yet), then obj_close_mirror (fall-through). */
void obj_init_mirror(void)
{
    wb(D64_OBJ_MIRROR_CLOSED, 1);
    wb(D64_OBJ_MIRROR_NUMERAL, 0);
    obj_close_mirror();
}

/* 2EC4 obj_close_mirror (PC 1000:2F90): between DI and EI, copies the 5 'mirror closed' height bytes
 * 2EE0 to [2EDE]; byte 11h into the mirror entry [2EE5] and 1Fh two bytes before it. */
void obj_close_mirror(void)
{
    uint16_t dst = rw(D64_OBJ_MIRROR_HEIGHT_PTR), p;
    uint8_t i;
    plat_di();
    for (i = 0; i < 5; ++i) wb((uint16_t)(dst + i), rb((uint16_t)(D64_OBJ_MIRROR_CLOSED_HEIGHTS + i)));
    p = rw(D64_OBJ_MIRROR_ENTRY_PTR);
    wb(p, 0x11);
    wb((uint16_t)(p - 2), 0x1F);
    plat_ei();
}

/* ================================================================== the sprite flips */

/* a CPC mode 1 byte mirrored: its 4 pixels (bits 7/3, 6/2, 5/1, 4/0) in the reverse order (2F6E-2F81:
 * the bits of each nibble reversed) */
static uint8_t flip_byte(uint8_t b)
{
    return (uint8_t)(((b & 0x11) << 3) | ((b & 0x22) << 1) | ((b & 0x44) >> 1) | ((b & 0x88) >> 3));
}

/* 2F57 spr_flip_graphics_h (PC 1000:3028): mirrors in place `rows` rows of `width` contiguous bytes from
 * p: in every row byte i and byte width-1-i are swapped, both mirrored (flip_byte); (width+1)/2 swaps a
 * row, so the middle byte of an odd row is mirrored once.  rows = 0 means 256.  The row width is kept in
 * the operand [2FA3].  In: HL = p, C = width, B = rows.  (The Z80 returns with the register banks
 * exchanged: EXX.) */
void spr_flip_graphics_h(uint16_t p, uint8_t width, uint8_t rows)
{
    uint16_t start = p, s, e, w;
    uint8_t n, swaps, fe, fs;
    ww(D64_SPR_FLIP_WIDTH, width);
    swaps = (uint8_t)((uint8_t)(width + 1) >> 1);
    e = (uint16_t)(p + (uint8_t)(width - 1));
    do {
        s = start;
        n = swaps;
        do {
            fe = flip_byte(rb(e));
            fs = flip_byte(rb(s));
            wb(e, fs);
            wb(s, fe);
            e = (uint16_t)(e - 1);
            s = (uint16_t)(s + 1);
        } while (--n);
        w = rw(D64_SPR_FLIP_WIDTH);
        start = (uint16_t)(start + w);
        e = (uint16_t)(start + ((w & 0xFF00) | (uint8_t)(w - 1)));
    } while (--rows);
}

/* 2EE7 spr_flip_adso (PC 1000:2FB4): flip routine of Adso: toggles his flip state [2B9C] and mirrors his
 * 5-byte-wide frames (A6EA, 5Fh lines) and 4-byte-wide frames (A8C5, 5Ah lines). */
void spr_flip_adso(void)
{
    wb(D64_CHR_ADSO + 6, (uint8_t)(rb(D64_CHR_ADSO + 6) ^ 1));
    spr_flip_graphics_h(D64_SPR_ADSO_GFX_W5, 5, 0x5F);
    spr_flip_graphics_h(D64_SPR_ADSO_GFX_W4, 4, 0x5A);
}

/* 2F00 spr_flip_malachi (PC 1000:2FCD): flip routine of the 3rd character: [2BAB] ^= 1 and mirrors his
 * face [2BE8] (5 bytes x 14h lines). */
void spr_flip_malachi(void)
{
    wb(D64_CHR_MALACHI + 6, (uint8_t)(rb(D64_CHR_MALACHI + 6) ^ 1));
    spr_flip_graphics_h(rw(D64_SPR_MONK_FACES), 5, 0x14);
}

/* 2F10 spr_flip_abbot (PC 1000:2FDE): the Abbot: [2BBA] ^= 1, face [2BEA]. */
void spr_flip_abbot(void)
{
    wb(D64_CHR_ABBOT + 6, (uint8_t)(rb(D64_CHR_ABBOT + 6) ^ 1));
    spr_flip_graphics_h(rw(D64_SPR_MONK_FACES + 2), 5, 0x14);
}

/* 2F20 spr_flip_berengar (PC 1000:2FEF): Berengar: [2BC9] ^= 1, face [2BEC]. */
void spr_flip_berengar(void)
{
    wb(D64_CHR_BERENGAR + 6, (uint8_t)(rb(D64_CHR_BERENGAR + 6) ^ 1));
    spr_flip_graphics_h(rw(D64_SPR_MONK_FACES + 4), 5, 0x14);
}

/* 2F30 spr_flip_severin (PC 1000:3000): Severin: [2BD8] ^= 1, face [2BEE]. */
void spr_flip_severin(void)
{
    wb(D64_CHR_SEVERIN + 6, (uint8_t)(rb(D64_CHR_SEVERIN + 6) ^ 1));
    spr_flip_graphics_h(rw(D64_SPR_MONK_FACES + 6), 5, 0x14);
}

/* 2F40 spr_flip_guillermo (PC 1000:3011): Guillermo: [2B8D] ^= 1, his 5-byte-wide frames (A300, AEh
 * lines) and 4-byte-wide frames (A666, 21h lines). */
void spr_flip_guillermo(void)
{
    wb(D64_CHR_GUILLERMO + 6, (uint8_t)(rb(D64_CHR_GUILLERMO + 6) ^ 1));
    spr_flip_graphics_h(D64_SPR_GUILLERMO_GFX_W5, 5, 0xAE);
    spr_flip_graphics_h(D64_SPR_GUILLERMO_GFX_W4, 4, 0x21);
}

#ifndef JUEGO_PURO  /* the hybrid host */
/* ======================================================================================================
 * The wrappers (registers -> parameters, results -> registers, RET) and the checks of their results.
 * ====================================================================================================== */

static int c8(const char *nombre, uint8_t c, uint8_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %02X Z80 %02X", nombre, c, z);
    return 0;
}

static int c16(const char *nombre, uint16_t c, uint16_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %04X Z80 %04X", nombre, c, z);
    return 0;
}

#define R_HL(z) ((uint16_t)((z)->h << 8 | (z)->l))
#define R_DE(z) ((uint16_t)((z)->d << 8 | (z)->e))
#define R_BC(z) ((uint16_t)((z)->b << 8 | (z)->c))

/* the general-purpose registers and flags an interrupt handler must leave as it found them */
static int r_todo(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c16("BC", R_BC(cz), R_BC(zz), msg, n);
    ok &= c16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= c16("IX", cz->ix, zz->ix, msg, n);
    ok &= c16("IY", cz->iy, zz->iy, msg, n);
    ok &= c8("F", (uint8_t)(cz->sf << 7 | cz->zf << 6 | cz->yf << 5 | cz->hf << 4 | cz->xf << 3 | cz->pf << 2 | cz->nf << 1 | cz->cf),
             (uint8_t)(zz->sf << 7 | zz->zf << 6 | zz->yf << 5 | zz->hf << 4 | zz->xf << 3 | zz->pf << 2 | zz->nf << 1 | zz->cf), msg, n);
    ok &= c8("IFF", (uint8_t)(cz->iff1 << 1 | cz->iff2), (uint8_t)(zz->iff1 << 1 | zz->iff2), msg, n);
    return ok;
}

static int r_iff(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    return c8("IFF", (uint8_t)(cz->iff1 << 1 | cz->iff2), (uint8_t)(zz->iff1 << 1 | zz->iff2), msg, n);
}

/* 2226 */
static void w_2226(void) { uint16_t sp = cpu.sp; game_run_npc_behaviours(sp); cpu.sp = sp; z80_ret(); }

/* 2236, 2265, 22D4 */
static void w_2236(void) { uint16_t sp = cpu.sp; spr_draw_or_darken(sp); cpu.sp = sp; z80_ret(); }
static void w_2265(void) { uint16_t sp = cpu.sp; spr_place_light(sp); cpu.sp = sp; z80_ret(); }
static void w_22D4(void) { vid_clear_play_area(); z80_ret(); }

/* 22D8, 22E7: HL (A = H) */
static void w_22D8(void) { uint16_t hl = chr_step_table(cpu.iy); SET_HL(hl); cpu.a = cpu.h; z80_ret(); }
static void w_22E7(void) { uint16_t hl = util_add_bx_8al(HL, cpu.a); SET_HL(hl); cpu.a = cpu.h; z80_ret(); }
static int r_hl_a(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= c8("A", cz->a, zz->a, msg, n);
    return ok;
}

/* 22F0: HL, CF */
static void w_22F0(void)
{
    uint16_t pos = HL;
    cpu.cf = chr_to_hbuf_coords(&pos);
    SET_HL(pos);
    z80_ret();
}
static int r_22F0(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= c8("CF", cz->cf, zz->cf, msg, n);
    return ok;
}

/* 2309, 230D, 2320: A, C, HL */
static void w_2309(void)
{
    uint8_t c = cpu.c;
    uint16_t hl = HL;
    cpu.a = chr_probe_ahead_flat(cpu.iy, cpu.a, &c, &hl);
    cpu.c = c;
    SET_HL(hl);
    z80_ret();
}
static void w_230D(void)
{
    uint8_t c = cpu.c;
    uint16_t hl = HL;
    cpu.a = chr_probe_ahead(cpu.iy, cpu.a, &c, &hl);
    cpu.c = c;
    SET_HL(hl);
    z80_ret();
}
static void w_2320(void)
{
    uint8_t c = cpu.c;
    uint16_t hl = HL;
    cpu.a = chr_probe_cells(cpu.iy, cpu.a, cpu.b, &c, &hl);
    cpu.c = c;
    SET_HL(hl);
    z80_ret();
}
static int r_probe(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c8("C", cz->c, zz->c, msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    return ok;
}

/* 23E2: from the JP (HL) of 24A5 */
static void w_23E2(void) { chr_guillermo_behaviour(cpu.iy, cpu.ix, HL); z80_ret(); }

/* 2444: IX */
static void w_2444(void) { cpu.ix = chr_mark_hbuf(cpu.iy, cpu.c, cpu.ix); z80_ret(); }
static int r_ix(const z80 *cz, const z80 *zz, char *msg, size_t n) { return c16("IX", cz->ix, zz->ix, msg, n); }

/* 2472: IX, IY */
static void w_2472(void)
{
    cpu.ix = chr_update(HL);
    cpu.iy = rw(D64_CHR_CUR_DATA);
    z80_ret();
}
static int r_ix_iy(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c16("IX", cz->ix, zz->ix, msg, n);
    ok &= c16("IY", cz->iy, zz->iy, msg, n);
    return ok;
}

/* 249A: ZF in (NZ: Malachi rising) */
static void w_249A(void) { chr_think_or_step(!cpu.zf, cpu.iy, cpu.ix); z80_ret(); }

/* 24A9, 250C, 2549, 2553, 2561, 257C */
static void w_24A9(void) { chr_try_advance(cpu.iy, cpu.ix, cpu.a, cpu.c, HL); z80_ret(); }
static void w_250C(void) { chr_try_advance_2x2(cpu.iy, cpu.ix, cpu.a, HL); z80_ret(); }
static void w_2549(void) { chr_step_level(cpu.iy, cpu.ix, HL); z80_ret(); }
static void w_2553(void) { chr_step_and_animate(cpu.iy, cpu.ix, HL); z80_ret(); }
static void w_2561(void) { chr_turn(cpu.iy, cpu.ix, cpu.c); z80_ret(); }
static void w_257C(void) { chr_animate(cpu.iy, cpu.ix); z80_ret(); }

/* 2503: A, ZF */
static void w_2503(void)
{
    cpu.a = chr_orientation_parity(cpu.iy);
    cpu.zf = cpu.a == 0;
    z80_ret();
}
static int r_a_zf(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c8("ZF", cz->zf, zz->zf, msg, n);
    return ok;
}

/* 2539: A, HL = step + 1 */
static void w_2539(void)
{
    uint16_t step = HL;
    cpu.a = chr_apply_step(cpu.iy, step);
    step = (uint16_t)(step + 1);
    SET_HL(step);
    z80_ret();
}

/* 25B6: HL */
static void w_25B6(void) { uint16_t hl = chr_select_frame(cpu.iy, cpu.ix); SET_HL(hl); z80_ret(); }
static int r_hl(const z80 *cz, const z80 *zz, char *msg, size_t n) { return c16("HL", R_HL(cz), R_HL(zz), msg, n); }

/* 2605: A */
static void w_2605(void) { cpu.a = spr_save_old_rect(cpu.ix); z80_ret(); }
static int r_a(const z80 *cz, const z80 *zz, char *msg, size_t n) { return c8("A", cz->a, zz->a, msg, n); }

/* 2623: A, ZF */
static void w_2623(void)
{
    cpu.a = spr_mark_leaving(cpu.ix);
    cpu.zf = cpu.a == 0xFE;
    z80_ret();
}

/* 274B: HL = entry + 10, IX = 274B, B = 0, DE = last target + 1, A = the last byte */
static void w_274B(void)
{
    uint16_t entry = HL;
    chr_load_params(entry);
    SET_HL((uint16_t)(entry + 10));
    cpu.ix = (uint16_t)(D64_CHR_PARAM_TARGETS + 10);
    cpu.b = 0;
    SET_DE((uint16_t)(rw(D64_CHR_PARAM_TARGETS + 8) + 1));
    cpu.a = rb((uint16_t)(entry + 9));
    z80_ret();
}
static int r_274B(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c8("B", cz->b, zz->b, msg, n);
    ok &= c16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= c16("IX", cz->ix, zz->ix, msg, n);
    return ok;
}

/* 2765: CF, A = the new [chr+0A], ZF */
static void w_2765(void)
{
    cpu.cf = chr_command_bit(cpu.iy);
    cpu.a = rb((uint16_t)(cpu.iy + 0x0A));
    cpu.zf = cpu.a == 0;
    z80_ret();
}
static int r_2765(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c8("CF", cz->cf, zz->cf, msg, n);
    ok &= c8("ZF", cz->zf, zz->zf, msg, n);
    return ok;
}

/* 278F: from the JP (HL) of 24A5 */
static void w_278F(void) { chr_ai_follow_commands(cpu.iy, cpu.ix); z80_ret(); }

/* 2855: HL, A = H (0 for room 0), BC = 7FC0h after the walk; IFF */
static void w_2855(void)
{
    uint8_t room = cpu.a;
    uint16_t p;
    iso_select_room(room);
    p = rw(D64_ISO_ROOM_PTR);
    SET_HL(p);
    cpu.a = room ? cpu.h : 0;
    if (room) SET_BC(0x7FC0);
    z80_ret();
}
static int r_2855(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c16("BC", R_BC(cz), R_BC(zz), msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= r_iff(cz, zz, msg, n);
    return ok;
}

/* 2873 */
static void w_2873(void) { chr_fill_height_buffer(cpu.iy); z80_ret(); }

/* 2899: the interrupt handler: A and F come back (PUSH AF / POP AF), RETI */
static void w_2899(void)
{
    uint8_t a = cpu.a;
    bool sf = cpu.sf, zf = cpu.zf, yf = cpu.yf, hf = cpu.hf, xf = cpu.xf, pf = cpu.pf, nf = cpu.nf, cf = cpu.cf;
    sys_tick();
    cpu.a = a;
    cpu.sf = sf; cpu.zf = zf; cpu.yf = yf; cpu.hf = hf; cpu.xf = xf; cpu.pf = pf; cpu.nf = nf; cpu.cf = cf;
    z80_ret();                          /* RETI */
}

/* 28AD: HL, DE, BC */
static void w_28AD(void)
{
    uint16_t src, dst, len;
    chr_backup_args(cpu.iy, &src, &dst, &len);
    SET_HL(src);
    SET_DE(dst);
    SET_BC(len);
    z80_ret();
}
static int r_hl_de_bc(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c16("BC", R_BC(cz), R_BC(zz), msg, n);
    ok &= c16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    return ok;
}

/* 2D50: A = 82h, HL = 2DF2, DE = 2DFC, B = F6h (C = the port C bits); interrupts off */
static void w_2D50(void)
{
    sys_read_keyboard();
    cpu.a = 0x82;
    SET_HL(D64_SYS_KEYS_DOWN + 10);
    SET_DE(D64_SYS_KEYS_PENDING + 10);
    cpu.b = 0xF6;
    z80_ret();
}
static int r_2D50(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c8("B", cz->b, zz->b, msg, n);
    ok &= c16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= r_iff(cz, zz, msg, n);
    return ok;
}

/* 2D99 */
static void w_2D99(void) { game_input_and_mirror(); z80_ret(); }

/* 2DFC: E, IX = 2B87 */
static void w_2DFC(void)
{
    cpu.e = game_check_qr_mirror();
    cpu.ix = D64_CHR_GUILLERMO;
    z80_ret();
}
static int r_2DFC(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("E", cz->e, zz->e, msg, n);
    ok &= c16("IX", cz->ix, zz->ix, msg, n);
    return ok;
}

/* 2E42, 2E98: A, ZF, C, DE, HL */
static void w_2E42(void)
{
    uint8_t code;
    uint16_t byte, mask;
    cpu.a = sys_test_key(cpu.a, DE, &code, &byte, &mask);
    cpu.zf = cpu.a == 0;
    cpu.cf = 0;
    cpu.c = code;
    SET_DE(byte);
    SET_HL(mask);
    z80_ret();
}
static void w_2E98(void)
{
    uint16_t byte, mask;
    uint8_t key = cpu.a;
    cpu.a = sys_key_bit(key, DE, &byte, &mask);
    cpu.zf = cpu.a == 0;
    cpu.cf = 0;
    cpu.c = key;
    SET_DE(byte);
    SET_HL(mask);
    z80_ret();
}
static int r_key(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c8("ZF", cz->zf, zz->zf, msg, n);
    ok &= c8("CF", cz->cf, zz->cf, msg, n);
    ok &= c8("C", cz->c, zz->c, msg, n);
    ok &= c16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    return ok;
}

/* 2E7D, 2E8D: A, ZF, C; HL, DE preserved (PUSH/POP) */
static void w_2E7D(void)
{
    uint8_t code;
    uint16_t hl = HL, de = DE;
    cpu.a = sys_key_pressed(cpu.a, &code);
    SET_HL(hl);
    SET_DE(de);
    cpu.zf = cpu.a == 0;
    cpu.cf = 0;
    cpu.c = code;
    z80_ret();
}
static void w_2E8D(void)
{
    uint8_t code;
    uint16_t hl = HL, de = DE;
    cpu.a = sys_key_down(cpu.a, &code);
    SET_HL(hl);
    SET_DE(de);
    cpu.zf = cpu.a == 0;
    cpu.cf = 0;
    cpu.c = code;
    z80_ret();
}

/* 2EBB, 2EC4: A = 1Fh, BC = 0, DE = [2EDE] + 5, HL = [2EE5] - 2; interrupts on */
static void regs_close_mirror(void)
{
    cpu.a = 0x1F;
    SET_BC(0);
    SET_DE((uint16_t)(rw(D64_OBJ_MIRROR_HEIGHT_PTR) + 5));
    SET_HL((uint16_t)(rw(D64_OBJ_MIRROR_ENTRY_PTR) - 2));
}
static void w_2EBB(void) { obj_init_mirror(); regs_close_mirror(); z80_ret(); }
static void w_2EC4(void) { obj_close_mirror(); regs_close_mirror(); z80_ret(); }
static int r_mirror(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= r_hl_de_bc(cz, zz, msg, n);
    ok &= r_iff(cz, zz, msg, n);
    return ok;
}

/* the registers one call of 2F57 leaves (p = HL, width = C, rows = B at its entry): it returns with the
 * banks exchanged (EXX), so the caller's BC DE HL are the entry's BC' DE' HL' with B = 0, C = the swaps
 * of a row, L = 0, and its BC' DE' HL' are the pointers of the last row (BC = its last end byte - 1, DE =
 * the next row, HL = the next row's end); A = the byte stored last at the row start, A' = the one
 * stored last at its end. */
static void regs_flip(uint16_t p, uint8_t width, uint8_t rows)
{
    uint8_t swaps = (uint8_t)((uint8_t)(width + 1) >> 1);
    unsigned n = swaps ? swaps : 256u, r = rows ? rows : 256u;
    uint16_t s_last = (uint16_t)(p + (r - 1) * width);
    uint16_t e_last = (uint16_t)(s_last + (uint8_t)(width - 1));
    uint16_t bc = (uint16_t)(e_last - n), de = (uint16_t)(s_last + width), hl = (uint16_t)(de + (uint8_t)(width - 1));
    cpu.a = rb((uint16_t)(s_last + n - 1));
    cpu.a_ = rb((uint16_t)(e_last - n + 1));
    cpu.b = 0;
    cpu.c = swaps;
    cpu.d = cpu.d_;
    cpu.e = cpu.e_;
    cpu.h = cpu.h_;
    cpu.l = 0;
    cpu.b_ = (uint8_t)(bc >> 8); cpu.c_ = (uint8_t)bc;
    cpu.d_ = (uint8_t)(de >> 8); cpu.e_ = (uint8_t)de;
    cpu.h_ = (uint8_t)(hl >> 8); cpu.l_ = (uint8_t)hl;
}

static void w_2F57(void)
{
    uint16_t p = HL;
    uint8_t width = cpu.c, rows = cpu.b;
    spr_flip_graphics_h(p, width, rows);
    regs_flip(p, width, rows);
    z80_ret();
}

/* the two-part flips: the second LD HL / LD BC go to the bank the first call leaves active */
static void regs_flip2(uint16_t p1, uint8_t w1, uint8_t r1, uint16_t p2, uint8_t w2, uint8_t r2)
{
    regs_flip(p1, w1, r1);
    SET_HL(p2);
    cpu.b = r2;
    cpu.c = w2;
    regs_flip(p2, w2, r2);
}

static void w_2EE7(void)
{
    spr_flip_adso();
    regs_flip2(D64_SPR_ADSO_GFX_W5, 5, 0x5F, D64_SPR_ADSO_GFX_W4, 4, 0x5A);
    z80_ret();
}
static void w_2F40(void)
{
    spr_flip_guillermo();
    regs_flip2(D64_SPR_GUILLERMO_GFX_W5, 5, 0xAE, D64_SPR_GUILLERMO_GFX_W4, 4, 0x21);
    z80_ret();
}
static void w_2F00(void) { uint16_t p = rw(D64_SPR_MONK_FACES); spr_flip_malachi(); regs_flip(p, 5, 0x14); z80_ret(); }
static void w_2F10(void) { uint16_t p = rw(D64_SPR_MONK_FACES + 2); spr_flip_abbot(); regs_flip(p, 5, 0x14); z80_ret(); }
static void w_2F20(void) { uint16_t p = rw(D64_SPR_MONK_FACES + 4); spr_flip_berengar(); regs_flip(p, 5, 0x14); z80_ret(); }
static void w_2F30(void) { uint16_t p = rw(D64_SPR_MONK_FACES + 6); spr_flip_severin(); regs_flip(p, 5, 0x14); z80_ret(); }

static int r_flip(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = c8("A", cz->a, zz->a, msg, n);
    ok &= c8("A'", cz->a_, zz->a_, msg, n);
    ok &= c16("BC", R_BC(cz), R_BC(zz), msg, n);
    ok &= c16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= c16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= c16("BC'", (uint16_t)(cz->b_ << 8 | cz->c_), (uint16_t)(zz->b_ << 8 | zz->c_), msg, n);
    ok &= c16("DE'", (uint16_t)(cz->d_ << 8 | cz->e_), (uint16_t)(zz->d_ << 8 | zz->e_), msg, n);
    ok &= c16("HL'", (uint16_t)(cz->h_ << 8 | cz->l_), (uint16_t)(zz->h_ << 8 | zz->l_), msg, n);
    return ok;
}

const traducida_t traducidas_personajes[] = {
    { 0x2226, "game_run_npc_behaviours", w_2226, sin_resultados },
    { 0x2236, "spr_draw_or_darken", w_2236, sin_resultados },
    { 0x2265, "spr_place_light", w_2265, sin_resultados },
    { 0x22D4, "vid_clear_play_area", w_22D4, sin_resultados },
    { 0x22D8, "chr_step_table", w_22D8, r_hl_a },
    { 0x22E7, "util_add_bx_8al", w_22E7, r_hl_a },
    { 0x22F0, "chr_to_hbuf_coords", w_22F0, r_22F0 },
    { 0x2309, "chr_probe_ahead_flat", w_2309, r_probe },
    { 0x230D, "chr_probe_ahead", w_230D, r_probe },
    { 0x2320, "chr_probe_cells", w_2320, r_probe },
    { 0x23E2, "chr_guillermo_behaviour", w_23E2, sin_resultados },
    { 0x2444, "chr_mark_hbuf", w_2444, r_ix },
    { 0x2472, "chr_update", w_2472, r_ix_iy },
    { 0x249A, "chr_think_or_step", w_249A, sin_resultados },
    { 0x24A9, "chr_try_advance", w_24A9, sin_resultados },
    { 0x2503, "chr_orientation_parity", w_2503, r_a_zf },
    { 0x250C, "chr_try_advance_2x2", w_250C, sin_resultados },
    { 0x2539, "chr_apply_step", w_2539, r_hl_a },
    { 0x2549, "chr_step_level", w_2549, sin_resultados },
    { 0x2553, "chr_step_and_animate", w_2553, sin_resultados },
    { 0x2561, "chr_turn", w_2561, sin_resultados },
    { 0x257C, "chr_animate", w_257C, sin_resultados },
    { 0x25B6, "chr_select_frame", w_25B6, r_hl },
    { 0x2605, "spr_save_old_rect", w_2605, r_a },
    { 0x2623, "spr_mark_leaving", w_2623, r_a_zf },
    { 0x274B, "chr_load_params", w_274B, r_274B },
    { 0x2765, "chr_command_bit", w_2765, r_2765 },
    { 0x278F, "chr_ai_follow_commands", w_278F, sin_resultados },
    { 0x2855, "iso_select_room", w_2855, r_2855 },
    { 0x2873, "chr_fill_height_buffer", w_2873, sin_resultados },
    { 0x2899, "sys_tick", w_2899, r_todo },
    { 0x28AD, "chr_backup_args", w_28AD, r_hl_de_bc },
    { 0x2D50, "sys_read_keyboard", w_2D50, r_2D50 },
    { 0x2D99, "game_input_and_mirror", w_2D99, r_iff },
    { 0x2DFC, "game_check_qr_mirror", w_2DFC, r_2DFC },
    { 0x2E42, "sys_test_key", w_2E42, r_key },
    { 0x2E7D, "sys_key_pressed", w_2E7D, r_key },
    { 0x2E8D, "sys_key_down", w_2E8D, r_key },
    { 0x2E98, "sys_key_bit", w_2E98, r_key },
    { 0x2EBB, "obj_init_mirror", w_2EBB, r_mirror },
    { 0x2EC4, "obj_close_mirror", w_2EC4, r_mirror },
    { 0x2EE7, "spr_flip_adso", w_2EE7, r_flip },
    { 0x2F00, "spr_flip_malachi", w_2F00, r_flip },
    { 0x2F10, "spr_flip_abbot", w_2F10, r_flip },
    { 0x2F20, "spr_flip_berengar", w_2F20, r_flip },
    { 0x2F30, "spr_flip_severin", w_2F30, r_flip },
    { 0x2F40, "spr_flip_guillermo", w_2F40, r_flip },
    { 0x2F57, "spr_flip_graphics_h", w_2F57, r_flip },
    { 0, NULL, NULL, NULL }
};
#endif
