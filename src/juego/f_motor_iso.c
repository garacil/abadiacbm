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

/* abadia64ks, group motor_iso (64K 128F-2225): the isometric engine: the tile buffer and the tile
 * placing, the room builder and its block interpreter (opcode table 1BEEh, block table 11DDh, room
 * table 6100h), the play-area fill of the CPC screen, the camera's room change and transforms, the
 * floor bases.  Each function cites its CPC 64 KiB address and the PC rebuild's function
 * (c/src/iso.c); the 64K code is the reference.  Then the wrappers and checks of the hybrid host and
 * the table traducidas_motor_iso.
 *
 * The interpreter (1C26-1E49) is translated as a whole, as the PC rebuild did: its handlers are
 * entered by the dispatcher's PUSH DE / RET, not by CALL, and keep state on the Z80 stack across
 * handlers, so they are static functions on an iso_vm (datos_motor_iso.h) and are checked through
 * their CALLed entries (iso_build_room, iso_draw_room, iso_tile_run, iso_put_tile_step...). */
#include <stdio.h>
#include <string.h>
#include "juego64.h"
#include "datos_motor_iso.h"

/* ================================================================================================
 * Utilities, tiles and the tile buffer
 * ================================================================================================ */

/* 128F util_add_bx_al (PC 1000:289C): HL + A (A unsigned), 16 bit.  In: HL, A.  Out: HL (A = its high
 * byte, F of the SUB that computes it: see the wrapper). */
uint16_t util_add_bx_al(uint16_t hl, uint8_t a)
{
    return (uint16_t)(hl + a);
}

/* the step instructions the program keeps at its SMC sites (1C60, 1C66, 1CF8, 1CFF, 1D06, 1D29):
 * INC H, DEC H, INC L, DEC L on the position HL */
static uint16_t iso_exec_step(uint8_t insn, uint16_t hl)
{
    uint8_t h = (uint8_t)(hl >> 8), l = (uint8_t)hl;
    switch (insn) {
    case D64_ISO_INSN_INC_H: ++h; break;
    case D64_ISO_INSN_DEC_H: --h; break;
    case D64_ISO_INSN_INC_L: ++l; break;
    case D64_ISO_INSN_DEC_L: --l; break;
    default: break;
    }
    return (uint16_t)(h << 8 | l);
}

/* 1295 iso_put_tile (PC 1000:28A7): puts tile at the grid position pos (H = y, L = x) when it is
 * visible (y - 8 < 14h, x - 8 < 10h).  The cell is tile buffer + 96 (y - 8) + 6 (x - 8); the JP at
 * 12BF goes to the word at 12C0: 12C9h (always while a room is built), the cell update: the old tile
 * [5] becomes the lower tile [2]; [0],[1] = the old depth [3],[4], or the current depth when it is
 * smaller in both coordinates; [3],[4] = the current depth (1BEC, 1BED); [5] = tile.  12C2h (set after
 * building, never used then): the tile at cell + 780h.  In: pos (HL), tile (C), *de (DE).  Out: A =
 * the depth y put, or the coordinate that failed (y - 8, or x - 8 with D = y - 8); *de = cell + 1 (DE
 * of the update), 0780h (the other form); HL and BC are kept. */
uint8_t iso_put_tile(uint16_t pos, uint8_t tile, uint16_t *de)
{
    uint8_t row = (uint8_t)((pos >> 8) - 8), col, old_x, old_y, lo_x, lo_y, dx, dy;
    uint16_t off, cell;
    if (row >= 0x14) return row;
    *de = (uint16_t)(row << 8 | (*de & 0xFF));
    col = (uint8_t)((uint8_t)pos - 8);
    if (col >= 0x10) return col;
    off = util_add_bx_al((uint16_t)(row * 0x60u), (uint8_t)(col * 6));
    cell = (uint16_t)(off + D64_ISO_TILE_BUFFER);
    if (rw(D64_ISO_PUT_TILE_JUMP) == D64_ISO_PUT_TILE_MARK) {
        wb((uint16_t)(cell + 0x0780), tile);
        *de = 0x0780;
        return (uint8_t)(off >> 8);
    }
    old_x = rb((uint16_t)(cell + 3));
    old_y = rb((uint16_t)(cell + 4));
    wb((uint16_t)(cell + 2), rb((uint16_t)(cell + 5)));
    dx = rb(D64_ISO_DEPTH_X);
    wb((uint16_t)(cell + 3), dx);
    lo_x = old_x;
    lo_y = old_y;
    if (dx < old_x) {
        dy = rb(D64_ISO_DEPTH_Y);
        if (dy < old_y) {
            lo_y = dy;
            lo_x = rb(D64_ISO_DEPTH_X);
        }
    }
    dy = rb(D64_ISO_DEPTH_Y);
    wb((uint16_t)(cell + 4), dy);
    wb(cell, lo_x);
    wb((uint16_t)(cell + 1), lo_y);
    wb((uint16_t)(cell + 5), tile);
    *de = (uint16_t)(cell + 1);
    return dy;
}

/* 1D26 iso_put_tile_step (PC 1000:2B60; f_1D26): iso_put_tile, then the step instruction at 1D29
 * (written by iso_tile_run: DEC H, DEC L or INC L).  In: pos (HL), tile (C), *de.  Out: the position
 * stepped (HL); *a = A of iso_put_tile; *de as iso_put_tile leaves it. */
uint16_t iso_put_tile_step(uint16_t pos, uint8_t tile, uint8_t *a, uint16_t *de)
{
    *a = iso_put_tile(pos, tile, de);
    return iso_exec_step(rb(D64_ISO_TILE_STEP_INSN), pos);
}

/* 1D48 iso_put_tile_times (PC 1000:2B87): the count form of a tile run, broken as in the PC: the
 * counter is A, which iso_put_tile overwrites, so it repeats put + step while the A left by
 * iso_put_tile, minus one, is not 0 (the count itself is never used; no block uses this form).
 * In: pos (HL), tile (C), *de.  Out: the position (HL); A = 0. */
uint16_t iso_put_tile_times(uint16_t pos, uint8_t tile, uint16_t *de)
{
    uint8_t a;
    do {
        pos = iso_put_tile_step(pos, tile, &a, de);
        --a;
    } while (a != 0);
    return pos;
}

/* ================================================================================================
 * The play area of the CPC screen
 * ================================================================================================ */

/* 16B2 vid_fill_play_area (PC 1000:29F6): fills the 160 lines of the play area (the first 64 bytes of
 * each, from C000h; the next line from f_3558) with the byte fill, kept at 16C0 (the operand of the
 * LD (HL),n of each line).  In: fill (A), *de.  Out: HL = the line after the last one (from f_3558,
 * which also leaves A = H and F); *de = the last line + 40h; B = 0, C kept. */
uint16_t vid_fill_play_area(uint8_t fill, uint16_t *de)
{
    uint16_t hl = D64_VID_SCREEN;
    uint8_t lines, i, v;
    wb(D64_VID_FILL_BYTE, fill);
    for (lines = 0xA0; lines != 0; --lines) {
        v = rb(D64_VID_FILL_BYTE);
        for (i = 0; i < 0x40; ++i) wscr((uint16_t)(hl + i), v);
        *de = (uint16_t)(hl + 0x40);
        hl = vid_next_line(hl);             /* 16C7 CALL 3558 */
    }
    return hl;
}

/* 16A1 vid_fill_play_area_ff (f_16A1): vid_fill_play_area with FFh.  Out: as vid_fill_play_area. */
uint16_t vid_fill_play_area_ff(uint16_t *de)
{
    return vid_fill_play_area(0xFF, de);
}

/* 16A5 iso_clear_tile_buffer (PC 1000:29E1): zeroes the tile buffer (780h bytes at 8780h) and falls
 * into vid_fill_play_area.  In: fill (A).  Out: as vid_fill_play_area, with BC = 0. */
uint16_t iso_clear_tile_buffer(uint8_t fill, uint16_t *de)
{
    uint16_t i;
    for (i = 0; i < D64_ISO_TILE_BUFFER_SIZE; ++i) wb((uint16_t)(D64_ISO_TILE_BUFFER + i), 0);
    return vid_fill_play_area(fill, de);
}

/* ================================================================================================
 * The block interpreter
 * ================================================================================================ */

static void vm_push(iso_vm *vm, uint16_t v)
{
    if (vm->sp < ISO_VM_PILA) vm->pila[vm->sp++] = v;
}

static uint16_t vm_pop(iso_vm *vm)
{
    return vm->sp ? vm->pila[--vm->sp] : 0;
}

/* 1E27 iso_operand_value (PC 1000:2C88): the value of operand code: below 60h a literal; 82h the
 * literal byte [IX++]; else a register: codes from 70h on XOR the mirror flag (1E3E: depth x <-> y),
 * *reg = 1BDD + (code - 61h) (8-bit offset), the value [*reg] (61h-6Ch tiles, 6Dh p1, 6Eh p2, 6Fh
 * height, 70h/71h depth).  In: code (A), *ix.  Out: the value (C and A; ZF = it is 0), *ix, *reg = DE
 * (1BDD for a literal). */
uint8_t iso_operand_value(uint8_t code, uint16_t *ix, uint16_t *reg)
{
    uint8_t v;
    *reg = D64_ISO_BLOCK_TILES;
    if (code < 0x60) return code;
    if (code == 0x82) {
        v = rb(*ix);
        ++*ix;
        return v;
    }
    if (code >= 0x70) code ^= rb(D64_ISO_MIRROR);
    *reg = util_add_bx_al(D64_ISO_BLOCK_TILES, (uint8_t)(code - 0x61));
    return rb(*reg);
}

/* 1E22 iso_fetch_operand (PC 1000:2C85; f_1E22): A = [IX++], then iso_operand_value.  In: *ix.
 * Out: as iso_operand_value. */
uint8_t iso_fetch_operand(uint16_t *ix, uint16_t *reg)
{
    uint8_t code = rb(*ix);
    ++*ix;
    return iso_operand_value(code, ix, reg);
}

/* 1D74 iso_expression (PC 1000:2BC4): the rest of an expression: while [IX] < C8h, 84h negates the
 * value so far (8 bit), any other byte is an operand added to it; the opcode byte that ends it is
 * not consumed.  In: first (C), *ix.  Out: the value (C), *ix; A = [IX] (>= C8h); B kept. */
uint8_t iso_expression(uint8_t first, uint16_t *ix)
{
    uint8_t v = first, b;
    uint16_t reg;
    for (;;) {
        b = rb(*ix);
        if (b >= 0xC8) return v;
        if (b == 0x84) {
            ++*ix;
            v = (uint8_t)(0 - v);
            continue;
        }
        v = (uint8_t)(v + iso_fetch_operand(ix, &reg));
    }
}

/* 1D90 iso_fetch_word (PC 1000:2BE5): the word at [IX], IX += 2.  Out: DE, *ix. */
uint16_t iso_fetch_word(uint16_t *ix)
{
    uint8_t lo = rb(*ix), hi;
    ++*ix;
    hi = rb(*ix);
    ++*ix;
    return (uint16_t)(hi << 8 | lo);
}

/* 1BC6 iso_block_depth (PC 1000:287D): the depth of the block from its start position (H = y, L = x)
 * and height h: nothing for h = FF; else t = h/2 + y, depth x (1BEC) = t + x - 0Fh, depth y (1BED) =
 * 10h + t - x (8 bit).  In: pos (HL), height (A).  Out: memory (A = D = depth y, E = depth x). */
void iso_block_depth(uint16_t pos, uint8_t height)
{
    uint8_t x = (uint8_t)pos, y = (uint8_t)(pos >> 8), t;
    if (height == 0xFF) return;
    t = (uint8_t)((height >> 1) + y);
    wb(D64_ISO_DEPTH_X, (uint8_t)(t + x - 0x0F));
    wb(D64_ISO_DEPTH_Y, (uint8_t)(0x10 + t - x));
}

/* 1D0A iso_tile_run (PC 1000:2B3E): a tile run.  The step instruction (the byte after the CALL, at
 * step) is copied to 1D29 and the call returns past it.  Loop: tile = an operand; the next byte b:
 * >= C8h (the next opcode, not consumed): put the tile, step, end (JR into iso_put_tile_step); 80h:
 * put, step, next tile; 81h: put without stepping, next tile; other: the count form (b skipped, a
 * count operand, iso_put_tile_times when it is not 0, then the next byte ends the run when >= C8h,
 * else it is skipped).  In: step, *pos (HL), *ix, *bc (B kept).  Out: *pos, *ix, C of *bc = the last
 * tile; A (of iso_put_tile, or the opcode byte after the count form). */
uint8_t iso_tile_run(uint16_t step, uint16_t *pos, uint16_t *ix, uint16_t *bc)
{
    uint16_t de;
    uint8_t tile, b, a, n;
    wb(D64_ISO_TILE_STEP_INSN, rb(step));
    for (;;) {
        tile = iso_fetch_operand(ix, &de);
        *bc = (uint16_t)((*bc & 0xFF00) | tile);
        b = rb(*ix);
        if (b >= 0xC8) {
            *pos = iso_put_tile_step(*pos, tile, &a, &de);
            return a;
        }
        ++*ix;
        if (b == 0x80) {
            *pos = iso_put_tile_step(*pos, tile, &a, &de);
            continue;
        }
        if (b == 0x81) {
            iso_put_tile(*pos, tile, &de);
            continue;
        }
        n = iso_fetch_operand(ix, &de);        /* PUSH BC / the count / POP BC: C stays the tile */
        if (n != 0) *pos = iso_put_tile_times(*pos, tile, &de);
        a = rb(*ix);
        if (a >= 0xC8) return a;
        ++*ix;
    }
}

/* 1C26 (the tail of iso_enter_block): EX (SP),IX (the script start on the stack top becomes IX and
 * the caller's IX is kept there for END, then p1/p2 (1BE9, 1BEA) = BC. */
static void iso_enter_script(iso_vm *vm)
{
    uint16_t start = vm_pop(vm);
    vm_push(vm, vm->ix);
    vm->ix = start;
    ww(D64_ISO_BLOCK_P1, vm->bc);
}

/* 17EE iso_enter_block_keep_tiles (PC 1000:2A1B): the entry of CALL_KEEP: like iso_enter_block without
 * copying a tile list.  In: vm (HL = position, BC = p1/p2, the script start on its stack), height (A). */
void iso_enter_block_keep_tiles(iso_vm *vm, uint8_t height)
{
    iso_block_depth(vm->hl, height);
    iso_enter_script(vm);
}

/* 17F1 iso_enter_block (PC 1000:2A1E): starts interpreting a block: copies its 12 tile numbers from
 * tiles to 1BDD (LDIR), the depth from the position (iso_block_depth), then 1C26.  Reached by a JP
 * from iso_build_room and through the vector 1DFC of CALL.  In: vm (as 17EE), tiles (DE), height (A). */
void iso_enter_block(iso_vm *vm, uint16_t tiles, uint8_t height)
{
    uint8_t i;
    for (i = 0; i < 12; ++i) wb((uint16_t)(D64_ISO_BLOCK_TILES + i), rb((uint16_t)(tiles + i)));
    iso_block_depth(vm->hl, height);
    iso_enter_script(vm);
}

/* 1C4C (inside iso_op_end): the mirror undone: INC L at 1C60 and 1D06, DEC L at 1C66, mirror 0 */
static void iso_reset_mirror(void)
{
    wb(D64_ISO_OP_X_INC_INSN, D64_ISO_INSN_INC_L);
    wb(D64_ISO_STEP_RIGHT_INSN, D64_ISO_INSN_INC_L);
    wb(D64_ISO_OP_X_DEC_INSN, D64_ISO_INSN_DEC_L);
    wb(D64_ISO_MIRROR, 0);
}

/* 1C40 iso_op_end (PC 1000:2A58): opcode FF, END: IX = the caller's pointer (popped); the keep flag
 * (1BDC) is cleared, and when it was 0 the mirror is undone; RET: the tag popped (163F, the next room
 * entry; 1DFE, the end of a called block). */
static void iso_op_end(iso_vm *vm)
{
    uint8_t keep;
    vm->ix = vm_pop(vm);
    keep = rb(D64_ISO_KEEP_FLAG);
    wb(D64_ISO_KEEP_FLAG, 0);
    if (keep == 0) iso_reset_mirror();
    vm->ret = vm_pop(vm);
}

/* 1C95 iso_reg_add (PC 1000:2AC0): the register of operand code (6Dh p1, 6Eh p2) += delta; entered by
 * a JR from EF (p2 + 1), F0 (p1 + 1), ED (p2 - 1), EE (p1 - 1).  C = delta after it. */
static void iso_reg_add(iso_vm *vm, uint8_t code, uint8_t delta)
{
    uint16_t reg;
    uint8_t v = iso_operand_value(code, &vm->ix, &reg);
    wb(reg, (uint8_t)(v + delta));
    vm->bc = (uint16_t)((vm->bc & 0xFF00) | delta);
}

/* 1CB3 (inside iso_op_loop_p1): a loop of count 0 is skipped: a byte scan to the matching NEXT (FA):
 * 82h skips its literal, FE/FD/E8/E7 open a level, FA closes one (B counts them, 0 at the end). */
static void iso_loop_skip(iso_vm *vm)
{
    uint8_t level = 1, a;
    for (;;) {
        a = rb(vm->ix);
        vm->ix = (uint16_t)(vm->ix + 2);
        if (a == 0x82) continue;
        --vm->ix;
        if (a == 0xFE || a == 0xFD || a == 0xE8 || a == 0xE7) {
            ++level;
            continue;
        }
        if (a != 0xFA) continue;
        if (--level == 0) break;
    }
    vm->bc = (uint16_t)(vm->bc & 0x00FF);
}

/* 1C9F iso_op_loop_p1 (PC 1000:2AD2) and 1CAC (loop p2): opcodes FE / FD: count = p1 / p2 (C); 0 skips
 * to the matching NEXT, else PUSH IX (the loop start) and PUSH BC (C the count, B a leftover). */
static void iso_op_loop(iso_vm *vm, uint8_t code)
{
    uint16_t reg;
    uint8_t n = iso_operand_value(code, &vm->ix, &reg);
    vm->bc = (uint16_t)((vm->bc & 0xFF00) | n);
    if (n == 0) {
        iso_loop_skip(vm);
        return;
    }
    vm_push(vm, vm->ix);
    vm_push(vm, vm->bc);
}

/* 1CE5 iso_op_next (PC 1000:2B17): opcode FA: POP BC, C - 1; 0: the loop start is dropped (POP BC: BC =
 * that start); else IX = the loop start (kept) and BC pushed again. */
static void iso_op_next(iso_vm *vm)
{
    uint16_t bc = vm_pop(vm);
    uint8_t c = (uint8_t)(bc - 1);
    vm->bc = (uint16_t)((bc & 0xFF00) | c);
    if (c == 0) {
        vm->bc = vm_pop(vm);
        return;
    }
    vm->ix = vm_pop(vm);
    vm_push(vm, vm->ix);
    vm_push(vm, vm->bc);
}

/* 1D4F iso_op_set (PC 1000:2B8F): opcode F7 reg expr: register := expression.  Codes below 70h are
 * stored as they are (a literal destination writes t1 at 1BDD); the depth registers (70h/71h, swapped
 * while mirroring) keep the value 0 and take 0 for a result >= 64h.  C = the value. */
static void iso_op_set(iso_vm *vm)
{
    bool plain = rb(vm->ix) < 0x70;
    uint16_t dst, reg;
    uint8_t v;
    iso_fetch_operand(&vm->ix, &dst);
    v = iso_fetch_operand(&vm->ix, &reg);
    v = iso_expression(v, &vm->ix);
    vm->bc = (uint16_t)((vm->bc & 0xFF00) | v);
    if (!plain) {
        if (rb(dst) == 0) return;
        if (v >= 0x64) {
            v = 0;
            vm->bc = (uint16_t)(vm->bc & 0xFF00);
        }
    }
    wb(dst, v);
}

/* 1D9B iso_op_mirror (PC 1000:2BEC): opcodes E9-E5: DEC L at 1C60 and 1D06, INC L at 1C66, mirror 1
 * (operands 70h/71h exchanged) until the END of the block. */
static void iso_op_mirror(void)
{
    wb(D64_ISO_OP_X_INC_INSN, D64_ISO_INSN_DEC_L);
    wb(D64_ISO_STEP_RIGHT_INSN, D64_ISO_INSN_DEC_L);
    wb(D64_ISO_OP_X_DEC_INSN, D64_ISO_INSN_INC_L);
    wb(D64_ISO_MIRROR, 1);
}

/* 1DC5 (the common part of 1DB8 iso_op_call_keep and 1DC2 iso_op_call, PC 1000:2C1B): the vector at
 * 1DFC = entry; pushes HL, the SMC bytes of 1C60/1C66 and 1D06/1E3E, the depth (1BEC), p1/p2 (1BE9),
 * AF (A = the height 1BEB), the tag 1DFE; reads the block address, pushes its script start and jumps
 * through the vector with DE = its tile list, BC = p1/p2, A = the height. */
static void iso_call_common(iso_vm *vm, uint16_t entry)
{
    uint16_t block, tiles;
    uint8_t h;
    ww(D64_ISO_ENTER_VECTOR, entry);
    vm_push(vm, vm->hl);
    vm_push(vm, (uint16_t)(rb(D64_ISO_OP_X_DEC_INSN) << 8 | rb(D64_ISO_OP_X_INC_INSN)));
    vm_push(vm, (uint16_t)(rb(D64_ISO_MIRROR) << 8 | rb(D64_ISO_STEP_RIGHT_INSN)));
    vm_push(vm, rw(D64_ISO_DEPTH_X));
    vm->bc = rw(D64_ISO_BLOCK_P1);
    vm_push(vm, vm->bc);
    vm_push(vm, (uint16_t)(rb(D64_ISO_BLOCK_HEIGHT) << 8));
    vm_push(vm, D64_ISO_TAG_CALL_RETURN);
    block = iso_fetch_word(&vm->ix);
    h = rb(D64_ISO_BLOCK_HEIGHT);
    tiles = rw(block);
    vm_push(vm, (uint16_t)(block + 2));
    if (rw(D64_ISO_ENTER_VECTOR) == D64_ISO_ENTER_BLOCK_KEEP) iso_enter_block_keep_tiles(vm, h);
    else iso_enter_block(vm, tiles, h);
}

/* 1DFE iso_call_return (PC 1000:2C5E): where END returns after a called block: restores the height,
 * p1/p2, the depth, the bytes of 1D06/1E3E and 1C60/1C66 and HL (BC = the last word popped).  The 12
 * tile registers are not restored. */
static void iso_call_return(iso_vm *vm)
{
    wb(D64_ISO_BLOCK_HEIGHT, (uint8_t)(vm_pop(vm) >> 8));
    vm->bc = vm_pop(vm);
    ww(D64_ISO_BLOCK_P1, vm->bc);
    vm->bc = vm_pop(vm);
    ww(D64_ISO_DEPTH_X, vm->bc);
    vm->bc = vm_pop(vm);
    wb(D64_ISO_STEP_RIGHT_INSN, (uint8_t)vm->bc);
    wb(D64_ISO_MIRROR, (uint8_t)(vm->bc >> 8));
    vm->bc = vm_pop(vm);
    wb(D64_ISO_OP_X_INC_INSN, (uint8_t)vm->bc);
    wb(D64_ISO_OP_X_DEC_INSN, (uint8_t)(vm->bc >> 8));
    vm->hl = vm_pop(vm);
}

/* 1C2C the dispatcher (PC 1000:2A42): op = [IX++]; the handler = the word at 1BEE + (~op * 2 & FFh)
 * (DE), entered by PUSH DE / RET; every handler goes back to 1C2C.  Interprets until an END returns to
 * the room entry loop (163F); an END that returns to 1DFE goes on in iso_call_return.  (An opcode
 * outside FF-E4 would index other bytes as a handler, and an END tag other than these two would be a
 * RET to a random address: no block has them; both stop here.) */
static void iso_run(iso_vm *vm)
{
    uint8_t op;
    uint16_t h;
    for (;;) {
        op = rb(vm->ix);
        ++vm->ix;
        h = rw(util_add_bx_al(D64_ISO_BLOCK_OPCODE_TABLE, (uint8_t)((uint8_t)~op << 1)));
        vm->de = h;
        vm->ret = 0;
        switch (h) {
        case D64_ISO_OP_END: iso_op_end(vm); break;
        case D64_ISO_OP_Y_INC: vm->hl = iso_exec_step(D64_ISO_INSN_INC_H, vm->hl); break;
        case D64_ISO_OP_X_INC: vm->hl = iso_exec_step(rb(D64_ISO_OP_X_INC_INSN), vm->hl); break;
        case D64_ISO_OP_Y_DEC: vm->hl = iso_exec_step(D64_ISO_INSN_DEC_H, vm->hl); break;
        case D64_ISO_OP_X_DEC: vm->hl = iso_exec_step(rb(D64_ISO_OP_X_DEC_INSN), vm->hl); break;
        case D64_ISO_OP_Y_ADD:                 /* 1C69: H += the expression */
        case D64_ISO_OP_X_ADD: {               /* 1C74: L += the expression (not mirrored) */
            uint16_t reg;
            uint8_t v = iso_fetch_operand(&vm->ix, &reg);
            v = iso_expression(v, &vm->ix);
            vm->bc = (uint16_t)((vm->bc & 0xFF00) | v);
            if (h == D64_ISO_OP_Y_ADD) vm->hl = (uint16_t)((uint8_t)((vm->hl >> 8) + v) << 8 | (vm->hl & 0xFF));
            else vm->hl = (uint16_t)((vm->hl & 0xFF00) | (uint8_t)(vm->hl + v));
            break;
        }
        case D64_ISO_OP_P2_INC: iso_reg_add(vm, 0x6E, 0x01); break;
        case D64_ISO_OP_P1_INC: iso_reg_add(vm, 0x6D, 0x01); break;
        case D64_ISO_OP_P2_DEC: iso_reg_add(vm, 0x6E, 0xFF); break;
        case D64_ISO_OP_P1_DEC: iso_reg_add(vm, 0x6D, 0xFF); break;
        case D64_ISO_OP_LOOP_P1: iso_op_loop(vm, 0x6D); break;
        case D64_ISO_OP_LOOP_P2: iso_op_loop(vm, 0x6E); break;
        case D64_ISO_OP_PUSH_POS: vm_push(vm, vm->hl); break;
        case D64_ISO_OP_POP_POS: vm->hl = vm_pop(vm); break;
        case D64_ISO_OP_NEXT: iso_op_next(vm); break;
        case D64_ISO_OP_TILES_UP: iso_tile_run(D64_ISO_STEP_UP_INSN, &vm->hl, &vm->ix, &vm->bc); break;
        case D64_ISO_OP_TILES_LEFT: iso_tile_run(D64_ISO_STEP_LEFT_INSN, &vm->hl, &vm->ix, &vm->bc); break;
        case D64_ISO_OP_TILES_RIGHT: iso_tile_run(D64_ISO_STEP_RIGHT_INSN, &vm->hl, &vm->ix, &vm->bc); break;
        case D64_ISO_OP_SET: iso_op_set(vm); break;
        case D64_ISO_OP_MIRROR: iso_op_mirror(); break;
        case D64_ISO_OP_JUMP: vm->ix = iso_fetch_word(&vm->ix); break;
        case D64_ISO_OP_CALL_KEEP:             /* 1DB8: the keep flag, entry 17EE */
            wb(D64_ISO_KEEP_FLAG, 1);
            iso_call_common(vm, D64_ISO_ENTER_BLOCK_KEEP);
            break;
        case D64_ISO_OP_CALL: iso_call_common(vm, D64_ISO_ENTER_BLOCK); break;
        default: return;
        }
        if (vm->ret == 0) continue;
        if (vm->ret == D64_ISO_TAG_CALL_RETURN) {
            iso_call_return(vm);
            continue;
        }
        return;
    }
}

/* 163F iso_build_room (PC 1000:2967): interprets the room entries at IX until a byte FF.  Entry: byte
 * 0 = block type (bits 1-7: the word of the block table 11DDh) | bit 0 (a height byte follows); byte
 * 1 = x | p1 << 5; byte 2 = y | p2 << 5; [byte 3 = height].  For each: the block at 1697 (the operand
 * of LD HL), depth 0,0, height (1BEB) = the byte or FF; HL = y,x, BC = p2,p1; the tag 163F and the
 * script start (block + 2) pushed; iso_enter_block with its tile list (the word at the block); the
 * block's END pops IX = the next entry and RETs to 163F, the next turn of this loop.  In: vm->ix, and
 * hl, bc, de as the Z80 has them.  Out: vm->ix = the FF; hl, bc, de as the Z80 leaves them (A = FF,
 * ZF = 1). */
void iso_build_room(iso_vm *vm)
{
    uint8_t b0, b1, b2, h;
    uint16_t block;
    for (;;) {
        b0 = rb(vm->ix);
        if (b0 == 0xFF) return;
        block = rw(util_add_bx_al(D64_ISO_BLOCK_TABLE, (uint8_t)(b0 & 0xFE)));
        ww(D64_ISO_CUR_BLOCK, block);
        b1 = rb((uint16_t)(vm->ix + 1));
        b2 = rb((uint16_t)(vm->ix + 2));
        vm->hl = (uint16_t)((b2 & 0x1F) << 8 | (b1 & 0x1F));
        vm->bc = (uint16_t)((b2 >> 5) << 8 | (b1 >> 5));
        ww(D64_ISO_DEPTH_X, 0);
        vm->ix = (uint16_t)(vm->ix + 3);
        h = 0xFF;
        if (b0 & 1) {
            h = rb(vm->ix);
            ++vm->ix;
        }
        wb(D64_ISO_BLOCK_HEIGHT, h);
        vm->sp = 0;
        vm_push(vm, D64_ISO_TAG_NEXT_ENTRY);
        block = rw(D64_ISO_CUR_BLOCK);
        vm_push(vm, (uint16_t)(block + 2));
        iso_enter_block(vm, rw(block), h);
        iso_run(vm);
        if (vm->ret != D64_ISO_TAG_NEXT_ENTRY) return;
    }
}

/* 1611 iso_draw_room (PC 1000:2945): builds and shows the current room: the tile buffer cleared and
 * the play area filled with 0 (lit; the PC uses vid_play_fill) or FFh (iso_room_dark 11DC != 0; the
 * PC uses 0); iso_build_room on the record [11DA] + 1 with the cell update of iso_put_tile (12C0 =
 * 12C9h; after it 12C2h); a lit room is then drawn (tail JP 4A5F, iso_draw_room_spiral).  In: vm (the
 * registers).  Out: true when the room was drawn (4A5F ran); else vm->hl, bc, de, ix as the Z80 leaves
 * them (A = [11DC], F of AND A). */
bool iso_draw_room(iso_vm *vm)
{
    uint8_t fill = rb(D64_ISO_ROOM_DARK) ? 0xFF : 0x00;
    iso_clear_tile_buffer(fill, &vm->de);
    vm->ix = (uint16_t)(rw(D64_ISO_ROOM_PTR) + 1);
    vm->hl = D64_ISO_PUT_TILE_UPDATE;
    ww(D64_ISO_PUT_TILE_JUMP, D64_ISO_PUT_TILE_UPDATE);
    vm->bc = 0x7FC7;                         /* the 6128's memory configuration, unused in 64K */
    iso_build_room(vm);
    vm->bc = 0x7FC0;
    vm->hl = D64_ISO_PUT_TILE_MARK;
    ww(D64_ISO_PUT_TILE_JUMP, D64_ISO_PUT_TILE_MARK);
    if (rb(D64_ISO_ROOM_DARK) != 0) return false;
    iso_draw_room_spiral();             /* JP 4A5F: the tile buffer drawn from the centre outwards */
    return true;
}

/* ================================================================================================
 * The camera and the room shown
 * ================================================================================================ */

/* 2097 iso_floor_base (PC 1000:1E97): the base height of the floor that holds height z: 0 below 0Dh,
 * 0Bh below 18h, else 16h.  In: z (A, kept).  Out: B (F of CP 0Dh, or of CP 18h when z >= 0Dh). */
uint8_t iso_floor_base(uint8_t z)
{
    if (z < 0x0D) return 0x00;
    if (z >= 0x18) return 0x16;
    return 0x0B;
}

/* 20A4 iso_orient_relative (PC 1000:1EA8): (o - the camera orientation at 20A5) & 3.  In: o (A).
 * Out: A (F of AND 3). */
uint8_t iso_orient_relative(uint8_t o)
{
    return (uint8_t)((o - rb(D64_ISO_CAMERA_ORIENT)) & 3);
}

/* 20A9 iso_rotate_cam1 (PC 1000:1EAF): camera transform of orientation 1 (through the CALL at 2655 in
 * chr_project): (x, y) = (L, H) -> (28h - y, x); falls into the RET of 20AE.  In: HL.  Out: HL (A = L). */
uint16_t iso_rotate_cam1(uint16_t xy)
{
    uint8_t x = (uint8_t)xy, y = (uint8_t)(xy >> 8);
    return (uint16_t)(x << 8 | (uint8_t)(0x28 - y));
}

/* 20AE iso_rotate_cam0 (PC 1000:1EB7): camera transform of orientation 0: a bare RET.  In/Out: HL. */
uint16_t iso_rotate_cam0(uint16_t xy)
{
    return xy;
}

/* 20AF iso_rotate_cam2 (PC 1000:1EB8): orientation 2: (x, y) -> (28h - x, 28h - y).  Out: HL (A = L). */
uint16_t iso_rotate_cam2(uint16_t xy)
{
    uint8_t x = (uint8_t)xy, y = (uint8_t)(xy >> 8);
    return (uint16_t)((uint8_t)(0x28 - y) << 8 | (uint8_t)(0x28 - x));
}

/* 20B8 iso_rotate_cam3 (PC 1000:1EC5): orientation 3: (x, y) -> (y, 28h - x).  Out: HL (A = H). */
uint16_t iso_rotate_cam3(uint16_t xy)
{
    uint8_t x = (uint8_t)xy, y = (uint8_t)(xy >> 8);
    return (uint16_t)((uint8_t)(0x28 - x) << 8 | y);
}

/* 2082 spr_project_or_hide (PC 1000:1E83): chr_project (2632) of the character; when it is not in
 * view the sprite is marked FE (hidden).  In the Z80 the result is the control flow: chr_project
 * returns to the caller's caller when the character is visible (POP DE at 267D), and this function
 * pops two words when it is not, returning past spr_update_char_sprite's frame; here it is a
 * result.  In: spr (IX), chr (IY).  Out: true when visible, *depth (C) as chr_project leaves it. */
static bool spr_project_or_hide(uint16_t spr, uint16_t chr, uint8_t *depth)
{
    uint16_t screen;
    if (chr_project(chr, spr, depth, &screen)) return true;   /* 2082 CALL 2632 */
    wb(spr, 0xFE);
    return false;
}

/* 208C spr_update_char_sprite (PC 1000:1E8C): chr_select_frame (25B6) of the character, then, when
 * spr_project_or_hide finds it in view, its frame set up by the tail of chr_animate (JP 2589).  In:
 * spr (IX), chr (IY).  Out: memory. */
void spr_update_char_sprite(uint16_t spr, uint16_t chr)
{
    uint16_t frame;
    uint8_t depth;
    frame = chr_select_frame(chr, spr);                      /* 208C CALL 25B6 */
    if (!spr_project_or_hide(spr, chr, &depth)) return;
    chr_show_frame(chr, spr, frame, depth);                  /* JP 2589, chr_animate's tail */
}

/* 1F79 iso_update_camera_room (PC 1000:1D3F): main-loop step.  The record of the character the camera
 * follows ([28D9]): each of x & F0 vs 28C6 (then the origin x 2636 = x - 0Ch), y & F0 vs 28C7 (origin
 * y), the floor base of z vs 28C8 (then the floor 264E and the floor map 2013) that changed is stored
 * and counted; none -> return.  Else 2909 = the count; the room is dark (11DC = 1) on floor 16h with
 * room x >= 20h except the room (20h, 60h); the light sprite 2B20 = FE; the camera orientation 20A5 =
 * ((X ^ Y) & 1) | (X & 1) << 1 for the room coordinates (the nibbles taken by RLD, the bytes written
 * back); iso_select_room(map[(Y << 4) | X]); chr_fill_height_buffer; the sprite offsets 28D5 = 2BF0 +
 * 40h * orientation; the camera transform 2656 = the word 1E81[orientation]; doors and objects
 * placed; then for each chr_table entry (2703, 10 bytes, FF in byte 1 ends): 2070 = sprite, 2074 =
 * record, 25AE = word +6, 25D9 = word +8, spr_update_char_sprite and chr_mark_hbuf(C = [record +
 * 0Eh]).  Out: true when the room changed (A = FF; false: A = 0). */
bool iso_update_camera_room(void)
{
    uint8_t changes = 0, a, x, xbit, index, orient, dark;
    uint16_t rec = rw(D64_CHR_CAMERA_TARGET), e, spr, chr;

    a = (uint8_t)(rb((uint16_t)(rec + 2)) & 0xF0);
    if (a != rb(D64_CHR_ROOM_X)) {
        ++changes;
        wb(D64_CHR_ROOM_X, a);
        wb(D64_CHR_ROOM_ORIGIN_X, (uint8_t)(a - 0x0C));
    }
    a = (uint8_t)(rb((uint16_t)(rec + 3)) & 0xF0);
    if (a != rb(D64_CHR_ROOM_Y)) {
        wb(D64_CHR_ROOM_Y, a);
        ++changes;
        wb(D64_CHR_ROOM_ORIGIN_Y, (uint8_t)(a - 0x0C));
    }
    a = iso_floor_base(rb((uint16_t)(rec + 4)));
    if (a != rb(D64_CHR_ROOM_Z)) {
        wb(D64_CHR_ROOM_FLOOR, a);
        wb(D64_CHR_ROOM_Z, a);
        ++changes;
        ww(D64_ISO_FLOOR_MAP_PTR, a == 0 ? D64_ISO_FLOOR0_MAP : a == 0x0B ? D64_ISO_FLOOR1_MAP : D64_ISO_FLOOR2_MAP);
    }
    if (changes == 0) return false;

    wb(D64_ISO_ROOM_CHANGED, changes);
    if (rb(D64_CHR_ROOM_Z) != D64_ISO_DARK_FLOOR) dark = 0;
    else if (rb(D64_CHR_ROOM_X) < 0x20) dark = 0;
    else if (rb(D64_CHR_ROOM_X) != 0x20) dark = 1;
    else dark = rb(D64_CHR_ROOM_Y) != 0x60 ? 1 : 0;
    wb(D64_ISO_ROOM_DARK, dark);
    wb(D64_SPR_LIGHT, 0xFE);

    x = (uint8_t)(rb(D64_CHR_ROOM_X) >> 4);              /* RLD with A = FEh, the byte written back */
    xbit = (uint8_t)(x & 1);
    index = (uint8_t)(rb(D64_CHR_ROOM_Y) | x);           /* (Y << 4) | X */
    orient = (uint8_t)((((rb(D64_CHR_ROOM_Y) >> 4) & 1) ^ xbit) | (uint8_t)(xbit << 1));
    wb(D64_ISO_CAMERA_ORIENT, orient);
    iso_select_room(rb((uint16_t)(rw(D64_ISO_FLOOR_MAP_PTR) + index)));   /* 2017 */
    chr_fill_height_buffer(rec);                         /* 201A */

    a = rb(D64_ISO_CAMERA_ORIENT);
    a = (uint8_t)(a >> 2 | a << 6);                      /* RRCA twice */
    ww(D64_CHR_SPRITE_OFFSETS, util_add_bx_al(D64_CHR_SPRITE_OFFSET_TABLES, a));
    ww(D64_CHR_CAMERA_TRANSFORM, rw(util_add_bx_al(D64_ISO_CAMERA_ROTATIONS, (uint8_t)(rb(D64_ISO_CAMERA_ORIENT) * 2))));
    obj_place_doors_in_room();                           /* 203E */
    obj_place_objects_in_room();                         /* 2041 */

    for (e = D64_CHR_TABLE;; e = (uint16_t)(e + 10)) {
        if (rb((uint16_t)(e + 1)) == 0xFF) return true;
        ww(D64_ISO_SETUP_SPRITE, rw(e));
        ww(D64_ISO_SETUP_RECORD, rw((uint16_t)(e + 2)));
        ww(D64_CHR_CUR_FLIP, rw((uint16_t)(e + 6)));
        ww(D64_CHR_CUR_ANIM, rw((uint16_t)(e + 8)));
        spr = rw(D64_ISO_SETUP_SPRITE);
        chr = rw(D64_ISO_SETUP_RECORD);
        spr_update_char_sprite(spr, chr);                /* 2076 */
        (void)chr_mark_hbuf(chr, rb((uint16_t)(chr + 0x0E)), spr);   /* 207C */
    }
}

/* 1E6E vid_set_crtc (f_1E6E): programs the CRTC with the (register, value) pairs that follow the CALL,
 * up to a byte FFh, and returns past it (POP HL / PUSH HL keep the pointer in the return slot).  Used
 * at the game's start (20C8: R1 = 20h, R2 = 2Bh, R6 = 18h, the 256-pixel screen of 64-byte lines)
 * and at 1E63 (R1 = 28h, R2 = 2Eh, R6 = 19h, the standard screen).  In: data = the return address.
 * Out: the address after the FFh (HL, the return address); B = BCh, C = 0. */
uint16_t vid_set_crtc(uint16_t data)
{
    uint8_t r;
    for (;;) {
        r = rb(data);
        ++data;
        if (r == 0xFF) return data;
        plat_crtc(r, rb(data));
        ++data;
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
/* ================================================================================================
 * The wrappers and checks of the hybrid host
 * ================================================================================================ */

static uint8_t paridad(uint8_t v)
{
    v ^= (uint8_t)(v >> 4);
    v ^= (uint8_t)(v >> 2);
    v ^= (uint8_t)(v >> 1);
    return (uint8_t)(!(v & 1));
}

/* F of SUB a,b (cp: CP, whose X/Y flags come from the operand) */
static void flags_resta(uint8_t a, uint8_t b, int cp)
{
    uint8_t r = (uint8_t)(a - b), xy = cp ? b : r;
    cpu.sf = r >> 7; cpu.zf = r == 0; cpu.yf = (xy >> 5) & 1; cpu.xf = (xy >> 3) & 1;
    cpu.hf = (a & 0x0F) < (b & 0x0F);
    cpu.pf = ((a ^ b) & (a ^ r) & 0x80) != 0;
    cpu.nf = 1; cpu.cf = a < b;
}

/* F of AND/OR/XOR (and: H = 1) */
static void flags_logica(uint8_t r, int and)
{
    cpu.sf = r >> 7; cpu.zf = r == 0; cpu.yf = (r >> 5) & 1; cpu.xf = (r >> 3) & 1;
    cpu.hf = and != 0; cpu.pf = paridad(r); cpu.nf = 0; cpu.cf = 0;
}

static uint8_t registro_f(const z80 *z)
{
    return (uint8_t)(z->sf << 7 | z->zf << 6 | z->yf << 5 | z->hf << 4 | z->xf << 3 | z->pf << 2 | z->nf << 1 | z->cf);
}

static int igual8(const char *nombre, uint8_t c, uint8_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %02X Z80 %02X", nombre, c, z);
    return 0;
}

static int igual16(const char *nombre, uint16_t c, uint16_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %04X Z80 %04X", nombre, c, z);
    return 0;
}

#define R_A(n_)   igual8("A", cz->a, zz->a, msg, n_)
#define R_B(n_)   igual8("B", cz->b, zz->b, msg, n_)
#define R_C(n_)   igual8("C", cz->c, zz->c, msg, n_)
#define R_F(n_)   igual8("F", registro_f(cz), registro_f(zz), msg, n_)
#define R_ZF(n_)  igual8("ZF", cz->zf, zz->zf, msg, n_)
#define R_HL(n_)  igual16("HL", (uint16_t)(cz->h << 8 | cz->l), (uint16_t)(zz->h << 8 | zz->l), msg, n_)
#define R_DE(n_)  igual16("DE", (uint16_t)(cz->d << 8 | cz->e), (uint16_t)(zz->d << 8 | zz->e), msg, n_)
#define R_BC(n_)  igual16("BC", (uint16_t)(cz->b << 8 | cz->c), (uint16_t)(zz->b << 8 | zz->c), msg, n_)
#define R_IX(n_)  igual16("IX", cz->ix, zz->ix, msg, n_)
#define R_IY(n_)  igual16("IY", cz->iy, zz->iy, msg, n_)

/* 128F: HL, A = H, F of SUB (the high byte by ADD A,L / ADC A,H / SUB L) */
static void w_128F(void)
{
    uint8_t a1 = (uint8_t)(cpu.a + cpu.l), c1 = (uint8_t)(cpu.a + cpu.l > 0xFF);
    uint8_t a2 = (uint8_t)(a1 + cpu.h + c1);
    uint16_t hl = util_add_bx_al(HL, cpu.a);
    flags_resta(a2, a1, 0);
    SET_HL(hl);
    cpu.a = cpu.h;
    z80_ret();
}
static int r_128F(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_HL(n); ok &= R_A(n); ok &= R_F(n); return ok; }

/* 1295: A, DE; HL and BC kept */
static void w_1295(void)
{
    uint16_t de = DE;
    cpu.a = iso_put_tile(HL, cpu.c, &de);
    SET_DE(de);
    z80_ret();
}
static int r_1295(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_A(n); ok &= R_DE(n); ok &= R_HL(n); ok &= R_BC(n); return ok; }

/* 1D26: HL stepped, A, DE */
static void w_1D26(void)
{
    uint16_t de = DE;
    uint8_t a;
    uint16_t hl = iso_put_tile_step(HL, cpu.c, &a, &de);
    SET_HL(hl); SET_DE(de); cpu.a = a;
    z80_ret();
}
static int r_1D26(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_A(n); ok &= R_DE(n); ok &= R_HL(n); ok &= R_BC(n); return ok; }

/* 1D48: HL, A = 0, ZF */
static void w_1D48(void)
{
    uint16_t de = DE;
    uint16_t hl = iso_put_tile_times(HL, cpu.c, &de);
    SET_HL(hl); SET_DE(de); cpu.a = 0; cpu.zf = 1;
    z80_ret();
}
static int r_1D48(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_A(n); ok &= R_HL(n); ok &= R_BC(n); ok &= R_ZF(n); return ok; }
#endif

/* 16B2 / 16A5 / 16A1: HL (A = H and F are left by the last f_3558 run through the core, as in the
 * Z80, which ends with POP BC / DJNZ / RET), DE, B = 0 */
#ifndef JUEGO_PURO  /* the hybrid host */
/* the A and F that 3558 (vid_next_line) leaves for the line p: A = the new H; F of ADD A,8 (no carry)
 * or of OR C0h */
static void regs_3558(uint16_t p)
{
    uint8_t h = (uint8_t)(p >> 8), r = (uint8_t)(h + 8);
    cpu.a = (uint8_t)(vid_next_line(p) >> 8);
    if (h < 0xF8) {
        cpu.sf = r >> 7; cpu.zf = r == 0; cpu.yf = (r >> 5) & 1; cpu.xf = (r >> 3) & 1;
        cpu.hf = (h & 0x0F) + 8 > 0x0F; cpu.pf = (~(h ^ 8) & (h ^ r) & 0x80) != 0; cpu.nf = 0; cpu.cf = 0;
    } else {
        flags_logica(cpu.a, 0);
    }
}

/* the A and F of the last 3558 of a play-area fill (160 lines from C000h) */
static void regs_fill(void)
{
    uint16_t p = D64_VID_SCREEN, last = p;
    unsigned k;
    for (k = 0; k < 0xA0; ++k) { last = p; p = vid_next_line(p); }
    regs_3558(last);
}

static void w_16B2(void)
{
    uint16_t de = DE;
    uint16_t hl = vid_fill_play_area(cpu.a, &de);
    SET_HL(hl); SET_DE(de); cpu.b = 0;
    regs_fill();
    z80_ret();
}
static void w_16A5(void)
{
    uint16_t de = DE;
    uint16_t hl = iso_clear_tile_buffer(cpu.a, &de);
    SET_HL(hl); SET_DE(de); SET_BC(0);
    regs_fill();
    z80_ret();
}
static void w_16A1(void)
{
    uint16_t de = DE;
    uint16_t hl = vid_fill_play_area_ff(&de);
    SET_HL(hl); SET_DE(de); cpu.b = 0;
    regs_fill();
    z80_ret();
}
static int r_16B2(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_HL(n); ok &= R_DE(n); ok &= R_BC(n); ok &= R_A(n); ok &= R_F(n); return ok; }

/* 1BC6: A, DE (unchanged for FF), F */
static void w_1BC6(void)
{
    uint8_t height = cpu.a, x = cpu.l, y = cpu.h, t;
    iso_block_depth(HL, height);
    if (height == 0xFF) {
        flags_resta(0xFF, 0xFF, 1);
    } else {
        t = (uint8_t)((height >> 1) + y);
        flags_resta((uint8_t)(0x10 + t), x, 0);
        cpu.a = rb(D64_ISO_DEPTH_Y);
        SET_DE(rw(D64_ISO_DEPTH_X));      /* D = depth y, E = depth x */
    }
    z80_ret();
}
static int r_1BC6(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_A(n); ok &= R_DE(n); ok &= R_F(n); return ok; }

/* 1D0A: the step byte after the CALL; returns past it (the slot rewritten by PUSH DE); HL, IX, BC, A */
static void w_1D0A(void)
{
    uint16_t ret = rw(cpu.sp), hl = HL, ix = cpu.ix, bc = BC;
    uint8_t a = iso_tile_run(ret, &hl, &ix, &bc);
    ww(cpu.sp, (uint16_t)(ret + 1));
    SET_HL(hl); cpu.ix = ix; SET_BC(bc); cpu.a = a;
    z80_ret();
}
static int r_1D0A(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_HL(n); ok &= R_IX(n); ok &= R_BC(n); ok &= R_A(n); return ok; }

/* 1D74: C, IX, A = [IX], F of CP C8h; B kept */
static void w_1D74(void)
{
    uint16_t ix = cpu.ix;
    cpu.c = iso_expression(cpu.c, &ix);
    cpu.ix = ix;
    cpu.a = rb(ix);
    flags_resta(cpu.a, 0xC8, 1);
    z80_ret();
}
static int r_1D74(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_BC(n); ok &= R_IX(n); ok &= R_A(n); ok &= R_F(n); return ok; }

/* 1D90: DE, IX */
static void w_1D90(void)
{
    uint16_t ix = cpu.ix, de = iso_fetch_word(&ix);
    SET_DE(de); cpu.ix = ix;
    z80_ret();
}
static int r_1D90(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_DE(n); ok &= R_IX(n); return ok; }

/* 1E22 / 1E27: A = C = the value, DE, IX, F of AND A */
static void w_1E22(void)
{
    uint16_t ix = cpu.ix, reg;
    uint8_t v = iso_fetch_operand(&ix, &reg);
    cpu.a = cpu.c = v; SET_DE(reg); cpu.ix = ix;
    flags_logica(v, 1);
    z80_ret();
}
static void w_1E27(void)
{
    uint16_t ix = cpu.ix, reg;
    uint8_t v = iso_operand_value(cpu.a, &ix, &reg);
    cpu.a = cpu.c = v; SET_DE(reg); cpu.ix = ix;
    flags_logica(v, 1);
    z80_ret();
}
static int r_1E22(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_A(n); ok &= R_BC(n); ok &= R_DE(n); ok &= R_IX(n); ok &= R_F(n); return ok; }

/* 163F: IX = the FF, HL, BC, DE as the interpreter leaves them, A = FF, F of CP FFh */
static void w_163F(void)
{
    static iso_vm vm;
    vm.hl = HL; vm.bc = BC; vm.de = DE; vm.ix = cpu.ix;
    iso_build_room(&vm);
    SET_HL(vm.hl); SET_BC(vm.bc); SET_DE(vm.de); cpu.ix = vm.ix;
    cpu.a = 0xFF;
    flags_resta(0xFF, 0xFF, 1);
    z80_ret();
}
static int r_163F(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = R_IX(n); ok &= R_HL(n); ok &= R_BC(n); ok &= R_DE(n); ok &= R_A(n); ok &= R_F(n);
    return ok;
}

/* 1611: lit, the registers of 4A5F (already in cpu); dark: A = [11DC], F of AND A, HL, BC, DE, IX */
static void w_1611(void)
{
    static iso_vm vm;
    vm.hl = HL; vm.bc = BC; vm.de = DE; vm.ix = cpu.ix;
    if (!iso_draw_room(&vm)) {
        SET_HL(vm.hl); SET_BC(vm.bc); SET_DE(vm.de); cpu.ix = vm.ix;
        cpu.a = rb(D64_ISO_ROOM_DARK);
        flags_logica(cpu.a, 1);
    }
    z80_ret();
}
/* a dark room: the registers iso_draw_room leaves; a lit one ends in 4A5F, whose registers (its loop
 * counters and pointers, the shadow bank of 4AC8's EXX) are not reproduced: the only caller, the main
 * loop at 21AF, reads none after it (LD A,80h follows) */
static int r_1611(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = 1;
    if (rb(D64_ISO_ROOM_DARK) == 0) return ok;
    ok &= R_IX(n); ok &= R_IY(n); ok &= R_HL(n); ok &= R_BC(n); ok &= R_DE(n); ok &= R_A(n); ok &= R_F(n);
    return ok;
}

/* 1E6E: returns past its data (written to the return slot by PUSH HL); HL, B = BCh, C = 0, F of INC C
 * (FFh -> 0; CF kept) */
static void w_1E6E(void)
{
    uint16_t p = vid_set_crtc(rw(cpu.sp));
    ww(cpu.sp, p);
    SET_HL(p); cpu.b = 0xBC; cpu.c = 0;
    cpu.sf = 0; cpu.zf = 1; cpu.yf = 0; cpu.hf = 1; cpu.xf = 0; cpu.pf = 0; cpu.nf = 0;
    z80_ret();
}
static int r_1E6E(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_HL(n); ok &= R_BC(n); ok &= R_F(n); return ok; }

/* 1F79: IY = the camera's record; nothing changed: A = 0, F of AND A, HL = 28C8; else A = FF, F of
 * CP FFh, HL = the byte FF that ends chr_table (IX, IY and the rest as the core calls left them, as
 * in the Z80) */
static void w_1F79(void)
{
    uint16_t e;
    cpu.iy = rw(D64_CHR_CAMERA_TARGET);
    if (!iso_update_camera_room()) {
        cpu.a = 0;
        flags_logica(0, 1);
        SET_HL(D64_CHR_ROOM_Z);
    } else {
        uint16_t last = D64_CHR_TABLE, cell;
        for (e = D64_CHR_TABLE; rb((uint16_t)(e + 1)) != 0xFF; e = (uint16_t)(e + 10)) last = e;
        cpu.a = 0xFF;
        flags_resta(0xFF, 0xFF, 1);
        SET_HL((uint16_t)(e + 1));
        /* IY = the last record, IX = what its chr_mark_hbuf left: its cell, or the sprite off the buffer */
        cpu.iy = rw((uint16_t)(last + 2));
        cpu.ix = iso_grid_cell_of(cpu.iy, &cell) ? rw(last) : cell;
    }
    z80_ret();
}
static int r_1F79(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = R_A(n); ok &= R_F(n); ok &= R_HL(n); ok &= R_IX(n); ok &= R_IY(n);
    return ok;
}

/* 208C: memory; IX, IY (as the core calls leave them) */
static void w_208C(void)
{
    spr_update_char_sprite(cpu.ix, cpu.iy);
    z80_ret();
}
static int r_208C(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_IX(n); ok &= R_IY(n); return ok; }

/* 2097: B, F of the last CP; A kept */
static void w_2097(void)
{
    uint8_t z = cpu.a;
    cpu.b = iso_floor_base(z);
    flags_resta(z, z < 0x0D ? 0x0D : 0x18, 1);
    z80_ret();
}
static int r_2097(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_B(n); ok &= R_A(n); ok &= R_F(n); return ok; }

/* 20A4: A, F of AND 3 */
static void w_20A4(void)
{
    cpu.a = iso_orient_relative(cpu.a);
    flags_logica(cpu.a, 1);
    z80_ret();
}
static int r_20A4(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_A(n); ok &= R_F(n); return ok; }

/* 20A9 / 20AF / 20B8: HL, A, F of the last SUB; 20AE: nothing */
static void w_20A9(void)
{
    uint8_t h = cpu.h;
    uint16_t hl = iso_rotate_cam1(HL);
    flags_resta(0x28, h, 0);
    SET_HL(hl); cpu.a = cpu.l;
    z80_ret();
}
static void w_20AE(void)
{
    SET_HL(iso_rotate_cam0(HL));
    z80_ret();
}
static void w_20AF(void)
{
    uint8_t l = cpu.l;
    uint16_t hl = iso_rotate_cam2(HL);
    flags_resta(0x28, l, 0);
    SET_HL(hl); cpu.a = cpu.l;
    z80_ret();
}
static void w_20B8(void)
{
    uint8_t l = cpu.l;
    uint16_t hl = iso_rotate_cam3(HL);
    flags_resta(0x28, l, 0);
    SET_HL(hl); cpu.a = cpu.h;
    z80_ret();
}
static int r_20A9(const z80 *cz, const z80 *zz, char *msg, size_t n) { int ok = R_HL(n); ok &= R_A(n); ok &= R_F(n); return ok; }

const traducida_t traducidas_motor_iso[] = {
    { 0x128F, "util_add_bx_al", w_128F, r_128F },
    { 0x1295, "iso_put_tile", w_1295, r_1295 },
    { 0x1611, "iso_draw_room", w_1611, r_1611 },
    { 0x163F, "iso_build_room", w_163F, r_163F },
    { 0x16A1, "vid_fill_play_area_ff", w_16A1, r_16B2 },
    { 0x16A5, "iso_clear_tile_buffer", w_16A5, r_16B2 },
    { 0x16B2, "vid_fill_play_area", w_16B2, r_16B2 },
    { 0x1BC6, "iso_block_depth", w_1BC6, r_1BC6 },
    { 0x1D0A, "iso_tile_run", w_1D0A, r_1D0A },
    { 0x1D26, "iso_put_tile_step", w_1D26, r_1D26 },
    { 0x1D48, "iso_put_tile_times", w_1D48, r_1D48 },
    { 0x1D74, "iso_expression", w_1D74, r_1D74 },
    { 0x1D90, "iso_fetch_word", w_1D90, r_1D90 },
    { 0x1E22, "iso_fetch_operand", w_1E22, r_1E22 },
    { 0x1E27, "iso_operand_value", w_1E27, r_1E22 },
    { 0x1E6E, "vid_set_crtc", w_1E6E, r_1E6E },
    { 0x1F79, "iso_update_camera_room", w_1F79, r_1F79 },
    { 0x208C, "spr_update_char_sprite", w_208C, r_208C },
    { 0x2097, "iso_floor_base", w_2097, r_2097 },
    { 0x20A4, "iso_orient_relative", w_20A4, r_20A4 },
    { 0x20A9, "iso_rotate_cam1", w_20A9, r_20A9 },
    { 0x20AE, "iso_rotate_cam0", w_20AE, resultado_hl },
    { 0x20AF, "iso_rotate_cam2", w_20AF, r_20A9 },
    { 0x20B8, "iso_rotate_cam3", w_20B8, r_20A9 },
    { 0, NULL, NULL, NULL }
};
#endif

