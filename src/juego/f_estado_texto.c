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

/* abadia64ks, group estado_texto: the CPC 64 KiB functions of 2FAD-3AAE translated to C (the doors of
 * the left wing, the pause, the game state blocks and a new game, the room height buffer, the start-up,
 * the text: characters, words, the phrase scroller, the script engine of RST 08h / RST 10h, the door
 * permissions, the hour update and the palettes), each with its wrapper and result check for the
 * hybrid host (hibrido.c) and the table traducidas_estado_texto.  The 64K code is the reference; the
 * PC rebuild (c/src) gives the names. */
#include <stdio.h>
#include <string.h>
#include "juego64.h"
#include "datos_estado_texto.h"

/* ---- small helpers ---- */

/* LDIR of n bytes (n = 0: 65536), outside the screen */
static void copia(uint16_t dst, uint16_t src, uint16_t n)
{
    do {
        wb(dst, rb(src));
        dst = (uint16_t)(dst + 1);
        src = (uint16_t)(src + 1);
    } while (--n);
}

/* LDIR of n bytes inside the screen */
static void copia_pantalla(uint16_t dst, uint16_t src, uint16_t n)
{
    do {
        wscr(dst, rscr(src));
        dst = (uint16_t)(dst + 1);
        src = (uint16_t)(src + 1);
    } while (--n);
}

/* the height step of the self-modified opcode at op: INC C, DEC C or NOP */
static uint8_t paso_altura(uint16_t op, uint8_t v)
{
    uint8_t o = rb(op);
    if (o == D64_OP_INC_C) return (uint8_t)(v + 1);
    if (o == D64_OP_DEC_C) return (uint8_t)(v - 1);
    return v;
}

/* =========================================================================================== */

/* 2FAD obj_open_left_wing_doors (PC 1000:30DB): bytes 0-1 of doors 5 and 6 of obj_doors = E002h and
 * C002h: the two doors that close the left wing open again.  Out: HL = C002h. */
void obj_open_left_wing_doors(void)
{
    ww(D64_OBJ_DOORS + 0x19, 0xE002);
    ww(D64_OBJ_DOORS + 0x1E, 0xC002);
}

/* 2FB9 sys_check_pause_save_load (PC 1000:311E): main-loop step: the key 4Fh (Del) pauses the game:
 * interrupts off, snd_channel_mask_copy = 3Fh, PSG register 7 (mixer) := 3Fh (every channel off), then
 * the keyboard is read (sys_read_keyboard) until 4Fh is pressed again; interrupts on.  (The save and
 * load of the 64K version are in 31DF.)  Out: A = the last sys_key_pressed (0, ZF = 1: no pause), C =
 * *code, the key code it tested last. */
uint8_t sys_check_pause_save_load(uint8_t *code)
{
    uint8_t a = sys_key_pressed(0x4F, code);
    if (!a) return a;
    plat_di();
    wb(D64_SND_CHANNEL_MASK_COPY, 0x3F);
    snd_psg_write(0x07, 0x3F);          /* 2FC9 CALL 0FBE: register A := C */
    do {
        sys_read_keyboard();            /* 2FCE CALL 2D50 */
        a = sys_key_pressed(0x4F, code);
    } while (!a);
    plat_ei();
    return a;
}

/* 304F spr_unflip_monk_faces (PC 1000:3283): for the four monks (records chr_malachi + 0Fh k): if +6
 * (graphics flipped) is set, clears it and flips back the face spr_monk_faces[k] (20 rows of 5 bytes,
 * spr_flip_graphics_h).  Out: HL = the end of spr_monk_faces, B = 0. */
void spr_unflip_monk_faces(void)
{
    uint16_t iy = D64_CHR_MALACHI, hl = D64_SPR_MONK_FACES, face;
    uint8_t k, v;
    for (k = 0; k < 4; ++k) {
        face = rw(hl);
        hl = (uint16_t)(hl + 2);
        v = rb((uint16_t)(iy + 6));
        if (v) {
            wb((uint16_t)(iy + 6), 0);
            spr_flip_graphics_h(face, 5, 0x14);   /* 306E CALL 2F57: HL graphics, B rows, C bytes */
        }
        iy = (uint16_t)(iy + 0x0F);
    }
}

/* 3087 obj_fix_owner_pointers (PC 1000:32DF): after a load, rebuilds the pointers saved with the game.
 * The lamp (obj_objects + 28h), when taken (bit 7), gets the holder game_adso_lamp; each of the 8 objects
 * of obj_objects that is taken gets (+2) the address of the obj_char_objects entry (7 bytes, +3 = the
 * objects mask) that holds its bit (80h for object 0 ... 01h for object 7; none: the 6th entry); then the six
 * position pointers chr_pos_ptrs go to +1/+2 of the entries of obj_door_permissions (3 bytes) and of
 * obj_char_objects (7 bytes).  Out: IX = obj_door_permissions + 18, IY = obj_char_objects + 42, HL =
 * chr_pos_ptrs + 12. */
void obj_fix_owner_pointers(void)
{
    uint16_t ix = D64_OBJ_OBJECTS, hl, p, dp, co;
    uint8_t mask = 0x80, k, n, lo, hi;
    if (rb(D64_OBJ_OBJECTS + 0x28) & 0x80) ww(D64_OBJ_OBJECTS + 0x2A, D64_GAME_ADSO_LAMP);
    for (k = 0; k < 8; ++k) {
        if (rb(ix) & 0x80) {
            hl = D64_OBJ_CHAR_OBJECTS + 3;
            n = 5;
            do {
                if (rb(hl) & mask) break;
                hl = (uint16_t)(hl + 7);
            } while (--n);
            ww((uint16_t)(ix + 2), (uint16_t)(hl - 3));
        }
        ix = (uint16_t)(ix + 5);
        mask >>= 1;
    }
    p = D64_CHR_POS_PTRS;
    dp = D64_OBJ_DOOR_PERMISSIONS;
    co = D64_OBJ_CHAR_OBJECTS;
    for (k = 0; k < 6; ++k) {
        lo = rb(p);
        wb((uint16_t)(dp + 1), lo);
        wb((uint16_t)(co + 1), lo);
        hi = rb((uint16_t)(p + 1));
        wb((uint16_t)(dp + 2), hi);
        wb((uint16_t)(co + 2), hi);
        p = (uint16_t)(p + 2);
        dp = (uint16_t)(dp + 3);
        co = (uint16_t)(co + 7);
    }
}

/* 30FD spr_tile_ptr_check (PC 1000:3351): true (CF = 0) when p lies inside the tile buffer
 * (8780h <= p < 8F00h).  In: IX = p.  Out: CF = outside; HL = p - 8780h (below) or p - 8F00h; DE =
 * 8780h or 780h. */
bool spr_tile_ptr_check(uint16_t p)
{
    if (p < D64_ISO_TILE_BUFFER) return false;
    return (uint16_t)(p - D64_ISO_TILE_BUFFER) < D64_ISO_TILE_BUFFER_SIZE;
}

/* 3166 game_state_block_save (PC 1000:338B): copies len bytes from block to cursor (LDIR); returns
 * cursor + len.  In: HL = cursor, DE = block, BC = len.  Out: HL = cursor + len, DE = block + len,
 * BC = 0. */
uint16_t game_state_block_save(uint16_t cursor, uint16_t block, uint16_t len)
{
    copia(cursor, block, len);
    return (uint16_t)(cursor + len);
}

/* 316B game_state_block_restore (PC 1000:339B): copies len bytes from cursor to block (LDIR); returns
 * cursor + len.  In: HL = cursor, DE = block, BC = len.  Out: HL = cursor + len, DE = block + len,
 * BC = 0. */
uint16_t game_state_block_restore(uint16_t cursor, uint16_t block, uint16_t len)
{
    copia(block, cursor, len);
    return (uint16_t)(cursor + len);
}

/* 3111 game_for_each_state_block (PC 1000:3367): stores fn (3166 save / 316B restore) in the operand of
 * its CALL at 3129 (game_state_block_fn) and calls it for each (address, length) entry of
 * game_state_blocks (a zero address ends) with a cursor into game_initial_state (0103h) that each call
 * advances.  In: HL = fn.  Out: the final cursor (HL); IX = the end of game_state_blocks, DE = 0,
 * BC = 0, A = 0, ZF = 1 (OR E). */
uint16_t game_for_each_state_block(uint16_t fn)
{
    uint16_t ix = D64_GAME_STATE_BLOCKS, cursor = D64_GAME_INITIAL_STATE, block, len, f;
    ww(D64_GAME_STATE_BLOCK_FN, fn);
    for (;;) {
        block = rw(ix);
        if (!block) return cursor;
        len = rb((uint16_t)(ix + 2));
        f = rw(D64_GAME_STATE_BLOCK_FN);                       /* CALL [312A] */
        if (f == 0x3166) cursor = game_state_block_save(cursor, block, len);
        else if (f == 0x316B) cursor = game_state_block_restore(cursor, block, len);
        /* never another one: only 3166/316B are stored */
        ix = (uint16_t)(ix + 3);
    }
}

/* 310E game_snapshot_initial_state (PC 1000:3364): start-up: copies the state blocks into
 * game_initial_state (game_for_each_state_block with 3166 save).  Out: as game_for_each_state_block. */
uint16_t game_snapshot_initial_state(void)
{
    return game_for_each_state_block(0x3166);
}

/* 316E util_clear_bytes (PC 1000:33A7): zeroes the n+1 bytes p..p+n: [p] = 0, then an overlapping
 * LDIR from p to p+1 of n bytes.  In: HL = p, BC = n.  Out: HL = p + n, DE = p + n + 1, BC = 0. */
void util_clear_bytes(uint16_t p, uint16_t n)
{
    wb(p, 0);
    copia((uint16_t)(p + 1), p, n);
}

/* 3176 game_init_new_game (PC 1000:33BB): a game starts: clears 37D2-37F2 (game_book_poison_count..)
 * and 28DE-2929, restores the state blocks from game_initial_state (316B), hides every sprite of
 * spr_table (byte 0 = FEh up to the FFh end, 20-byte records) and resets the six character records:
 * +0, +5, +9, +0Bh = 0, +1 (orientation) = 1, +0Ah = FDh (the PC version sets +1 = 0).  Out: A = 0,
 * BC = 0, DE = 0Fh, HL = the FFh end of spr_table, IX = the end of the six records. */
void game_init_new_game(void)
{
    uint16_t hl, ix;
    uint8_t k;
    util_clear_bytes(D64_GAME_BOOK_POISON_COUNT, 0x20);
    util_clear_bytes(D64_ISO_MIRROR_STATE_GUILLERMO, 0x4B);
    game_for_each_state_block(0x316B);
    for (hl = D64_SPR_TABLE; rb(hl) != 0xFF; hl = (uint16_t)(hl + 0x14)) wb(hl, 0xFE);
    ix = D64_CHR_GUILLERMO;
    for (k = 0; k < 6; ++k) {
        wb(ix, 0);
        wb((uint16_t)(ix + 1), 1);
        wb((uint16_t)(ix + 5), 0);
        wb((uint16_t)(ix + 9), 0);
        wb((uint16_t)(ix + 0x0A), 0xFD);
        wb((uint16_t)(ix + 0x0B), 0);
        ix = (uint16_t)(ix + 0x0F);
    }
}

/* ---- the room height buffer ---- */

/* 3786 util_clip_span: clips the span [pos, pos+len) to the window [win, win+win_len) (8-bit
 * coordinates).  Returns true (CF) when part of it is visible: *count = its visible length (A), *skip =
 * the offset of the visible part inside the span (H), *start = its position inside the window (L).
 * Hidden: *count = the distance (A), and *skip, *start = 0, distance (span after the window) or
 * pos, win (span before it: H and L unchanged).  In: L = win, H = pos, D = len, E = win_len. */
bool util_clip_span(uint8_t win, uint8_t pos, uint8_t len, uint8_t win_len, uint8_t *count,
                    uint8_t *skip, uint8_t *start)
{
    uint8_t a = (uint8_t)(win - pos);
    if (a == 0) {                                              /* 379B: aligned */
        *skip = 0;
        *start = 0;
        *count = win_len < len ? win_len : len;
        return true;
    }
    if (win < pos) {                                           /* 37A4: starts inside the window or after it */
        a = (uint8_t)(pos - win);
        *skip = 0;
        *start = a;
        if (a >= win_len) {
            *count = a;
            return false;
        }
        a = (uint8_t)(win_len - a);
        *count = a < len ? a : len;
        return true;
    }
    *skip = pos;                                               /* 378C: starts before the window */
    *start = win;
    if (a >= len) {
        *count = a;
        return false;
    }
    *skip = a;
    *start = 0;
    *count = (uint8_t)(a + win_len) >= len ? (uint8_t)(len - a) : win_len;
    return true;
}

/* 3549 chr_hbuf_clip_x: the columns of a height block in the 24-column window whose world x is the
 * operand at 354A (chr_hbuf_fill_room).  In: H = x, D = columns - 1.  Out: CF = visible, A = E = the
 * visible columns, H = the first visible column of the block, L = its column in the buffer, D =
 * columns (util_clip_span). */
bool chr_hbuf_clip_x(uint8_t x, uint8_t n1, uint8_t *count, uint8_t *skip, uint8_t *start)
{
    return util_clip_span(rb(D64_CHR_HBUF_WIN_X_OP), x, (uint8_t)(n1 + 1), D64_CHR_HBUF_SIZE, count, skip, start);
}

/* 354D chr_hbuf_clip_y: the same for the rows, window y = the operand at 354E.  In: H = y, D = rows - 1.
 * Out: CF, A = E = the visible rows, H = the first visible row, L = its row in the buffer, D = rows. */
bool chr_hbuf_clip_y(uint8_t y, uint8_t n1, uint8_t *count, uint8_t *skip, uint8_t *start)
{
    return util_clip_span(rb(D64_CHR_HBUF_WIN_Y_OP), y, (uint8_t)(n1 + 1), D64_CHR_HBUF_SIZE, count, skip, start);
}

/* 3521 chr_hbuf_slope_x_inc: slope kind 1, the height grows by 1 per column: the column step opcode
 * (3515) = INC C; returns the height of the first visible cell, h + skip_x.  In: A = h, H' = skip_x.
 * Out: A (ADD flags), A' = 0Ch (the EX AF,AF' scratch). */
uint8_t chr_hbuf_slope_x_inc(uint8_t h, uint8_t skip_x)
{
    wb(D64_CHR_HBUF_COL_STEP_OP, D64_OP_INC_C);
    return (uint8_t)(h + skip_x);
}

/* 352C chr_hbuf_slope_y_dec: slope kind 2, the height falls by 1 per row: the row step opcode (351C) =
 * DEC C; returns h - skip_y.  In: A = h, H = skip_y.  Out: A (SUB flags), A' = 0Dh. */
uint8_t chr_hbuf_slope_y_dec(uint8_t h, uint8_t skip_y)
{
    wb(D64_CHR_HBUF_ROW_STEP_OP, D64_OP_DEC_C);
    return (uint8_t)(h - skip_y);
}

/* 3535 chr_hbuf_slope_x_dec: slope kind 3, the height falls by 1 per column: column step = DEC C;
 * returns h - skip_x.  In: A = h, H' = skip_x.  Out: A (SUB flags), A' = 0Dh. */
uint8_t chr_hbuf_slope_x_dec(uint8_t h, uint8_t skip_x)
{
    wb(D64_CHR_HBUF_COL_STEP_OP, D64_OP_DEC_C);
    return (uint8_t)(h - skip_x);
}

/* 3540 chr_hbuf_slope_y_inc: slope kind 4, the height grows by 1 per row: row step = INC C; returns
 * h + skip_y.  In: A = h, H = skip_y.  Out: A (ADD flags), A' = 0Ch. */
uint8_t chr_hbuf_slope_y_inc(uint8_t h, uint8_t skip_y)
{
    wb(D64_CHR_HBUF_ROW_STEP_OP, D64_OP_INC_C);
    return (uint8_t)(h + skip_y);
}

/* 346E chr_hbuf_fill_list (PC 1000:34E5, a different algorithm): fills the 24x24 height buffer
 * (chr_hbuf_ptr) from the height list at `list`.  Record: byte 0 = h<<4 | big<<3 | kind, x, y, then
 * (nx-1)<<4 | (ny-1) (4 bytes) or nx-1, ny-1 (5 bytes, big = 1); FFh ends.  Each record is clipped to
 * the window (chr_hbuf_clip_x/_y); kind 5 is a flat block of height h; any other kind fills through the
 * slope loop (350A) whose per-column and per-row steps are the opcodes at 3515/351C (kinds 1-4 set one
 * of them and the height of the first visible cell; kinds 0, 6, 7 keep both NOPs: a flat fill).  The
 * visible width is kept in the operands at 34EA and 3510.  Returns the address of the FFh (IX; C = 0,
 * ZF = 1). */
uint16_t chr_hbuf_fill_list(uint16_t list)
{
    uint16_t ix = list, p, q;
    uint8_t c, d, kind, h, nx, ny, skip_x, skip_y, start_x, start_y, rows, n, v, rv;
    for (;;) {
        c = rb(ix);
        if (c == 0xFF) return ix;
        d = rb((uint16_t)(ix + 3));
        if (!(c & 0x08)) d = (uint8_t)((d >> 4) & 0x0F);
        if (chr_hbuf_clip_x(rb((uint16_t)(ix + 1)), d, &nx, &skip_x, &start_x)) {
            d = (c & 0x08) ? rb((uint16_t)(ix + 4)) : (uint8_t)(rb((uint16_t)(ix + 3)) & 0x0F);
            if (chr_hbuf_clip_y(rb((uint16_t)(ix + 2)), d, &ny, &skip_y, &start_y)) {
                wb(D64_CHR_HBUF_ROW_STEP_OP, D64_OP_NOP);
                wb(D64_CHR_HBUF_COL_STEP_OP, D64_OP_NOP);
                c = rb(ix);
                kind = c & 0x07;
                h = (uint8_t)((c >> 4) & 0x0F);
                if (kind == 1) h = chr_hbuf_slope_x_inc(h, skip_x);
                else if (kind == 2) h = chr_hbuf_slope_y_dec(h, skip_y);
                else if (kind == 3) h = chr_hbuf_slope_x_dec(h, skip_x);
                else if (kind == 4) h = chr_hbuf_slope_y_inc(h, skip_y);
                p = (uint16_t)(rw(D64_CHR_HBUF_PTR) + (uint16_t)(start_y * 24u));
                wb(D64_CHR_HBUF_FLAT_WIDTH_OP, nx);
                wb(D64_CHR_HBUF_SLOPE_WIDTH_OP, nx);
                p = util_add_bx_al(p, start_x);
                rows = ny;
                if (kind == 5) {                               /* 34E9: flat block */
                    do {
                        n = rb(D64_CHR_HBUF_FLAT_WIDTH_OP);
                        q = p;
                        do {
                            wb(q, h);
                            q = (uint16_t)(q + 1);
                        } while (--n);
                        p = (uint16_t)(p + D64_CHR_HBUF_SIZE);
                    } while (--rows);
                } else {                                       /* 350A: slope */
                    rv = h;
                    do {
                        n = rb(D64_CHR_HBUF_SLOPE_WIDTH_OP);
                        q = p;
                        v = rv;
                        do {
                            wb(q, v);
                            q = (uint16_t)(q + 1);
                            v = paso_altura(D64_CHR_HBUF_COL_STEP_OP, v);
                        } while (--n);
                        p = (uint16_t)(p + D64_CHR_HBUF_SIZE);
                        rv = paso_altura(D64_CHR_HBUF_ROW_STEP_OP, rv);
                    } while (--rows);
                }
            }
        }
        ix = (uint16_t)(ix + ((rb(ix) & 0x08) ? 5 : 4));
    }
}

/* 3456 chr_hbuf_fill_room (PC 1000:34C3): the window origin chr_hbuf_origin_x / _y into the operands
 * at 354A / 354E, then fills the buffer from the current floor's height list (chr_floor_heights_ptr).
 * Reached by JP from the end of chr_fill_height_buffer (2896).  IX is kept. */
void chr_hbuf_fill_room(void)
{
    wb(D64_CHR_HBUF_WIN_X_OP, rb(D64_CHR_HBUF_ORIGIN_X));
    wb(D64_CHR_HBUF_WIN_Y_OP, rb(D64_CHR_HBUF_ORIGIN_Y));
    chr_hbuf_fill_list(rw(D64_CHR_FLOOR_HEIGHTS_PTR));
}

/* 35F8 chr_hbuf_skip_list (PC 1000:379D): advances p over the 4/5-byte records of a height list to its
 * FFh end.  In: HL = p.  Out: HL, A = FFh, ZF = 1. */
uint16_t chr_hbuf_skip_list(uint16_t p)
{
    while (rb(p) != 0xFF) p = (uint16_t)(p + ((rb(p) & 0x08) ? 5 : 4));
    return p;
}

/* ---- the screen ---- */

/* 3558 vid_next_line (PC 1000:3718 for the CGA): the screen address of the next pixel line: H + 8; on
 * a carry (the 8th line of a character row) L + 40h and H = (H + that carry) OR C0h.  In: HL.  Out: HL,
 * A = H, CF = 0. */
uint16_t vid_next_line(uint16_t p)
{
    uint8_t h = (uint8_t)((p >> 8) + 8), l = (uint8_t)p;
    if (h >= 8) return (uint16_t)(h << 8 | l);
    l = (uint8_t)(l + 0x40);
    if (l < 0x40) h = (uint8_t)(h + 1);
    return (uint16_t)((h | 0xC0) << 8 | l);
}

/* 3778 vid_xy_to_offset (PC 1000:3960 for the CGA): the screen address of byte column x (L, below 40h)
 * on pixel line y (H): C000h + (y AND 7) * 800h + (y >> 3) * 40h + x (H = y rotated left 3 OR C0h, L =
 * (that AND C0h) OR x).  Out: HL, A = L (OR flags). */
uint16_t vid_xy_to_offset(uint16_t xy)
{
    uint8_t y = (uint8_t)(xy >> 8), r = (uint8_t)(y << 3 | y >> 5);
    return (uint16_t)((uint8_t)(r | 0xC0) << 8 | (uint8_t)((r & 0xC0) | (uint8_t)xy));
}

/* 35B0 vid_copy_lines_to_row: copies 8 consecutive lines of 64 bytes from src into the 8 pixel lines
 * of the screen character row that starts at row.  In: HL = row, DE = src.  Out: HL = the next
 * character row (returned), DE = src + 200h, A = H, B = 0. */
uint16_t vid_copy_lines_to_row(uint16_t row, uint16_t src)
{
    uint8_t k;
    for (k = 0; k < 8; ++k) {
        copia_pantalla(row, src, 0x40);
        src = (uint16_t)(src + 0x40);
        row = vid_next_line(row);
    }
    return row;
}

/* 3598 hud_rows_from_hidden: builds the character rows 20-23 of the screen (the top of the score bar)
 * from the hidden rows 24-31 (CRTC R6 = 24): row 20 from pixel line 0 of rows 24-31 (C600-C7FF), row 21
 * from line 2 (D600), row 22 from line 4 (E600), row 23 from line 6 (F600).  Out: HL = C600h (the
 * row after 23), DE = F800h, A = C6h, B = 0. */
uint16_t hud_rows_from_hidden(void)
{
    uint16_t row = D64_SCR_ROW20;
    row = vid_copy_lines_to_row(row, 0xC600);
    row = vid_copy_lines_to_row(row, 0xD600);
    row = vid_copy_lines_to_row(row, 0xE600);
    return vid_copy_lines_to_row(row, 0xF600);
}

/* 3607 vid_init_stub (PC 1000:37AF, a RET on the PC): builds the four pixel tables of 256 bytes at
 * 8F00h, 9000h, 9100h, 9200h (mode 1 bytes, c = 4 pixels with bit 0 in the high nibble):
 * t0 = (c AND F0h) OR (c AND c>>4 AND 0Fh), t1 = 11h * (c AND NOT c>>4 AND 0Fh),
 * t2 = (c AND 0Fh) OR (c AND c<<4 AND F0h), t3 = u OR u>>4 with u = c AND NOT c<<4 AND F0h.
 * Out (constant): A = 0, BC = 8F00h, DE = 00FFh, flags of INC C (ZF = HF = 1). */
void vid_init_stub(void)
{
    uint8_t c = 0, e, a;
    do {
        e = (uint8_t)(c >> 4 | c << 4);
        wb((uint16_t)(D64_VID_COLOUR_TABLES + c), (uint8_t)((e & c & 0x0F) | (c & 0xF0)));
        a = (uint8_t)((e ^ c) & c & 0x0F);
        wb((uint16_t)(D64_VID_COLOUR_TABLES + 0x100 + c), (uint8_t)(a << 4 | a));
        wb((uint16_t)(D64_VID_COLOUR_TABLES + 0x200 + c), (uint8_t)((c & 0x0F) | (e & c & 0xF0)));
        a = (uint8_t)((e ^ c) & c & 0xF0);
        wb((uint16_t)(D64_VID_COLOUR_TABLES + 0x300 + c), (uint8_t)(a | a >> 4));
    } while (++c);
}

/* 3A90 (common body of 3A83 / 3A88 / 3A8D) vid_set_palette: pens 3, 2, 1, 0 and the border := the 5
 * hardware colours at table.  Out: HL = table + 4, A = 0, B = 7Fh, C = 40h OR the border colour. */
static void vid_set_palette(uint16_t table)
{
    uint8_t pen;
    for (pen = 4; pen; --pen) {
        plat_tinta((uint8_t)(pen - 1), rb(table));
        table = (uint16_t)(table + 1);
    }
    plat_tinta(0x10, rb(table));
}

/* 3A83 vid_palette_black: every pen and the border black (start-up). */
void vid_palette_black(void)
{
    vid_set_palette(D64_VID_PALETTE_BLACK);
}

/* 3A88 vid_palette_day (PC 1000:5DBD): the day palette. */
void vid_palette_day(void)
{
    vid_set_palette(D64_VID_PALETTE_DAY);
}

/* 3A8D vid_palette_night (PC 1000:5DC0): the night palette. */
void vid_palette_night(void)
{
    vid_set_palette(D64_VID_PALETTE_NIGHT);
}

/* 35C3 game_init_mirror (PC 1000:3724, its second half): obj_mirror_height_ptr = the end of the
 * second-floor height list (chr_hbuf_skip_list); in room 72h of iso_room_table (rooms skipped by their
 * length byte) finds the block 1F AA 51 (256 bytes at most), changes 51h into 11h (mirror closed) and
 * stores its address in obj_mirror_entry_ptr.  Returns that address (HL). */
uint16_t game_init_mirror(void)
{
    uint16_t hl;
    uint8_t b;
    ww(D64_OBJ_MIRROR_HEIGHT_PTR, chr_hbuf_skip_list(D64_CHR_FLOOR2_HEIGHTS));
    hl = D64_ISO_ROOM_TABLE;
    for (b = 0x72; b; --b) hl = (uint16_t)(hl + rb(hl));
    b = 0;
    do {
        uint8_t a = rb(hl);
        hl = (uint16_t)(hl + 1);
        if (a == 0x1F && rb(hl) == 0xAA && rb((uint16_t)(hl + 1)) == 0x51) {
            hl = (uint16_t)(hl + 1);
            wb(hl, 0x11);
            ww(D64_OBJ_MIRROR_ENTRY_PTR, hl);
            return hl;
        }
    } while (--b);
    return hl;
}

/* 3568 sys_startup_init: the start-up of the 64K game, run once (sys_startup_done = 0Dh): every pen
 * black, mode 1 (the ROMs off), the score bar rows 20-23 from the hidden rows, the 1000h bytes at 8300h
 * into the hidden rows 24-31 (200h bytes per pixel line), the snapshot of the initial state, the mirror,
 * and (JP) the pixel tables of vid_init_stub, over the end of the 8300h data.  Its code is then free:
 * the command buffers live there.  Out: those of vid_init_stub, HL = obj_mirror_entry_ptr, IX = the
 * end of game_state_blocks. */
uint16_t sys_startup_init(void)
{
    uint16_t src = D64_HUD_HIDDEN_ROWS_SRC, dst = D64_SCR_ROW24, hl;
    uint8_t k;
    wb(D64_SYS_STARTUP_DONE, 0x0D);
    vid_palette_black();
    plat_modo(1);                                              /* OUT (7Fxx),8Dh */
    hud_rows_from_hidden();
    for (k = 0; k < 8; ++k) {
        uint16_t i;
        for (i = 0; i < 0x200; ++i) wscr((uint16_t)(dst + i), rb((uint16_t)(src + i)));
        src = (uint16_t)(src + 0x200);
        dst = (uint16_t)(dst + 0x800);
    }
    game_snapshot_initial_state();
    hl = game_init_mirror();
    vid_init_stub();
    return hl;
}

/* ---- the text ---- */

/* 364F (common body of txt_draw_char / txt_draw_char_inverted): draws code c at txt_cursor (x in bytes
 * low, y line high).  c AND 7Fh: 20h uses the blank glyph; below 2Dh draws nothing (false) and leaves
 * the cursor; else glyph txt_font + (c-2Dh)*8.  Each of the 8 glyph rows becomes two mode 1 bytes: its
 * high nibble, and its low nibble shifted up, each XOR mask (0Fh: ink 3 on 2; FFh: inverted); lines
 * advanced with vid_next_line; then the cursor x += 2. */
bool txt_draw_char_masked(uint8_t c, uint8_t mask)
{
    uint16_t glyph, cursor, p;
    uint8_t k, g;
    c &= 0x7F;
    if (c == 0x20) glyph = D64_TXT_GLYPH_BLANK;
    else {
        if (c < 0x2D) return false;
        glyph = (uint16_t)(D64_TXT_FONT + (uint16_t)(c - 0x2D) * 8u);
    }
    cursor = rw(D64_TXT_CURSOR);
    p = vid_xy_to_offset(cursor);
    for (k = 0; k < 8; ++k) {
        g = rb(glyph);
        wscr(p, (uint8_t)((g & 0xF0) ^ mask));
        wscr((uint16_t)(p + 1), (uint8_t)((uint8_t)(g << 4) ^ mask));
        p = vid_next_line(p);
        glyph = (uint16_t)(glyph + 1);
    }
    ww(D64_TXT_CURSOR, (uint16_t)((cursor & 0xFF00) | (uint8_t)(cursor + 2)));
    return true;
}

/* 364D txt_draw_char (PC 1000:37B0): draw code c at txt_cursor (mask 0Fh).  In: A = c.  Out: C = mask;
 * drawn: HL = txt_cursor, DE = glyph + 8, B = 0, A = the H of the line below; not drawn (c < 2Dh): CF,
 * A = c - 2Dh, DE = txt_glyph_blank. */
bool txt_draw_char(uint8_t c)
{
    return txt_draw_char_masked(c, 0x0F);
}

/* 3649 txt_draw_char_inverted (PC 1000:37B4): the same with mask FFh. */
bool txt_draw_char_inverted(uint8_t c)
{
    return txt_draw_char_masked(c, 0xFF);
}

/* 3770 txt_skip_words (PC 1000:3953): advances p past n words of the dictionary (each word ends with a
 * byte that has bit 7 set); n = 0 means 256.  In: HL = p, B = n.  Out: HL, B = 0. */
uint16_t txt_skip_words(uint16_t p, uint8_t n)
{
    uint8_t b;
    do {
        do {
            b = rb(p);
            p = (uint16_t)(p + 1);
        } while (!(b & 0x80));
    } while (--n);
    return p;
}

/* 368A txt_phrase_tick (PC 1000:3820): phrase scroller, run by the 300 Hz interrupt (2899): acts on
 * every 2Dh-th call (txt_scroll_timer) while a phrase is active (txt_phrase_active).  Then a beep
 * (snd_play_beep, which ends with EI) and the next character: the next letter of the current word
 * (txt_word_ptr; bit 7 = last letter -> txt_word_done = 1; the letter's low 3 bits go to the voice
 * tone bytes, their negation to snd_voice_tone_neg), or at a word end a trailing blank while
 * txt_trailing_blanks counts down (at 0 the phrase ends), or the next phrase byte (txt_phrase_ptr): FFh
 * = end (11h: 16 blanks), FA-FE punctuation from txt_punctuation, F9 nn word nn with no blank, else word
 * n (a blank is printed first).  Printing scrolls the strip E510-E52F (8 lines, 30 bytes) two bytes to
 * the left, sets snd_voice_level = 6 (0 for a blank) and draws the character inverted at the strip's
 * right end (txt_cursor = A42Eh); txt_cursor is restored.  Every register but AF is kept. */
void txt_phrase_tick(void)
{
    uint16_t saved, p, q;
    uint8_t ch, b, k;
    plat_di();
    b = (uint8_t)(rb(D64_TXT_SCROLL_TIMER) + 1);
    wb(D64_TXT_SCROLL_TIMER, b);
    if (b != 0x2D) return;
    wb(D64_TXT_SCROLL_TIMER, 0);
    if (!rb(D64_TXT_PHRASE_ACTIVE)) return;
    saved = rw(D64_TXT_CURSOR);
    snd_play_beep();                                           /* 36A9 CALL 0C90 */
    for (;;) {
        if (rb(D64_TXT_WORD_DONE) != 1) {                      /* 36B2: the next letter of the word */
            p = rw(D64_TXT_WORD_PTR);
            if (rb(p) & 0x80) wb(D64_TXT_WORD_DONE, 1);
            k = rb(p) & 0x07;
            wb(D64_SND_VOICE_TONE_A, k);
            wb(D64_SND_VOICE_TONE_B, k);
            wb(D64_SND_VOICE_TONE_NEG, (uint8_t)-k);
            ch = rb(p) & 0x7F;
            ww(D64_TXT_WORD_PTR, (uint16_t)(p + 1));
            break;
        }
        b = rb(D64_TXT_TRAILING_BLANKS);                       /* 370D: the word is finished */
        if (b) {
            --b;
            wb(D64_TXT_TRAILING_BLANKS, b);
            if (b) {
                ch = 0x20;
                break;
            }
            wb(D64_TXT_PHRASE_ACTIVE, 0);
            ww(D64_TXT_CURSOR, saved);
            return;
        }
        wb(D64_TXT_WORD_DONE, 0);                              /* 3722: the next byte of the phrase */
        p = rw(D64_TXT_PHRASE_PTR);
        b = rb(p);
        if (b == 0xFF) {                                       /* the end: 16 blanks */
            wb(D64_TXT_TRAILING_BLANKS, 0x11);
            wb(D64_TXT_WORD_DONE, 1);
            continue;
        }
        if (b >= 0xFA) {                                       /* 375E: punctuation */
            ww(D64_TXT_PHRASE_PTR, (uint16_t)(p + 1));
            ww(D64_TXT_WORD_PTR, util_add_bx_al(D64_TXT_PUNCTUATION, (uint8_t)(b - 0xFA)));
            continue;
        }
        p = (uint16_t)(p + 1);
        ch = 0x20;
        if (b >= 0xF9) {                                       /* F9 nn: word nn, no blank */
            ch = 0;
            b = rb(p);
            p = (uint16_t)(p + 1);
        }
        ww(D64_TXT_PHRASE_PTR, p);
        q = D64_TXT_WORDS;
        if (b) q = txt_skip_words(q, b);
        ww(D64_TXT_WORD_PTR, q);
        if (ch) break;
    }
    p = D64_TXT_STRIP;                                         /* 36D3: print ch */
    for (k = 0; k < 8; ++k) {
        copia_pantalla((uint16_t)(p - 2), p, 0x1E);
        p = vid_next_line(p);
    }
    ww(D64_TXT_CURSOR, D64_TXT_STRIP_CURSOR);
    wb(D64_SND_VOICE_LEVEL, ch == 0x20 ? 0 : 6);
    txt_draw_char_inverted(ch);
    ww(D64_TXT_CURSOR, saved);
}

/* ---- the script engine (RST 08h, RST 10h) ---- */

/* 3910 ai_script_var_ptr (PC 1000:5BED): the address of script variable op: the word at ai_script_vars
 * + (2*op mod 256).  In: A = op.  Out: HL; DE = the table entry + 1, A = the high byte of the entry. */
uint16_t ai_script_var_ptr(uint8_t op)
{
    return rw((uint16_t)(D64_AI_SCRIPT_VARS + (uint8_t)(op + op)));
}

/* 3994 ai_script_operand (PC 1000:5C9A): reads one operand at *p (40h nn: literal nn; a byte below
 * 80h: literal; else the value of that script variable), advances *p and returns the value.  In: HL =
 * p.  Out: C = the value, HL = p; A = 40h, the literal, or as ai_script_var_ptr. */
uint8_t ai_script_operand(uint16_t *p)
{
    uint8_t a = rb(*p);
    *p = (uint16_t)(*p + 1);
    if (a == 0x40) {
        a = rb(*p);
        *p = (uint16_t)(*p + 1);
        return a;
    }
    if (a < 0x80) return a;
    return rb(ai_script_var_ptr(a));
}

/* the bytes that end an expression: the opcode of the next instruction (JR NZ, RST 10h, JP NZ, CALL,
 * RST 08h, RET, JP, JR) */
static bool fin_expresion(uint8_t b)
{
    return b == 0x20 || b == 0xD7 || b == 0xC2 || b == 0xCD || b == 0xCF || b == 0xC9 || b == 0xC3 || b == 0x18;
}

/* 3926 ai_script_eval (PC 1000:5C0E): evaluates the postfix expression at *p; returns its value and
 * *p = the address of its terminator.  The top of the stack is C, the deeper values are on the CPU
 * stack (here an array); an operator pops the second value E: '=' 00 if equal else FFh, '>' 00 if
 * E >= C, '<' 00 if E < C, '*' AND, '&' OR, '+' sum, '-' E - C; any other byte pushes C and reads an
 * operand.  (The original pops its own return address at the first non-terminator byte and pushes it
 * back for an operand: an operator with an empty stack would take that word; no expression does it.)
 * In: HL.  Out: C = the value, HL = the terminator, A = its byte, flags of CP equal. */
uint8_t ai_script_eval(uint16_t *p)
{
    uint8_t pila[32], n = 0, c, a, e;
    c = ai_script_operand(p);
    for (;;) {
        a = rb(*p);
        if (fin_expresion(a)) return c;
        *p = (uint16_t)(*p + 1);
        if (a == 0x3D || a == 0x3E || a == 0x3C || a == 0x2A || a == 0x26 || a == 0x2B || a == 0x2D)
            e = n ? pila[--n] : 0;
        else
            e = 0;
        if (a == 0x3D) c = c == e ? 0x00 : 0xFF;               /* 398B '=' */
        else if (a == 0x3E) c = e >= c ? 0x00 : 0xFF;         /* 3979 '>' */
        else if (a == 0x3C) c = e < c ? 0x00 : 0xFF;          /* 3982 '<' */
        else if (a == 0x2A) c = (uint8_t)(c & e);             /* 3975 '*' */
        else if (a == 0x26) c = (uint8_t)(c | e);             /* 3971 '&' */
        else if (a == 0x2B) c = (uint8_t)(c + e);             /* 396D '+' */
        else if (a == 0x2D) c = (uint8_t)(e - c);             /* 3968 '-' */
        else {                                                 /* 3960: push C, read an operand */
            if (n < sizeof pila) pila[n++] = c;
            *p = (uint16_t)(*p - 1);
            c = ai_script_operand(p);
        }
    }
}

/* 391E ai_script_test (PC 1000:5C04), the RST 08h helper: `RST 08h <expr>`: the value of the expression
 * after the RST (ZF = value == 0 = 'true'); returns past it.  In: *p = the return address (the
 * expression).  Out: A = C = the value (AND A flags), HL = *p = the terminator, where it returns. */
uint8_t ai_script_test(uint16_t *p)
{
    return ai_script_eval(p);
}

/* 38FC ai_script_assign (PC 1000:5BD0), the RST 10h helper: `RST 10h <var> <expr>`: ai_script_dest_ptr
 * (the operand of its LD (nn),A at 390C) := the address of variable var, then [that address] := the
 * value of the expression; returns past it.  In: *p = the return address.  Out: A = C = the value, HL
 * = *p = the terminator, where it returns; flags of CP equal. */
uint8_t ai_script_assign(uint16_t *p)
{
    uint8_t op = rb(*p), v;
    *p = (uint16_t)(*p + 1);
    ww(D64_AI_SCRIPT_DEST_PTR, ai_script_var_ptr(op));
    v = ai_script_eval(p);
    wb(rw(D64_AI_SCRIPT_DEST_PTR), v);
    return v;
}

/* 39A8 ai_stay (PC 1000:5CB6): ai_no_route := 1 (the character does not plan a route this frame); the
 * scripts reach it by JP.  Out: A = 1. */
void ai_stay(void)
{
    wb(D64_AI_NO_ROUTE, 0x01);
}

/* 39AE ai_guillermo_is_close (PC 1000:5CBC): true (ZF = 1) when Guillermo is on the floor of the
 * character chr (iso_floor_base of both heights) and inside the box in front of it: ai_close_box_table,
 * 4 bytes per orientation of chr (x offset, x size, y offset, y size), tests (gx + off - x) < size
 * unsigned.  In: IY = chr.  Out: ZF. */
bool ai_guillermo_is_close(uint16_t chr)
{
    uint8_t g = iso_floor_base(rb(D64_CHR_GUILLERMO + 4)), a;
    uint16_t bx;
    if (iso_floor_base(rb((uint16_t)(chr + 4))) != g) return false;
    bx = util_add_bx_al(D64_AI_CLOSE_BOX_TABLE, (uint8_t)(rb((uint16_t)(chr + 1)) * 4));
    a = (uint8_t)(rb(D64_CHR_GUILLERMO + 2) + rb(bx) - rb((uint16_t)(chr + 2)));
    if (a >= rb((uint16_t)(bx + 1))) return false;
    a = (uint8_t)(rb(D64_CHR_GUILLERMO + 3) + rb((uint16_t)(bx + 2)) - rb((uint16_t)(chr + 3)));
    if (a >= rb((uint16_t)(bx + 3))) return false;
    return true;
}

/* 39E5 ai_next_state_on_arrival (PC 1000:5CFF): when the destination [places-1] equals the place
 * reached [places-3], the state [places-2] += 1 and true.  In: IX = places.  Out: ZF = arrived; A = 0
 * (arrived) or [places-1]. */
bool ai_next_state_on_arrival(uint16_t places)
{
    if (rb((uint16_t)(places - 1)) != rb((uint16_t)(places - 3))) return false;
    wb((uint16_t)(places - 2), (uint8_t)(rb((uint16_t)(places - 2)) + 1));
    return true;
}

/* 3A30 util_bits_set_or_clear (PC 1000:5D54): clear (CF = 1) -> val AND NOT bits, else val OR bits.
 * In: A = bits, E = val, CF.  Out: A. */
uint8_t util_bits_set_or_clear(uint8_t bits, uint8_t val, bool clear)
{
    if (clear) return (uint8_t)(~bits & val);
    return (uint8_t)(bits | val);
}

/* 39F1 obj_set_door_permissions (PC 1000:5D0E): doors = the doors the character may open (C), ANDed with
 * obj_door_check_mask; also ai_random := chr_command_buffers[0].  For each of the 6 doors of
 * obj_door_link_table (pairs index into chr_room_links, bits; FFh ends a door) the bits are cleared
 * (door allowed) or set (forbidden) by util_bits_set_or_clear.  Self-modifying code: before each door
 * the opcode at 3A24 := CCF when its bit is set, else NOP; it gives the CF of the call.  IX is kept.
 * Out: A = FFh, B = 0, HL = chr_room_links. */
void obj_set_door_permissions(uint8_t doors)
{
    uint16_t ix = D64_OBJ_DOOR_LINK_TABLE, hl;
    uint8_t c, b, idx, bits;
    wb(D64_AI_RANDOM, rb(D64_CHR_COMMAND_BUFFERS));
    c = (uint8_t)(rb(D64_OBJ_DOOR_CHECK_MASK) & doors);
    for (b = 6; b; --b) {
        wb(D64_OBJ_DOOR_ALLOW_OP, (c & 0x01) ? D64_OP_CCF : D64_OP_NOP);
        c >>= 1;
        for (;;) {
            idx = rb(ix);
            ix = (uint16_t)(ix + 1);
            if (idx == 0xFF) break;
            hl = util_add_bx_al(D64_CHR_ROOM_LINKS, idx);
            bits = rb(ix);
            ix = (uint16_t)(ix + 1);
            wb(hl, util_bits_set_or_clear(bits, rb(hl), rb(D64_OBJ_DOOR_ALLOW_OP) == D64_OP_CCF));
        }
    }
}

/* 3A37 ai_hour_update (PC 1000:5D5E): once per frame: txt_phrase_busy := txt_phrase_active; nothing more
 * while the camera character is between two steps (bit 0 of its record); when ai_advance_hour is set
 * and no phrase is shown, clears it and advances the hour (5094); then the hour-change actions (5A4F,
 * reached by JP: its RET returns to the caller). */
void ai_hour_update(void)
{
    wb(D64_TXT_PHRASE_BUSY, rb(D64_TXT_PHRASE_ACTIVE));
    if (rb(rw(D64_CHR_CAMERA_TARGET)) & 0x01) return;
    if (rb(D64_AI_ADVANCE_HOUR)) {
        if (rb(D64_TXT_PHRASE_BUSY)) return;
        wb(D64_AI_ADVANCE_HOUR, 0);
        ai_clock_advance_hour();                               /* CALL 5094 */
    }
    ai_hour_change_events();                                   /* JP 5A4F */
}

/* 3A58 ai_say_phrase_param (PC 1000:5D92): `CALL 4B7C <db n>` whose inline byte 3A5B is the script
 * variable ai_phrase_param (A2h): hud_say of that phrase; RET. */
void ai_say_phrase_param(void)
{
    (void)hud_say(rb(D64_AI_PHRASE_PARAM));
}

/* 3A5D util_jump_table_inline (PC 1000:5D97): `CALL 3A5D <dw t0, t1, ..., 0000>`, a switch after a
 * script test: zero (ZF = 1) selects t0; otherwise entry sel (C, counted from t1; sel = 0 walks 256
 * entries).  The selected entry is entered by JP with the CALL's return address dropped (its RET returns
 * to the caller's caller); reaching the 0000 returns after the table.  Returns where the program goes on
 * (the entry, or the address after the 0000). */
uint16_t util_jump_table_inline(bool zero, uint8_t sel, uint16_t table)
{
    uint16_t w;
    uint8_t b = 1;
    if (!zero) {
        b = sel;
        table = (uint16_t)(table + 2);
    }
    for (;;) {
        w = rw(table);
        table = (uint16_t)(table + 2);
        if (!w) return table;
        if (!--b) return w;
    }
}

/* =========================================================================================== */
#ifndef JUEGO_PURO  /* the hybrid host */
/* ---- the wrappers and their checks (hybrid host) ---- */

static uint8_t paridad_par(uint8_t v)
{
    v ^= (uint8_t)(v >> 4);
    v ^= (uint8_t)(v >> 2);
    v ^= (uint8_t)(v >> 1);
    return (uint8_t)(!(v & 1));
}

static uint8_t f_de(const z80 *z)
{
    return (uint8_t)(z->sf << 7 | z->zf << 6 | z->yf << 5 | z->hf << 4 | z->xf << 3 | z->pf << 2 | z->nf << 1 | z->cf);
}

static void pon_f(uint8_t f)
{
    cpu.sf = (f >> 7) & 1;
    cpu.zf = (f >> 6) & 1;
    cpu.yf = (f >> 5) & 1;
    cpu.hf = (f >> 4) & 1;
    cpu.xf = (f >> 3) & 1;
    cpu.pf = (f >> 2) & 1;
    cpu.nf = (f >> 1) & 1;
    cpu.cf = f & 1;
}

/* the flags of AND (h = 1), OR / XOR (h = 0) with result r */
static uint8_t f_logica(uint8_t r, int h)
{
    return (uint8_t)((r & 0xA8) | (r ? 0 : 0x40) | (h ? 0x10 : 0) | (paridad_par(r) ? 0x04 : 0));
}

/* the flags of ADD A,b */
static uint8_t f_suma(uint8_t a, uint8_t b)
{
    uint8_t r = (uint8_t)(a + b);
    return (uint8_t)((r & 0xA8) | (r ? 0 : 0x40) | (((a & 0x0F) + (b & 0x0F)) > 0x0F ? 0x10 : 0)
                     | ((~(a ^ b) & (a ^ r) & 0x80) ? 0x04 : 0) | ((unsigned)a + b > 0xFF ? 0x01 : 0));
}

/* the flags of SUB b (cp = 1: CP b, X and Y from b) */
static uint8_t f_resta(uint8_t a, uint8_t b, int cp)
{
    uint8_t r = (uint8_t)(a - b);
    return (uint8_t)(((cp ? b : r) & 0x28) | (r & 0x80) | (r ? 0 : 0x40) | ((a & 0x0F) < (b & 0x0F) ? 0x10 : 0)
                     | (((a ^ b) & (a ^ r) & 0x80) ? 0x04 : 0) | 0x02 | (a < b ? 0x01 : 0));
}

/* the flags of INC v (CF kept) */
static uint8_t f_inc(uint8_t v, int cf)
{
    uint8_t r = (uint8_t)(v + 1);
    return (uint8_t)((r & 0xA8) | (r ? 0 : 0x40) | ((v & 0x0F) == 0x0F ? 0x10 : 0) | (v == 0x7F ? 0x04 : 0) | (cf ? 1 : 0));
}

static int cmp8(const char *nombre, uint8_t c, uint8_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %02X Z80 %02X", nombre, c, z);
    return 0;
}

static int cmp16(const char *nombre, uint16_t c, uint16_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %04X Z80 %04X", nombre, c, z);
    return 0;
}

#define R_HL(z) ((uint16_t)((z)->h << 8 | (z)->l))
#define R_DE(z) ((uint16_t)((z)->d << 8 | (z)->e))
#define R_BC(z) ((uint16_t)((z)->b << 8 | (z)->c))
#endif

/* the declared results of a wrapper: a mask of registers, and for F the mask of its compared bits */
enum { RA = 1, RB = 2, RC = 4, RDE = 8, RHL = 16, RIX = 32, RIY = 64, RA_ = 128, RIFF = 256 };

#ifndef JUEGO_PURO  /* the hybrid host */
static int compara_regs(const z80 *cz, const z80 *zz, unsigned regs, uint8_t fmask, char *msg, size_t n)
{
    int ok = 1;
    if (regs & RA) ok &= cmp8("A", cz->a, zz->a, msg, n);
    if (regs & RB) ok &= cmp8("B", cz->b, zz->b, msg, n);
    if (regs & RC) ok &= cmp8("C", cz->c, zz->c, msg, n);
    if (regs & RDE) ok &= cmp16("DE", R_DE(cz), R_DE(zz), msg, n);
    if (regs & RHL) ok &= cmp16("HL", R_HL(cz), R_HL(zz), msg, n);
    if (regs & RIX) ok &= cmp16("IX", cz->ix, zz->ix, msg, n);
    if (regs & RIY) ok &= cmp16("IY", cz->iy, zz->iy, msg, n);
    if (regs & RA_) ok &= cmp8("A'", cz->a_, zz->a_, msg, n);
    if (regs & RIFF) ok &= cmp8("IFF1", cz->iff1, zz->iff1, msg, n);
    if (fmask) ok &= cmp8("F", (uint8_t)(f_de(cz) & fmask), (uint8_t)(f_de(zz) & fmask), msg, n);
    return ok;
}

#define FCF 0x01
#define FZF 0x40
#define FALL 0xFF

/* 2FAD */
static void w_2FAD(void) { obj_open_left_wing_doors(); SET_HL(0xC002); z80_ret(); }
static int r_2FAD(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RHL, 0, m, n); }

/* 2FB9: the registers are those of the external calls, as in the Z80 */
static void w_2FB9(void)
{
    uint8_t code;
    uint16_t hl = HL, de = DE;
    cpu.a = sys_check_pause_save_load(&code);
    cpu.c = code;
    pon_f(cpu.a ? 0x00 : 0x40);         /* the flags of the last sys_key_pressed: ZF, CF = 0 */
    SET_HL(hl);                         /* 2E7D keeps HL and DE */
    SET_DE(de);
    z80_ret();
}
static int r_2FB9(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RIFF, FZF, m, n); }

/* 304F */
static void w_304F(void)
{
    z80 e = cpu;
    spr_unflip_monk_faces();
    cpu.iy = e.iy;
    SET_HL(D64_SPR_MONK_FACES + 8);
    cpu.b = 0;
    cpu.c = e.c;
    z80_ret();
}
static int r_304F(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RB | RC | RHL | RIY, 0, m, n); }

/* 3087 */
static void w_3087(void)
{
    obj_fix_owner_pointers();
    cpu.ix = D64_OBJ_DOOR_PERMISSIONS + 18;
    cpu.iy = D64_OBJ_CHAR_OBJECTS + 42;
    SET_HL(D64_CHR_POS_PTRS + 12);
    SET_BC(0);
    SET_DE(7);
    cpu.a = rb(D64_CHR_POS_PTRS + 11);
    z80_ret();
}
static int r_3087(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RDE | RHL | RIX | RIY, 0, m, n); }

/* 30FD */
static void w_30FD(void)
{
    uint16_t p = cpu.ix;
    bool dentro = spr_tile_ptr_check(p);
    if (p < D64_ISO_TILE_BUFFER) { SET_HL((uint16_t)(p - D64_ISO_TILE_BUFFER)); SET_DE(D64_ISO_TILE_BUFFER); }
    else { SET_HL((uint16_t)(p - D64_ISO_TILE_BUFFER - D64_ISO_TILE_BUFFER_SIZE)); SET_DE(D64_ISO_TILE_BUFFER_SIZE); }
    cpu.cf = !dentro;
    z80_ret();
}
static int r_30FD(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RDE | RHL, FCF, m, n); }

/* 3111 / 310E: the end state of game_for_each_state_block */
static void fin_bloques(uint16_t cursor)
{
    SET_HL(cursor);
    SET_DE(0);
    SET_BC(0);
    cpu.a = 0;
    cpu.ix = D64_GAME_STATE_BLOCKS_END;
    pon_f(f_logica(0, 0));
}
static void w_3111(void) { fin_bloques(game_for_each_state_block(HL)); z80_ret(); }
static void w_310E(void) { fin_bloques(game_snapshot_initial_state()); z80_ret(); }
static int r_3111(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RDE | RHL | RIX, FALL, m, n); }

/* 3166 / 316B */
static void w_3166(void)
{
    uint16_t de = DE, bc = BC;
    SET_HL(game_state_block_save(HL, de, bc));
    SET_DE((uint16_t)(de + bc));
    SET_BC(0);
    z80_ret();
}
static void w_316B(void)
{
    uint16_t de = DE, bc = BC;
    SET_HL(game_state_block_restore(HL, de, bc));
    SET_DE((uint16_t)(de + bc));
    SET_BC(0);
    z80_ret();
}
static int r_3166(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RB | RC | RDE | RHL, 0, m, n); }

/* 316E */
static void w_316E(void)
{
    uint16_t p = HL, c = BC;
    util_clear_bytes(p, c);
    SET_HL((uint16_t)(p + c));
    SET_DE((uint16_t)(p + c + 1));
    SET_BC(0);
    z80_ret();
}

/* 3176 */
static void w_3176(void)
{
    uint16_t hl;
    game_init_new_game();
    for (hl = D64_SPR_TABLE; rb(hl) != 0xFF; hl = (uint16_t)(hl + 0x14)) ;
    SET_HL(hl);
    SET_DE(0x000F);
    SET_BC(0);
    cpu.a = 0;
    cpu.ix = D64_CHR_GUILLERMO + 6 * 0x0F;
    z80_ret();
}
static int r_3176(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RDE | RHL | RIX, 0, m, n); }

/* 3456: IX kept; C = 0 and ZF from the end of the list */
static void w_3456(void)
{
    z80 e = cpu;
    chr_hbuf_fill_room();
    cpu.ix = e.ix;
    cpu.c = 0;
    cpu.zf = 1;
    z80_ret();
}
static void w_346E(void)
{
    cpu.ix = chr_hbuf_fill_list(cpu.ix);
    cpu.c = 0;
    cpu.zf = 1;
    z80_ret();
}
static int r_346E(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RC | RIX, FZF, m, n); }

/* 3521 / 352C / 3535 / 3540: A and its flags, A' the scratch */
static void w_3521(void) { uint8_t a = cpu.a; cpu.a = chr_hbuf_slope_x_inc(a, cpu.h_); pon_f(f_suma(a, cpu.h_)); cpu.a_ = D64_OP_INC_C; z80_ret(); }
static void w_352C(void) { uint8_t a = cpu.a; cpu.a = chr_hbuf_slope_y_dec(a, cpu.h); pon_f(f_resta(a, cpu.h, 0)); cpu.a_ = D64_OP_DEC_C; z80_ret(); }
static void w_3535(void) { uint8_t a = cpu.a; cpu.a = chr_hbuf_slope_x_dec(a, cpu.h_); pon_f(f_resta(a, cpu.h_, 0)); cpu.a_ = D64_OP_DEC_C; z80_ret(); }
static void w_3540(void) { uint8_t a = cpu.a; cpu.a = chr_hbuf_slope_y_inc(a, cpu.h); pon_f(f_suma(a, cpu.h)); cpu.a_ = D64_OP_INC_C; z80_ret(); }
static int r_3521(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RA_, FALL, m, n); }

/* 3549 / 354D / 3786 */
static void pon_recorte(bool vis, uint8_t count, uint8_t skip, uint8_t start)
{
    cpu.a = count;
    cpu.h = skip;
    cpu.l = start;
    cpu.cf = vis;
}
static void w_3549(void)
{
    uint8_t count, skip, start;
    bool vis = chr_hbuf_clip_x(cpu.h, cpu.d, &count, &skip, &start);
    pon_recorte(vis, count, skip, start);
    cpu.d = (uint8_t)(cpu.d + 1);
    cpu.e = count;
    z80_ret();
}
static void w_354D(void)
{
    uint8_t count, skip, start;
    bool vis = chr_hbuf_clip_y(cpu.h, cpu.d, &count, &skip, &start);
    pon_recorte(vis, count, skip, start);
    cpu.d = (uint8_t)(cpu.d + 1);
    cpu.e = count;
    z80_ret();
}
static void w_3786(void)
{
    uint8_t count, skip, start;
    bool vis = util_clip_span(cpu.l, cpu.h, cpu.d, cpu.e, &count, &skip, &start);
    pon_recorte(vis, count, skip, start);
    z80_ret();
}
static int r_3549(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RDE | RHL, FCF, m, n); }
static int r_3786(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RHL, FCF, m, n); }

/* 3558: A = the new H; flags of the ADD (no carry) or of the OR C0h */
static void w_3558(void)
{
    uint16_t p = HL, q = vid_next_line(p);
    uint8_t h = (uint8_t)(p >> 8);
    SET_HL(q);
    cpu.a = (uint8_t)(q >> 8);
    if (h < 0xF8) pon_f(f_suma(h, 8));
    else pon_f(f_logica(cpu.a, 0));
    z80_ret();
}
static int r_3558(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RHL, FALL, m, n); }

/* 3607 and the start-up: the constant end state of vid_init_stub */
static void fin_tablas(void)
{
    cpu.a = 0;
    SET_BC(0x8F00);
    SET_DE(0x00FF);
    pon_f(f_inc(0xFF, 0));
}
static void w_3607(void) { vid_init_stub(); fin_tablas(); z80_ret(); }
static int r_3607(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RDE, FALL, m, n); }
static void w_3568(void)
{
    uint16_t hl = sys_startup_init();
    fin_tablas();
    SET_HL(hl);
    cpu.ix = D64_GAME_STATE_BLOCKS_END;
    z80_ret();
}
static int r_3568(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RDE | RHL | RIX, FALL, m, n); }

/* 3598 / 35B0 */
static void w_3598(void)
{
    SET_HL(hud_rows_from_hidden());
    SET_DE(0xF800);
    cpu.a = cpu.h;
    cpu.b = 0;
    z80_ret();
}
static void w_35B0(void)
{
    uint16_t src = DE;
    SET_HL(vid_copy_lines_to_row(HL, src));
    SET_DE((uint16_t)(src + 0x200));
    cpu.a = cpu.h;
    cpu.b = 0;
    z80_ret();
}
static int r_35B0(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RDE | RHL, 0, m, n); }

/* 35C3 / 35F8 */
static void w_35C3(void) { SET_HL(game_init_mirror()); z80_ret(); }
static void w_35F8(void) { SET_HL(chr_hbuf_skip_list(HL)); cpu.a = 0xFF; cpu.zf = 1; z80_ret(); }
static int r_35F8(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RHL, FZF, m, n); }

/* 3649 / 364D: the registers of the drawing */
static void fin_letra(uint8_t c, uint8_t mask, uint16_t cursor, bool drawn)
{
    cpu.c = mask;
    if (!drawn) {                                              /* RET C after SUB 2Dh */
        uint8_t a = (uint8_t)(c & 0x7F);
        SET_DE(D64_TXT_GLYPH_BLANK);
        pon_f(f_resta(a, 0x2D, 0));
        cpu.a = (uint8_t)(a - 0x2D);
    } else {
        uint16_t p = vid_xy_to_offset(cursor);
        uint8_t k, a7 = (uint8_t)(c & 0x7F);
        for (k = 0; k < 8; ++k) p = vid_next_line(p);
        cpu.a = (uint8_t)(p >> 8);
        SET_DE((uint16_t)((a7 == 0x20 ? D64_TXT_GLYPH_BLANK : D64_TXT_FONT + (uint16_t)(a7 - 0x2D) * 8u) + 8));
        cpu.b = 0;
        SET_HL(rw(D64_TXT_CURSOR));
        pon_f(f_inc((uint8_t)(cursor + 1), 0));
    }
}
static void w_3649(void) { uint8_t c = cpu.a; uint16_t cur = rw(D64_TXT_CURSOR); fin_letra(c, 0xFF, cur, txt_draw_char_inverted(c)); z80_ret(); }
static void w_364D(void) { uint8_t c = cpu.a; uint16_t cur = rw(D64_TXT_CURSOR); fin_letra(c, 0x0F, cur, txt_draw_char(c)); z80_ret(); }
static int r_3649(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RDE | RHL, FALL, m, n); }

/* 368A: every register but AF kept; the interrupt state (DI, and the EI of snd_play_beep) */
static void w_368A(void)
{
    z80 e = cpu;
    bool i1, i2;
    uint8_t d;
    txt_phrase_tick();
    i1 = cpu.iff1; i2 = cpu.iff2; d = cpu.iff_delay;
    cpu = e;
    cpu.iff1 = i1; cpu.iff2 = i2; cpu.iff_delay = d;
    z80_ret();
}
static int r_368A(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RB | RC | RDE | RHL | RIX | RIY | RA_ | RIFF, 0, m, n); }

/* 3770 / 3778 */
static void w_3770(void) { SET_HL(txt_skip_words(HL, cpu.b)); cpu.b = 0; z80_ret(); }
static int r_3770(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RB | RHL, 0, m, n); }
static void w_3778(void) { SET_HL(vid_xy_to_offset(HL)); cpu.a = cpu.l; pon_f(f_logica(cpu.a, 0)); z80_ret(); }
static int r_3778(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RHL, FALL, m, n); }

/* 3910 / 3994 / 3926 */
static void w_3910(void)
{
    uint8_t op = cpu.a;
    uint16_t entry = (uint16_t)(D64_AI_SCRIPT_VARS + (uint8_t)(op + op));
    SET_HL(ai_script_var_ptr(op));
    SET_DE((uint16_t)(entry + 1));
    cpu.a = (uint8_t)(entry >> 8);
    z80_ret();
}
static int r_3910(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RDE | RHL, 0, m, n); }
static void w_3994(void)
{
    uint16_t p = HL;
    uint8_t b0 = rb(p);
    cpu.c = ai_script_operand(&p);
    SET_HL(p);
    if (b0 == 0x40 || b0 < 0x80) cpu.a = b0;
    else {
        uint16_t entry = (uint16_t)(D64_AI_SCRIPT_VARS + (uint8_t)(b0 + b0));
        cpu.a = (uint8_t)(entry >> 8);
        SET_DE((uint16_t)(entry + 1));
    }
    z80_ret();
}
static int r_3994(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RC | RHL, 0, m, n); }
static void w_3926(void)
{
    uint16_t p = HL;
    cpu.c = ai_script_eval(&p);
    SET_HL(p);
    cpu.a = rb(p);
    pon_f(f_resta(cpu.a, cpu.a, 1));
    z80_ret();
}
static int r_3926(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RC | RHL, FALL, m, n); }

/* 391E (RST 08h) / 38FC (RST 10h): pop the address of the inline data, return past it (the new return
 * address is pushed into the same slot) */
static void w_391E(void)
{
    uint16_t p = rw(cpu.sp);
    uint8_t v = ai_script_test(&p);
    ww(cpu.sp, p);                                             /* PUSH HL / RET */
    cpu.sp = (uint16_t)(cpu.sp + 2);
    SET_HL(p);
    cpu.c = v;
    cpu.a = v;
    pon_f(f_logica(v, 1));
    cpu.pc = p;
}
static void w_38FC(void)
{
    uint16_t p = rw(cpu.sp);
    uint8_t v = ai_script_assign(&p);
    ww(cpu.sp, p);                                             /* PUSH HL / RET */
    cpu.sp = (uint16_t)(cpu.sp + 2);
    SET_HL(p);
    cpu.c = v;
    cpu.a = v;
    pon_f(f_resta(rb(p), rb(p), 1));
    cpu.pc = p;
}
static int r_391E(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RC | RHL, FALL, m, n); }

/* 39A8 / 39AE / 39E5 */
static void w_39A8(void) { ai_stay(); cpu.a = 1; z80_ret(); }
static void w_39AE(void) { cpu.zf = ai_guillermo_is_close(cpu.iy); z80_ret(); }
static int r_39AE(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RIY, FZF, m, n); }
static void w_39E5(void)
{
    uint16_t pl = cpu.ix;
    uint8_t a = rb((uint16_t)(pl - 1)), b = rb((uint16_t)(pl - 3));
    if (ai_next_state_on_arrival(pl)) { cpu.a = 0; pon_f(f_logica(0, 0)); }
    else { cpu.a = a; pon_f(f_resta(a, b, 1)); }
    z80_ret();
}
static int r_39E5(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA, FALL, m, n); }

/* 39F1 / 3A30 */
static void w_39F1(void)
{
    z80 e = cpu;
    uint8_t c = cpu.c;
    obj_set_door_permissions(c);
    cpu.ix = e.ix;
    cpu.a = 0xFF;
    cpu.b = 0;
    cpu.c = (uint8_t)((rb(D64_OBJ_DOOR_CHECK_MASK) & c) >> 6);
    SET_HL(D64_CHR_ROOM_LINKS);
    pon_f(f_resta(0xFF, 0xFF, 1));
    z80_ret();
}
static int r_39F1(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RHL | RIX, FALL, m, n); }
static void w_3A30(void)
{
    bool clear = cpu.cf;
    cpu.a = util_bits_set_or_clear(cpu.a, cpu.e, clear);
    pon_f(f_logica(cpu.a, clear));
    z80_ret();
}

/* 3A37: the registers are those left by the tail call (5A4F), as in the Z80 */
static void w_3A37(void) { ai_hour_update(); z80_ret(); }
/* 3A58: the registers of hud_say (4B7C) are read by no caller (the scripts) */
static void w_3A58(void) { ai_say_phrase_param(); z80_ret(); }

/* 3A5D: no return to the caller: PC = the entry (JP (HL)) or after the table (PUSH HL / RET) */
static void w_3A5D(void)
{
    uint16_t table = rw(cpu.sp), w, p;
    bool zero = cpu.zf;
    uint8_t b = zero ? 1 : cpu.c;
    p = util_jump_table_inline(zero, cpu.c, table);
    cpu.sp = (uint16_t)(cpu.sp + 2);
    /* the registers of the walk: B counts down, DE = the last word read */
    if (!zero) table = (uint16_t)(table + 2);
    for (;;) {
        w = rw(table);
        table = (uint16_t)(table + 2);
        if (!w || !--b) break;
    }
    if (w) { SET_HL(w); SET_DE(table); }
    else { SET_HL(table); SET_DE(0); ww((uint16_t)(cpu.sp - 2), table); }   /* PUSH HL / RET */
    cpu.b = b;
    cpu.a = (uint8_t)(w >> 8 | w);
    pon_f(f_logica(cpu.a, 0));
    cpu.pc = p;
}
static int r_3A5D(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RDE | RHL, FALL, m, n); }

/* 3A83 / 3A88 / 3A8D */
static void fin_paleta(uint16_t table)
{
    SET_HL((uint16_t)(table + 4));
    cpu.a = 0;
    cpu.b = 0x7F;
    cpu.c = (uint8_t)(rb((uint16_t)(table + 4)) | 0x40);
    pon_f((uint8_t)((f_resta(1, 1, 0) & ~0x01) | (cpu.cf ? 1 : 0)));
}
static void w_3A83(void) { vid_palette_black(); fin_paleta(D64_VID_PALETTE_BLACK); z80_ret(); }
static void w_3A88(void) { vid_palette_day(); fin_paleta(D64_VID_PALETTE_DAY); z80_ret(); }
static void w_3A8D(void) { vid_palette_night(); fin_paleta(D64_VID_PALETTE_NIGHT); z80_ret(); }
static int r_3A83(const z80 *cz, const z80 *zz, char *m, size_t n) { return compara_regs(cz, zz, RA | RB | RC | RHL, FALL, m, n); }

const traducida_t traducidas_estado_texto[] = {
    { 0x2FAD, "obj_open_left_wing_doors", w_2FAD, r_2FAD },
    { 0x2FB9, "sys_check_pause_save_load", w_2FB9, r_2FB9 },
    { 0x304F, "spr_unflip_monk_faces", w_304F, r_304F },
    { 0x3087, "obj_fix_owner_pointers", w_3087, r_3087 },
    { 0x30FD, "spr_tile_ptr_check", w_30FD, r_30FD },
    { 0x310E, "game_snapshot_initial_state", w_310E, r_3111 },
    { 0x3111, "game_for_each_state_block", w_3111, r_3111 },
    { 0x3166, "game_state_block_save", w_3166, r_3166 },
    { 0x316B, "game_state_block_restore", w_316B, r_3166 },
    { 0x316E, "util_clear_bytes", w_316E, r_3166 },
    { 0x3176, "game_init_new_game", w_3176, r_3176 },
    { 0x3456, "chr_hbuf_fill_room", w_3456, r_346E },
    { 0x346E, "chr_hbuf_fill_list", w_346E, r_346E },
    { 0x3521, "chr_hbuf_slope_x_inc", w_3521, r_3521 },
    { 0x352C, "chr_hbuf_slope_y_dec", w_352C, r_3521 },
    { 0x3535, "chr_hbuf_slope_x_dec", w_3535, r_3521 },
    { 0x3540, "chr_hbuf_slope_y_inc", w_3540, r_3521 },
    { 0x3549, "chr_hbuf_clip_x", w_3549, r_3549 },
    { 0x354D, "chr_hbuf_clip_y", w_354D, r_3549 },
    { 0x3558, "vid_next_line", w_3558, r_3558 },
    { 0x3568, "sys_startup_init", w_3568, r_3568 },
    { 0x3598, "hud_rows_from_hidden", w_3598, r_35B0 },
    { 0x35B0, "vid_copy_lines_to_row", w_35B0, r_35B0 },
    { 0x35C3, "game_init_mirror", w_35C3, resultado_hl },
    { 0x35F8, "chr_hbuf_skip_list", w_35F8, r_35F8 },
    { 0x3607, "vid_init_stub", w_3607, r_3607 },
    { 0x3649, "txt_draw_char_inverted", w_3649, r_3649 },
    { 0x364D, "txt_draw_char", w_364D, r_3649 },
    { 0x368A, "txt_phrase_tick", w_368A, r_368A },
    { 0x3770, "txt_skip_words", w_3770, r_3770 },
    { 0x3778, "vid_xy_to_offset", w_3778, r_3778 },
    { 0x3786, "util_clip_span", w_3786, r_3786 },
    { 0x38FC, "ai_script_assign", w_38FC, r_391E },
    { 0x3910, "ai_script_var_ptr", w_3910, r_3910 },
    { 0x391E, "ai_script_test", w_391E, r_391E },
    { 0x3926, "ai_script_eval", w_3926, r_3926 },
    { 0x3994, "ai_script_operand", w_3994, r_3994 },
    { 0x39A8, "ai_stay", w_39A8, resultado_a },
    { 0x39AE, "ai_guillermo_is_close", w_39AE, r_39AE },
    { 0x39E5, "ai_next_state_on_arrival", w_39E5, r_39E5 },
    { 0x39F1, "obj_set_door_permissions", w_39F1, r_39F1 },
    { 0x3A30, "util_bits_set_or_clear", w_3A30, r_39E5 },
    { 0x3A37, "ai_hour_update", w_3A37, sin_resultados },
    { 0x3A58, "ai_say_phrase_param", w_3A58, sin_resultados },
    { 0x3A5D, "util_jump_table_inline", w_3A5D, r_3A5D },
    { 0x3A83, "vid_palette_black", w_3A83, r_3A83 },
    { 0x3A88, "vid_palette_day", w_3A88, r_3A83 },
    { 0x3A8D, "vid_palette_night", w_3A8D, r_3A83 },
    { 0, NULL, NULL, NULL }
};
#endif

