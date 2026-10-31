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

/* abadia64ks: the group objetos_sonido (64K 0983-128E) translated to C: the doors and objects of the
 * room shown (their sprites, the door leaves in the height buffer, opening and closing), the
 * projection of a door or object onto the screen, the AY sound sequencer run by the interrupt, its
 * triggers and the AY register write.  Each function cites its 64K address, the PC rebuild's
 * function it corresponds to (c/src/obj.c, spr.c, snd.c) and the CPC 6128 address; the 64K code is
 * the reference.  The sound differs from the PC's (a one-voice speaker sequencer whose CPC calls are
 * stubs): the names here say what the CPC code does. */
#include <stdio.h>
#include <string.h>
#include "juego64.h"
#include "datos_objetos_sonido.h"

#ifndef JUEGO_PURO  /* the hybrid host */
/* ---- result checks ---- */

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

/* the flags byte of a core state (as PUSH AF / EX AF,AF' pack it) */
static uint8_t flags_de(const z80 *z)
{
    return (uint8_t)(z->cf | z->nf << 1 | z->pf << 2 | z->xf << 3 | z->hf << 4 | z->yf << 5 | z->zf << 6 | z->sf << 7);
}
#endif

/* ================================================================================================
 * Doors and objects
 * ================================================================================================ */

/* 0BEC util_read_indirect_pair (PC 1000:1486, CPC 6128 0F7C): q = the word at *p (a pointer to a
 * character's x, y), *p += 2; returns [q] (x) and *second = [q+1] (y).  In: HL = *p.  Out: A, B, HL. */
uint8_t util_read_indirect_pair(uint16_t *p, uint8_t *second)
{
    uint16_t q = rw(*p);
    *p = (uint16_t)(*p + 2);
    *second = rb((uint16_t)(q + 1));
    return rb(q);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0BEC(void)
{
    uint16_t p = HL;
    uint8_t b;
    cpu.a = util_read_indirect_pair(&p, &b);
    cpu.b = b;
    SET_HL(p);
    z80_ret();
}

static int r_0BEC(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp8("A", cz->a, zz->a, msg, n);
    ok &= cmp8("B", cz->b, zz->b, msg, n);
    ok &= cmp16("HL", R_HL(cz), R_HL(zz), msg, n);
    return ok;
}
#endif

/* 0BDC obj_door_unpermitted_near (PC 1000:146D, CPC 6128 0F6C): (mask | [entry]) & bit -> false (one of
 * the two may pass); else (x, y) = the position the entry points to: true when x - x0 < 6 and
 * y - y0 < 6 (8 bit, unsigned).  In: A = mask, HL = entry, C = bit, E = x0, D = y0.  Out: CF. */
bool obj_door_unpermitted_near(uint8_t mask, uint16_t entry, uint8_t bit, uint8_t x0, uint8_t y0)
{
    uint16_t p = (uint16_t)(entry + 1);
    uint8_t x, y;
    if ((mask | rb(entry)) & bit) return false;
    x = util_read_indirect_pair(&p, &y);
    if ((uint8_t)(x - x0) >= 6) return false;
    return (uint8_t)(y - y0) < 6;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0BDC(void)
{
    cpu.cf = obj_door_unpermitted_near(cpu.a, HL, cpu.c, cpu.e, cpu.d);
    z80_ret();
}

static int r_0BDC(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    return cmp8("CF", cz->cf, zz->cf, msg, n);
}
#endif

/* 0A9C obj_door_cells (PC 1000:12F5, CPC 6128 0E2C): *step = the word D64_OBJ_DOOR_CELL_STEPS[[door] & 3]
 * (+1, -24, -1, +24); then iso_grid_cell_of(door): true (CF) when the door is not in the current height
 * buffer, *cell unchanged; else *cell = the first cell of its leaf.  The original keeps its caller's A
 * in A' (EX AF,AF' at its entry: obj_door_mark_cells takes it back): a C parameter there.
 * In: IY = door, IX = *cell.  Out: CF, IX = *cell, BC = *step, AF' = AF at the entry. */
bool obj_door_cells(uint16_t door, uint16_t *cell, uint16_t *step)
{
    uint16_t p = util_add_bx_al(D64_OBJ_DOOR_CELL_STEPS, (uint8_t)((rb(door) & 3) * 2));
    *step = rw(p);
    return iso_grid_cell_of(door, cell);    /* 0AAE */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0A9C(void)
{
    uint8_t a0 = cpu.a, f0 = flags_de(&cpu);
    uint16_t cell = cpu.ix, step;
    bool fuera = obj_door_cells(cpu.iy, &cell, &step);
    cpu.a_ = a0; cpu.f_ = f0;
    cpu.ix = cell;
    SET_BC(step);
    cpu.cf = fuera;
    z80_ret();
}

static int r_0A9C(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp8("CF", cz->cf, zz->cf, msg, n);
    ok &= cmp16("IX", cz->ix, zz->ix, msg, n);
    ok &= cmp16("BC", R_BC(cz), R_BC(zz), msg, n);
    ok &= cmp8("A'", cz->a_, zz->a_, msg, n);
    ok &= cmp8("F'", cz->f_, zz->f_, msg, n);
    return ok;
}
#endif

/* 0A89 obj_door_mark_cells (PC 1000:12DE, CPC 6128 0E19): when door lies in the current height buffer
 * (obj_door_cells), value goes into the three cells of its leaf: cell, cell + step, cell + 2 step.
 * Returns true (CF) when the door is not in the buffer.  In: A = value, IY = door, IX = *cell (kept
 * when outside).  Out: CF, IX = *cell (the third cell when marked), A = value when marked. */
bool obj_door_mark_cells(uint16_t door, uint8_t value, uint16_t *cell)
{
    uint16_t step;
    if (obj_door_cells(door, cell, &step)) return true;
    wb(*cell, value);
    *cell = (uint16_t)(*cell + step);
    wb(*cell, value);
    *cell = (uint16_t)(*cell + step);
    wb(*cell, value);
    return false;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0A89(void)
{
    uint8_t value = cpu.a, f0 = flags_de(&cpu);
    uint16_t cell = cpu.ix;
    bool fuera = obj_door_mark_cells(cpu.iy, value, &cell);
    if (fuera) {                        /* RET C: A' = the value, AF from obj_door_cells */
        cpu.a_ = value; cpu.f_ = f0;
    } else {                            /* EX AF,AF': A = the value, A' = obj_door_cells' A */
        cpu.a_ = cpu.a; cpu.f_ = flags_de(&cpu);
        cpu.a = value;
    }
    cpu.ix = cell;
    z80_ret();
}

/* IX; A when the leaf was marked (= the value).  What 092E leaves in A (A' when marked, A when not) is
 * read by no caller (08CC, 0B86, 0BCA, 0A42, all in C) and is not compared. */
static int r_0A89(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp16("IX", cz->ix, zz->ix, msg, n);
    if (!zz->cf) ok &= cmp8("A", cz->a, zz->a, msg, n);
    return ok;
}
#endif

/* 0AFC obj_door_adjust_grid_pos (PC 1000:1361, CPC 6128 0E8C): [spr+12h] += [p+1], [spr+13h] += [p+2]
 * (the rotated grid position of a door sprite).  In: HL = p, IX = spr.  Out: HL = p + 2, A = [spr+13h]. */
void obj_door_adjust_grid_pos(uint16_t p, uint16_t spr)
{
    wb((uint16_t)(spr + 0x12), (uint8_t)(rb((uint16_t)(spr + 0x12)) + rb((uint16_t)(p + 1))));
    wb((uint16_t)(spr + 0x13), (uint8_t)(rb((uint16_t)(spr + 0x13)) + rb((uint16_t)(p + 2))));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0AFC(void)
{
    uint16_t p = HL;
    obj_door_adjust_grid_pos(p, cpu.ix);
    SET_HL((uint16_t)(p + 2));
    cpu.a = rb((uint16_t)(cpu.ix + 0x13));
    z80_ret();
}

static int r_0AFC(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= cmp8("A", cz->a, zz->a, msg, n);
    return ok;
}
#endif

/* 0AEC obj_door_camera_adjust (PC 1000:134D, CPC 6128 0E7C): entry e = D64_OBJ_DOOR_CAMERA_OFFSETS +
 * 4 iso_orient_relative(3); returns the screen offsets C = [e], B = [e+1] and falls into
 * obj_door_adjust_grid_pos(e + 1, spr).  In: IX = spr.  Out: BC. */
uint16_t obj_door_camera_adjust(uint16_t spr)
{
    uint16_t e = util_add_bx_al(D64_OBJ_DOOR_CAMERA_OFFSETS, (uint8_t)(iso_orient_relative(3) * 4));
    uint16_t c = rw(e);
    obj_door_adjust_grid_pos((uint16_t)(e + 1), spr);
    return c;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0AEC(void)
{
    SET_BC(obj_door_camera_adjust(cpu.ix));
    z80_ret();
}

static int r_0AEC(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    return cmp16("BC", R_BC(cz), R_BC(zz), msg, n);
}
#endif

/* 0A2B obj_object_sprite_update (PC 1000:126E, CPC 6128 0DBB): the callback of obj_for_each_visible for
 * a visible object: a carried object (bit 7 of [rec]) is left alone; else [spr] = depth | 80h (redraw),
 * [spr+2] = screen line - 8, [spr+1] = screen byte - 2.  In: IY = rec, IX = spr, HL = screen (H line,
 * L byte), C = depth.  Out: - */
void obj_object_sprite_update(uint16_t rec, uint16_t spr, uint16_t screen, uint8_t depth)
{
    if (rb(rec) & 0x80) return;
    wb(spr, (uint8_t)(depth | 0x80));
    wb((uint16_t)(spr + 2), (uint8_t)((screen >> 8) - 8));
    wb((uint16_t)(spr + 1), (uint8_t)((uint8_t)screen - 2));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0A2B(void)
{
    obj_object_sprite_update(cpu.iy, cpu.ix, HL, cpu.c);
    z80_ret();
}
#endif

/* 0A42 obj_door_sprite_update (PC 1000:1288, CPC 6128 0DD2): the callback for a visible door (through
 * obj_for_each_visible and from obj_update_doors).  spr_save_old_rect; (c, c') = obj_door_camera_adjust
 * (which also adds to the rotated position [spr+12h,13h]); entry e = D64_OBJ_DOOR_ORIENT_TABLE +
 * 8 iso_orient_relative([rec] & 3): [spr+1] = e0 + byte + c, [spr+2] = e1 + line + c', [spr] =
 * (e2 + depth) | [D64_OBJ_ROOM_REDRAW] | [D64_OBJ_DOOR_MOVED], [D64_OBJ_DOOR_FLIP_WANTED] |= e3,
 * obj_door_adjust_grid_pos(e + 3) adds e4, e5 to [spr+12h,13h], the graphic [spr+7,8] = AA49h; falls
 * into obj_door_mark_cells(rec, 0Fh): the leaf is impassable.  In: IY = rec, IX = spr, HL = screen,
 * C = depth.  Out: - (IX is the leaf's cell: its callers keep IX). */
void obj_door_sprite_update(uint16_t rec, uint16_t spr, uint16_t screen, uint8_t depth)
{
    uint16_t c, e, cell = spr;
    (void)spr_save_old_rect(spr);
    c = obj_door_camera_adjust(spr);
    e = util_add_bx_al(D64_OBJ_DOOR_ORIENT_TABLE, (uint8_t)(iso_orient_relative((uint8_t)(rb(rec) & 3)) * 8));
    wb((uint16_t)(spr + 1), (uint8_t)(rb(e) + (uint8_t)screen + (uint8_t)c));
    wb((uint16_t)(spr + 2), (uint8_t)(rb((uint16_t)(e + 1)) + (uint8_t)(screen >> 8) + (uint8_t)(c >> 8)));
    wb(spr, (uint8_t)((uint8_t)(rb((uint16_t)(e + 2)) + depth) | rb(D64_OBJ_ROOM_REDRAW) | rb(D64_OBJ_DOOR_MOVED)));
    wb(D64_OBJ_DOOR_FLIP_WANTED, (uint8_t)(rb(D64_OBJ_DOOR_FLIP_WANTED) | rb((uint16_t)(e + 3))));
    obj_door_adjust_grid_pos((uint16_t)(e + 3), spr);
    ww((uint16_t)(spr + 7), D64_OBJ_DOOR_GFX);
    obj_door_mark_cells(rec, 0x0F, &cell);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0A42(void)
{
    obj_door_sprite_update(cpu.iy, cpu.ix, HL, cpu.c);
    z80_ret();
}
#endif

/* 0ACA spr_project_entity_inner (PC 1000:1326, CPC 6128 0E5A): chr_project in test mode; not visible:
 * [spr] = FEh.  Part of spr_project_entity, never checked alone: it does not return to its caller (not
 * visible it drops its return address, POP DE, and returns to its caller's caller; visible chr_project
 * returns for it).  True when visible: *screen, *depth. */
static bool spr_project_entity_inner(uint16_t rec, uint16_t spr, uint16_t *screen, uint8_t *depth)
{
    if (chr_project(rec, spr, depth, screen)) return true;   /* test mode: HL = screen, A = depth */
    wb(spr, 0xFE);
    return false;
}

/* 0ABC spr_project_entity (PC 1000:1314, CPC 6128 0E4C): the screen position of door or object rec with
 * the character projection cut short ([D64_CHR_PROJECT_TEST] = C9h, RET, during it): returns false when
 * visible, with *screen (low byte the screen byte, high byte the line), *depth = max(0, x + y - 10h) of
 * the rotated position, [spr+12h,13h] = the rotated grid position; true (CF) when not visible, with
 * [spr] = FEh.  In: IY = rec, IX = spr.  Out: CF, A = 0, ZF = 1; visible HL = *screen, C = *depth. */
bool spr_project_entity(uint16_t rec, uint16_t spr, uint16_t *screen, uint8_t *depth)
{
    bool visible;
    wb(D64_CHR_PROJECT_TEST, 0xC9);
    visible = spr_project_entity_inner(rec, spr, screen, depth);
    wb(D64_CHR_PROJECT_TEST, 0x00);
    return !visible;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0ABC(void)
{
    uint16_t screen;
    uint8_t depth;
    bool oculto = spr_project_entity(cpu.iy, cpu.ix, &screen, &depth);
    if (!oculto) { SET_HL(screen); cpu.c = depth; }
    cpu.a = 0; cpu.zf = 1; cpu.cf = oculto;
    z80_ret();
}

static int r_0ABC(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp8("CF", cz->cf, zz->cf, msg, n);
    ok &= cmp8("A", cz->a, zz->a, msg, n);
    ok &= cmp8("ZF", cz->zf, zz->zf, msg, n);
    if (!zz->cf) {
        ok &= cmp16("HL", R_HL(cz), R_HL(zz), msg, n);
        ok &= cmp8("C", cz->c, zz->c, msg, n);
    }
    return ok;
}
#endif

/* 09AB obj_for_each_visible (PC 1000:11E8, CPC 6128 0D3B): [D64_OBJ_ENTITY_CALLBACK] = cb (the operand of
 * a CALL); for each 5-byte record from rec until FFh: spr_project_entity; visible -> the callback (rec,
 * spr, screen, depth); the sprite's old position = its new one ([spr+3,4] = [spr+1,2]); rec += 5,
 * spr += 14h; then [D64_OBJ_FOR_EACH_PATCH]: NOP goes on, RET (obj_redraw_one_object) returns.
 * In: HL = cb, IX = spr, IY = rec.  Out: - */
void obj_for_each_visible(uint16_t cb, uint16_t spr, uint16_t rec)
{
    uint16_t screen;
    uint8_t depth;
    ww(D64_OBJ_ENTITY_CALLBACK, cb);
    for (;;) {
        if (rb(rec) == 0xFF) return;
        if (!spr_project_entity(rec, spr, &screen, &depth)) {
            uint16_t f = rw(D64_OBJ_ENTITY_CALLBACK);      /* CALL NC,[09BA] */
            if (f == 0x0A2B) obj_object_sprite_update(rec, spr, screen, depth);
            else if (f == 0x0A42) obj_door_sprite_update(rec, spr, screen, depth);
            /* no other value is ever stored */
        }
        wb((uint16_t)(spr + 3), rb((uint16_t)(spr + 1)));
        wb((uint16_t)(spr + 4), rb((uint16_t)(spr + 2)));
        rec = (uint16_t)(rec + 5);
        spr = (uint16_t)(spr + 0x14);
        if (rb(D64_OBJ_FOR_EACH_PATCH) == 0xC9) return;    /* 09D4: RET */
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_09AB(void)
{
    obj_for_each_visible(HL, cpu.ix, cpu.iy);
    z80_ret();
}
#endif

/* 0983 obj_redraw_one_object (PC 1000:11C1, CPC 6128 0D13): one object only (reached by the JP at 4EA2):
 * [D64_OBJ_FOR_EACH_PATCH] = RET so that obj_for_each_visible stops after this entry,
 * obj_for_each_visible(0A2B, spr, obj), the patch back to NOP.  In: IX = spr, IY = obj.  Out: A = 0. */
void obj_redraw_one_object(uint16_t spr, uint16_t obj)
{
    wb(D64_OBJ_FOR_EACH_PATCH, 0xC9);
    obj_for_each_visible(0x0A2B, spr, obj);
    wb(D64_OBJ_FOR_EACH_PATCH, 0x00);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0983(void)
{
    obj_redraw_one_object(cpu.ix, cpu.iy);
    cpu.a = 0; cpu.zf = 1; cpu.cf = 0;
    z80_ret();
}

static int r_0983(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp8("A", cz->a, zz->a, msg, n);
    ok &= cmp8("ZF", cz->zf, zz->zf, msg, n);
    ok &= cmp8("CF", cz->cf, zz->cf, msg, n);
    return ok;
}
#endif

/* 0993 obj_place_objects_in_room (PC 1000:11D4, CPC 6128 0D23): every object (D64_OBJ_OBJECTS, sprites
 * D64_SPR_OBJECTS) with the callback obj_object_sprite_update.  In: -  Out: - */
void obj_place_objects_in_room(void)
{
    obj_for_each_visible(0x0A2B, D64_SPR_OBJECTS, D64_OBJ_OBJECTS);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0993(void)
{
    obj_place_objects_in_room();
    z80_ret();
}
#endif

/* 09A0 obj_place_doors_in_room (PC 1000:11DF, CPC 6128 0D30): every door (D64_OBJ_DOORS, sprites
 * D64_SPR_DOORS) with the callback obj_door_sprite_update.  In: -  Out: - */
void obj_place_doors_in_room(void)
{
    obj_for_each_visible(0x0A42, D64_SPR_DOORS, D64_OBJ_DOORS);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_09A0(void)
{
    obj_place_doors_in_room();
    z80_ret();
}
#endif

/* 0AD6 obj_door_flip_graphics (PC 1000:1332, CPC 6128 0E66): main-loop step: if the flip state the
 * visible doors need ([D64_OBJ_DOOR_FLIP_WANTED]) differs from the current one, the current one = it and
 * the door graphic (6 bytes x 28h lines) is mirrored (spr_flip_graphics_h, tail JP).  In: -  Out: - */
void obj_door_flip_graphics(void)
{
    uint8_t want = rb(D64_OBJ_DOOR_FLIP_WANTED);
    if (rb(D64_OBJ_DOOR_GFX_FLIPPED) == want) return;
    wb(D64_OBJ_DOOR_GFX_FLIPPED, want);
    spr_flip_graphics_h(D64_OBJ_DOOR_GFX, 6, 0x28);    /* JP 2F57: BC = 2806h, HL */
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0AD6(void)
{
    obj_door_flip_graphics();
    z80_ret();
}
#endif

/* 0B1D obj_door_check_open_close (PC 1000:1374, CPC 6128 0EAD): opens or closes door (sprite spr).
 * Fixed doors (bit 7 of [door+1]) are left alone.  bit = [door+1] & 1Fh & ([D64_OBJ_DOOR_CHECK_MASK] |
 * 10h).  If Guillermo or Adso lacks the bit (with the other's mask ORed in) and stands at x-2..x+3,
 * y-2..y+3, the door closes.  Else a permission entry with the bit standing at x-1..x+2, y-1..y+2 opens
 * it (if closed); none closes it.  Opening/closing: the old leaf cells get the door height
 * (obj_door_mark_cells with [door+4]), bit 6 set/cleared, [D64_OBJ_DOOR_MOVED] = 80h, the orientation
 * -1, or +1 (opening with bit 5 clear, closing with it set); if the third cell of the new leaf holds a
 * character ([cell] & F0h) the door bytes are restored, [D64_OBJ_DOOR_MOVED] = 0 and the leaf is marked
 * again.  The leaf pointer is IX's: the sprite while the door is outside the height buffer (then the
 * test reads a sprite byte, [spr + 2 step]).  The original keeps BC, DE, HL in the shadow registers
 * meanwhile (EXX): C locals.  In: IY = door, IX = spr.  Out: - (IX: its caller keeps it). */
void obj_door_check_open_close(uint16_t door, uint16_t spr)
{
    uint8_t flags = rb((uint16_t)(door + 1));
    uint8_t x0, y0, bit, m, x, y, saved0, saved1;
    uint16_t p, cell = spr, step;
    bool close;
    if (flags & 0x80) return;
    x0 = (uint8_t)(rb((uint16_t)(door + 2)) - 2);
    y0 = (uint8_t)(rb((uint16_t)(door + 3)) - 2);
    bit = (uint8_t)((rb(D64_OBJ_DOOR_CHECK_MASK) | 0x10) & (flags & 0x1F));
    if (obj_door_unpermitted_near(rb((uint16_t)(D64_OBJ_DOOR_PERMISSIONS + 3)), D64_OBJ_DOOR_PERMISSIONS, bit, x0, y0)
        || obj_door_unpermitted_near(rb(D64_OBJ_DOOR_PERMISSIONS), (uint16_t)(D64_OBJ_DOOR_PERMISSIONS + 3), bit, x0, y0)) {
        close = true;
    } else {
        x0++;
        y0++;
        p = D64_OBJ_DOOR_PERMISSIONS;
        close = true;
        for (;;) {
            m = rb(p);
            p++;
            if (m == 0xFF) break;
            if (!(m & bit)) { p = (uint16_t)(p + 2); continue; }
            x = util_read_indirect_pair(&p, &y);
            if ((uint8_t)(x - x0) >= 4) continue;
            if ((uint8_t)(y - y0) >= 4) continue;
            close = false;
            break;
        }
    }
    if (!close) {                                           /* 0B6E: someone allowed is near */
        if (rb((uint16_t)(door + 1)) & 0x40) return;
        saved0 = rb(door);
        saved1 = rb((uint16_t)(door + 1));
        wb((uint16_t)(door + 1), (uint8_t)(rb((uint16_t)(door + 1)) | 0x40));
        wb(D64_OBJ_DOOR_MOVED, 0x80);
        obj_door_mark_cells(door, rb((uint16_t)(door + 4)), &cell);
        wb(door, (uint8_t)(rb(door) - 1));
        if (!(rb((uint16_t)(door + 1)) & 0x20)) wb(door, (uint8_t)(rb(door) + 2));
    } else {                                                /* 0BB6: close it if it is open */
        if (!(rb((uint16_t)(door + 1)) & 0x40)) return;
        saved0 = rb(door);
        saved1 = rb((uint16_t)(door + 1));
        wb(D64_OBJ_DOOR_MOVED, 0x80);
        obj_door_mark_cells(door, rb((uint16_t)(door + 4)), &cell);
        wb((uint16_t)(door + 1), (uint8_t)(rb((uint16_t)(door + 1)) & 0xBF));
        wb(door, (uint8_t)(rb(door) - 1));
        if (rb((uint16_t)(door + 1)) & 0x20) wb(door, (uint8_t)(rb(door) + 2));
    }
    obj_door_cells(door, &cell, &step);                     /* 0B98: the new leaf */
    cell = (uint16_t)(cell + step);
    cell = (uint16_t)(cell + step);
    if (!(rb(cell) & 0xF0)) return;
    wb(door, saved0);                                       /* a character there: undone */
    wb((uint16_t)(door + 1), saved1);
    wb(D64_OBJ_DOOR_MOVED, 0);
    obj_door_mark_cells(door, rb((uint16_t)(door + 4)), &cell);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0B1D(void)
{
    obj_door_check_open_close(cpu.iy, cpu.ix);
    z80_ret();
}
#endif

/* ================================================================================================
 * The sound: the AY sequencer and its triggers
 * ================================================================================================ */

/* 0FBE snd_psg_write (PC 1000:63A2 snd_stub_psg_write, a RET there; CPC 6128 134E): AY register reg = v
 * through the PPI ports (plat_psg).  In: A = reg, C = v.  Out: - (A, BC: what the port sequence
 * leaves, used by no caller). */
void snd_psg_write(uint8_t reg, uint8_t v)
{
    plat_psg(reg, v);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0FBE(void)
{
    snd_psg_write(cpu.a, cpu.c);
    z80_ret();
}
#endif

/* 0FB8 snd_add_hl_a: hl + a (a byte; the same code as util_add_bx_al 128F).  In: HL, A.  Out: HL, A = H. */
uint16_t snd_add_hl_a(uint16_t hl, uint8_t a)
{
    return (uint16_t)(hl + a);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0FB8(void)
{
    uint16_t r = snd_add_hl_a(HL, cpu.a);
    SET_HL(r);
    cpu.a = (uint8_t)(r >> 8);
    z80_ret();
}

static int r_0FB8(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= cmp8("A", cz->a, zz->a, msg, n);
    return ok;
}
#endif

/* 0FDC snd_shift_right: hl >> a (a the octave, 0-7).  In: HL, A.  Out: HL, A = 0, ZF = 1. */
uint16_t snd_shift_right(uint16_t hl, uint8_t a)
{
    while (a) {
        hl >>= 1;
        a--;
    }
    return hl;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0FDC(void)
{
    SET_HL(snd_shift_right(HL, cpu.a));
    cpu.a = 0; cpu.zf = 1;
    z80_ret();
}

static int r_0FDC(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= cmp8("A", cz->a, zz->a, msg, n);
    ok &= cmp8("ZF", cz->zf, zz->zf, msg, n);
    return ok;
}
#endif

/* 0EA1 snd_tone_env_next: the next entry of the tone envelope of channel ch: e = [ch+SND_TONE_ENV] +
 * [ch+SND_TONE_INDEX]; 7Fh holds (steps, rate and count FFh, delta 0); 80h restarts it (index 0);
 * else steps = e0, delta = e1, rate = count = e2, index += 3.  In: IX = ch.  Out: - */
void snd_tone_env_next(uint16_t ch)
{
    uint16_t e;
    uint8_t a;
    for (;;) {
        e = snd_add_hl_a(rw((uint16_t)(ch + SND_TONE_ENV)), rb((uint16_t)(ch + SND_TONE_INDEX)));
        a = rb(e);
        if (a == 0x7F) {
            wb((uint16_t)(ch + SND_TONE_COUNT), 0xFF);
            wb((uint16_t)(ch + SND_TONE_RATE), 0xFF);
            wb((uint16_t)(ch + SND_TONE_STEPS), 0xFF);
            wb((uint16_t)(ch + SND_TONE_DELTA), 0x00);
            return;
        }
        if (a != 0x80) break;
        wb((uint16_t)(ch + SND_TONE_INDEX), 0);
    }
    wb((uint16_t)(ch + SND_TONE_STEPS), a);
    wb((uint16_t)(ch + SND_TONE_DELTA), rb((uint16_t)(e + 1)));
    wb((uint16_t)(ch + SND_TONE_RATE), rb((uint16_t)(e + 2)));
    wb((uint16_t)(ch + SND_TONE_COUNT), rb((uint16_t)(e + 2)));
    wb((uint16_t)(ch + SND_TONE_INDEX), (uint8_t)(rb((uint16_t)(ch + SND_TONE_INDEX)) + 3));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0EA1(void)
{
    snd_tone_env_next(cpu.ix);
    z80_ret();
}
#endif

/* 0F0B snd_vol_env_next: the next entry of the volume envelope of channel ch: e = [ch+SND_VOL_ENV] +
 * [ch+SND_VOL_INDEX]; 7Fh holds (count, rate and steps FFh, delta 0); 80h restarts it; 8xh the AY
 * envelope: shape x, period e1, e2 ([D64_SND_ENV_*]), count = e3, steps 1, state bit 4, index += 4;
 * else steps = e0, delta = e1, rate = count = e2, index += 3.  In: IX = ch.  Out: - */
void snd_vol_env_next(uint16_t ch)
{
    uint16_t e;
    uint8_t a;
    for (;;) {
        e = snd_add_hl_a(rw((uint16_t)(ch + SND_VOL_ENV)), rb((uint16_t)(ch + SND_VOL_INDEX)));
        a = rb(e);
        if (a == 0x7F) {
            wb((uint16_t)(ch + SND_VOL_COUNT), 0xFF);
            wb((uint16_t)(ch + SND_VOL_RATE), 0xFF);
            wb((uint16_t)(ch + SND_VOL_STEPS), 0xFF);
            wb((uint16_t)(ch + SND_VOL_DELTA), 0x00);
            return;
        }
        if (a != 0x80) break;
        wb((uint16_t)(ch + SND_VOL_INDEX), 0);
    }
    if (a & 0x80) {                                         /* 0F3A: the AY envelope */
        wb(D64_SND_ENV_SHAPE, (uint8_t)(a & 0x0F));
        wb(D64_SND_ENV_PERIOD_LO, rb((uint16_t)(e + 1)));
        wb(D64_SND_ENV_PERIOD_HI, rb((uint16_t)(e + 2)));
        wb((uint16_t)(ch + SND_VOL_COUNT), rb((uint16_t)(e + 3)));
        wb((uint16_t)(ch + SND_VOL_STEPS), 1);
        wb((uint16_t)(ch + SND_STATE), (uint8_t)(rb((uint16_t)(ch + SND_STATE)) | 0x10));
        wb((uint16_t)(ch + SND_VOL_INDEX), (uint8_t)(rb((uint16_t)(ch + SND_VOL_INDEX)) + 4));
        return;
    }
    wb((uint16_t)(ch + SND_VOL_STEPS), a);
    wb((uint16_t)(ch + SND_VOL_DELTA), rb((uint16_t)(e + 1)));
    wb((uint16_t)(ch + SND_VOL_RATE), rb((uint16_t)(e + 2)));
    wb((uint16_t)(ch + SND_VOL_COUNT), rb((uint16_t)(e + 2)));
    wb((uint16_t)(ch + SND_VOL_INDEX), (uint8_t)(rb((uint16_t)(ch + SND_VOL_INDEX)) + 3));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0F0B(void)
{
    snd_vol_env_next(cpu.ix);
    z80_ret();
}
#endif

/* 0EE5 snd_vol_env_step: the volume envelope of channel ch, once a tick: count -= 1, nothing while not
 * 0; then steps -= 1 (at 0 snd_vol_env_next), state bit 5 (volume to send), count = rate, and unless an
 * AY envelope (bit 4) volume = (volume + delta) & 0Fh.  In: IX = ch.  Out: - */
void snd_vol_env_step(uint16_t ch)
{
    uint8_t n = (uint8_t)(rb((uint16_t)(ch + SND_VOL_COUNT)) - 1);
    wb((uint16_t)(ch + SND_VOL_COUNT), n);
    if (n) return;
    n = (uint8_t)(rb((uint16_t)(ch + SND_VOL_STEPS)) - 1);
    wb((uint16_t)(ch + SND_VOL_STEPS), n);
    if (n == 0) snd_vol_env_next(ch);
    wb((uint16_t)(ch + SND_STATE), (uint8_t)(rb((uint16_t)(ch + SND_STATE)) | 0x20));
    wb((uint16_t)(ch + SND_VOL_COUNT), rb((uint16_t)(ch + SND_VOL_RATE)));
    if (rb((uint16_t)(ch + SND_STATE)) & 0x10) return;
    wb((uint16_t)(ch + SND_VOLUME), (uint8_t)((rb((uint16_t)(ch + SND_VOLUME)) + rb((uint16_t)(ch + SND_VOL_DELTA))) & 0x0F));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0EE5(void)
{
    snd_vol_env_step(cpu.ix);
    z80_ret();
}
#endif

/* the sequence commands (the handlers of D64_SND_COMMANDS, entered by JP (HL) from snd_channel_tick with
 * its loop address pushed: they return to it).  In: BC = arg (the two bytes after the command), IX = ch,
 * DE = the sequence pointer past them. */

/* 0F88 snd_cmd_jump (F9): the sequence goes on at arg.  Out: DE = arg. */
uint16_t snd_cmd_jump(uint16_t arg)
{
    return arg;
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0F88(void)
{
    SET_DE(snd_cmd_jump(BC));
    z80_ret();
}

static int r_0F88(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    return cmp16("DE", R_DE(cz), R_DE(zz), msg, n);
}
#endif

/* 0F8B snd_cmd_start_b (FE): channel B plays sequence arg (state 5: playing, starting; 1 tick left). */
void snd_cmd_start_b(uint16_t arg)
{
    ww((uint16_t)(D64_SND_CHANNEL_B + SND_SEQ), arg);
    wb((uint16_t)(D64_SND_CHANNEL_B + SND_STATE), 0x05);
    wb((uint16_t)(D64_SND_CHANNEL_B + SND_LEFT), 0x01);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0F8B(void)
{
    snd_cmd_start_b(BC);
    cpu.a = 0x01;
    z80_ret();
}
#endif

/* 0F9A snd_cmd_start_c (FD): channel C plays sequence arg. */
void snd_cmd_start_c(uint16_t arg)
{
    ww((uint16_t)(D64_SND_CHANNEL_C + SND_SEQ), arg);
    wb((uint16_t)(D64_SND_CHANNEL_C + SND_STATE), 0x05);
    wb((uint16_t)(D64_SND_CHANNEL_C + SND_LEFT), 0x01);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0F9A(void)
{
    snd_cmd_start_c(BC);
    cpu.a = 0x01;
    z80_ret();
}
#endif

/* 0FA9 snd_cmd_tone_env (FB): the tone envelope of channel ch = arg. */
void snd_cmd_tone_env(uint16_t ch, uint16_t arg)
{
    ww((uint16_t)(ch + SND_TONE_ENV), arg);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0FA9(void)
{
    snd_cmd_tone_env(cpu.ix, BC);
    z80_ret();
}
#endif

/* 0FB0 snd_cmd_vol_env (FA): the volume envelope of channel ch = arg. */
void snd_cmd_vol_env(uint16_t ch, uint16_t arg)
{
    ww((uint16_t)(ch + SND_VOL_ENV), arg);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0FB0(void)
{
    snd_cmd_vol_env(cpu.ix, BC);
    z80_ret();
}
#endif

/* 0FB7 snd_cmd_nothing (FC): a lone RET, its argument skipped. */
void snd_cmd_nothing(void)
{
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0FB7(void)
{
    snd_cmd_nothing();
    z80_ret();
}
#endif

/* the handler of a sequence command (the word of its D64_SND_COMMANDS entry); returns the sequence
 * pointer (DE) */
static uint16_t snd_command(uint16_t handler, uint16_t ch, uint16_t arg, uint16_t de)
{
    switch (handler) {
    case 0x0F88: return snd_cmd_jump(arg);
    case 0x0F8B: snd_cmd_start_b(arg); break;
    case 0x0F9A: snd_cmd_start_c(arg); break;
    case 0x0FA9: snd_cmd_tone_env(ch, arg); break;
    case 0x0FB0: snd_cmd_vol_env(ch, arg); break;
    case 0x0FB7: snd_cmd_nothing(); break;
    default: break;                             /* the table 0F76 holds no other handler */
    }
    return de;
}

/* 0DBC snd_channel_tick: the sequence of channel ch, once an interrupt.  Nothing unless playing (state
 * bit 0); the state keeps bits 0, 1, 2, 7.  On the tempo tick ([D64_SND_TEMPO] = 0) when the note ends
 * (left -= 1 reaches 0): state = 1, the commands (D64_SND_COMMANDS) at the sequence pointer run; FFh
 * ends the sequence (state 0); else a note: n, ticks, [noise period when bit 7 of n: state bits 1, 3],
 * the envelopes restart, volume 0; n & 0Fh = 0Fh is a rest (state bit 7), else the period =
 * D64_SND_NOTE_PERIODS[n & 0Fh] >> ((n >> 4) & 7).  Then, unless silent (bit 7) or starting (bit 2):
 * snd_vol_env_step, and every tone rate ticks the tone envelope step: steps -= 1 (at 0
 * snd_tone_env_next), period += delta (signed), state bit 6 (period to send).  In: IX = ch.  Out: - */
void snd_channel_tick(uint16_t ch)
{
    uint8_t st = rb((uint16_t)(ch + SND_STATE)), c, k;
    uint16_t de, p, d;
    if (!(st & 0x01)) return;
    wb((uint16_t)(ch + SND_STATE), (uint8_t)(st & 0x87));
    if (rb(D64_SND_TEMPO) == 0) {
        k = (uint8_t)(rb((uint16_t)(ch + SND_LEFT)) - 1);
        wb((uint16_t)(ch + SND_LEFT), k);
        if (k == 0) {
            wb((uint16_t)(ch + SND_STATE), 0x01);
            de = rw((uint16_t)(ch + SND_SEQ));
            for (;;) {                                      /* 0DDE: the commands */
                p = D64_SND_COMMANDS;
                for (k = 6; k != 0; --k) {
                    if (rb(de) == rb(p)) break;
                    p = (uint16_t)(p + 3);
                }
                if (k == 0) break;
                d = rw((uint16_t)(de + 1));
                de = snd_command(rw((uint16_t)(p + 1)), ch, d, (uint16_t)(de + 3));
            }
            if (rb(de) == 0xFF) {                           /* the end */
                wb((uint16_t)(ch + SND_STATE), 0x00);
                return;
            }
            wb((uint16_t)(ch + SND_TONE_COUNT), 1);        /* 0E06: a note */
            wb((uint16_t)(ch + SND_TONE_STEPS), 1);
            wb((uint16_t)(ch + SND_VOL_COUNT), 1);
            wb((uint16_t)(ch + SND_VOL_STEPS), 1);
            wb((uint16_t)(ch + SND_VOL_INDEX), 0);
            wb((uint16_t)(ch + SND_TONE_INDEX), 0);
            c = rb(de);
            wb((uint16_t)(ch + SND_LEFT), rb((uint16_t)(de + 1)));
            de = (uint16_t)(de + 2);
            if (c & 0x80) {                                 /* with noise */
                wb(D64_SND_NOISE_PERIOD, rb(de));
                wb((uint16_t)(ch + SND_STATE), (uint8_t)(rb((uint16_t)(ch + SND_STATE)) | 0x0A));
                de++;
            }
            wb((uint16_t)(ch + SND_VOLUME), 0);
            ww((uint16_t)(ch + SND_SEQ), de);
            wb((uint16_t)(ch + SND_STATE), (uint8_t)(rb((uint16_t)(ch + SND_STATE)) | 0x80));
            if ((c & 0x0F) == 0x0F) return;                 /* a rest */
            wb((uint16_t)(ch + SND_STATE), (uint8_t)(rb((uint16_t)(ch + SND_STATE)) & 0x7F));
            p = snd_add_hl_a(D64_SND_NOTE_PERIODS, (uint8_t)((c & 0x0F) * 2));
            ww((uint16_t)(ch + SND_PERIOD), snd_shift_right(rw(p), (uint8_t)((c >> 4) & 7)));
        }
    }
    st = rb((uint16_t)(ch + SND_STATE));                    /* 0E67 */
    if (st & 0x80) return;
    if (st & 0x04) return;
    snd_vol_env_step(ch);
    k = (uint8_t)(rb((uint16_t)(ch + SND_TONE_COUNT)) - 1);
    wb((uint16_t)(ch + SND_TONE_COUNT), k);
    if (k) return;
    k = (uint8_t)(rb((uint16_t)(ch + SND_TONE_STEPS)) - 1);
    wb((uint16_t)(ch + SND_TONE_STEPS), k);
    if (k == 0) snd_tone_env_next(ch);
    wb((uint16_t)(ch + SND_TONE_COUNT), rb((uint16_t)(ch + SND_TONE_RATE)));
    d = rb((uint16_t)(ch + SND_TONE_DELTA));
    if (d & 0x80) d |= 0xFF00;
    ww((uint16_t)(ch + SND_PERIOD), (uint16_t)(rw((uint16_t)(ch + SND_PERIOD)) + d));
    wb((uint16_t)(ch + SND_STATE), (uint8_t)(rb((uint16_t)(ch + SND_STATE)) | 0x40));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0DBC(void)
{
    snd_channel_tick(cpu.ix);
    z80_ret();
}
#endif

/* 0D40 snd_channel_output: what channel ch sends to the AY, once an interrupt.  Nothing unless playing
 * (bit 0) and not starting (bit 2) nor silent (bit 7).  Bit 6: the period to its tone registers; bit 5:
 * the volume to its volume register, or with an AY envelope (bit 4) the envelope period and shape
 * (registers 11-13) and 10h (envelope mode) to its volume register; then its mixer bits: tone only
 * (07h & bits), or with noise (bit 1) tone and noise (3Fh & bits), the noise period (register 6) when
 * bit 3, toggled into [D64_SND_MIXER].  In: IX = ch.  Out: - */
void snd_channel_output(uint16_t ch)
{
    uint8_t l = rb((uint16_t)(ch + SND_STATE)), a;
    if (!(l & 0x01)) return;
    if (l & 0x04) return;
    if (l & 0x80) return;
    if (l & 0x40) {
        snd_psg_write(rb((uint16_t)(ch + SND_REG_TONE)), rb((uint16_t)(ch + SND_PERIOD)));
        snd_psg_write((uint8_t)(rb((uint16_t)(ch + SND_REG_TONE)) + 1), rb((uint16_t)(ch + SND_PERIOD + 1)));
    }
    if (l & 0x20) {
        if (!(l & 0x10)) {
            snd_psg_write(rb((uint16_t)(ch + SND_REG_VOLUME)), rb((uint16_t)(ch + SND_VOLUME)));
        } else {
            snd_psg_write(0x0B, rb(D64_SND_ENV_PERIOD_LO));
            snd_psg_write(0x0C, rb(D64_SND_ENV_PERIOD_HI));
            snd_psg_write(0x0D, rb(D64_SND_ENV_SHAPE));
            snd_psg_write(rb((uint16_t)(ch + SND_REG_VOLUME)), 0x10);
        }
    }
    a = 0x07;
    if (l & 0x02) {
        if (l & 0x08) snd_psg_write(0x06, rb(D64_SND_NOISE_PERIOD));
        a = 0x3F;
    }
    wb(D64_SND_MIXER, (uint8_t)(rb(D64_SND_MIXER) ^ (a & rb((uint16_t)(ch + SND_MIXER_BITS)))));
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0D40(void)
{
    snd_channel_output(cpu.ix);
    z80_ret();
}
#endif

/* 0CD0 snd_interrupt: the sound of the interrupt (called by its handler at 28A3; DI ... EI, RETI).
 * Nothing unless a channel plays; the tempo counter 6..0; the mixer starts at 3Fh (all off); the
 * sequences of the three channels (snd_channel_tick), then what they send (snd_channel_output); the
 * mixer to the AY (register 7) when it changed.  Every register kept.  In: -  Out: - (interrupts
 * enabled). */
void snd_interrupt(void)
{
    uint8_t t;
    plat_di();
    if ((rb((uint16_t)(D64_SND_CHANNEL_A + SND_STATE)) | rb((uint16_t)(D64_SND_CHANNEL_B + SND_STATE))
         | rb((uint16_t)(D64_SND_CHANNEL_C + SND_STATE))) & 0x01) {
        t = (uint8_t)(rb(D64_SND_TEMPO) - 1);
        if (t == 0xFF) t = 6;
        wb(D64_SND_TEMPO, t);
        wb(D64_SND_MIXER, 0x3F);
        snd_channel_tick(D64_SND_CHANNEL_A);
        snd_channel_tick(D64_SND_CHANNEL_B);
        snd_channel_tick(D64_SND_CHANNEL_C);
        snd_channel_output(D64_SND_CHANNEL_A);
        snd_channel_output(D64_SND_CHANNEL_B);
        snd_channel_output(D64_SND_CHANNEL_C);
        if (rb(D64_SND_MIXER) != rb(D64_SND_MIXER_SENT)) {
            wb(D64_SND_MIXER_SENT, rb(D64_SND_MIXER));
            snd_psg_write(0x07, rb(D64_SND_MIXER));
        }
    }
    plat_ei();
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0CD0(void)
{
    snd_interrupt();
    z80_ret();                          /* RETI */
}

static int r_iff(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp8("IFF1", cz->iff1, zz->iff1, msg, n);
    ok &= cmp8("IFF2", cz->iff2, zz->iff2, msg, n);
    return ok;
}

static int r_0CD0(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = r_iff(cz, zz, msg, n);
    ok &= cmp8("A", cz->a, zz->a, msg, n);
    ok &= cmp8("F", flags_de(cz), flags_de(zz), msg, n);
    ok &= cmp16("BC", R_BC(cz), R_BC(zz), msg, n);
    ok &= cmp16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= cmp16("HL", R_HL(cz), R_HL(zz), msg, n);
    ok &= cmp16("IX", cz->ix, zz->ix, msg, n);
    return ok;
}
#endif

/* 0FE6 snd_silence_all (PC 1000:63A3 snd_silence_if_idle, CPC 6128 1376): every channel stops (state
 * 84h: not playing, silent, starting) and the AY mixer = 3Fh (all off; [D64_SND_MIXER_SENT] is kept).
 * In: -  Out: - */
void snd_silence_all(void)
{
    wb((uint16_t)(D64_SND_CHANNEL_A + SND_STATE), 0x84);
    wb((uint16_t)(D64_SND_CHANNEL_B + SND_STATE), 0x84);
    wb((uint16_t)(D64_SND_CHANNEL_C + SND_STATE), 0x84);
    snd_psg_write(0x07, 0x3F);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0FE6(void)
{
    snd_silence_all();
    z80_ret();
}
#endif

/* 0CBF snd_start (PC 1000:0553, CPC 6128 104F): channel ch plays sequence seq: state 5 (playing,
 * starting), 1 tick left; DI ... EI.  In: IX = ch, HL = seq.  Out: - (interrupts enabled). */
void snd_start(uint16_t ch, uint16_t seq)
{
    plat_di();
    wb((uint16_t)(ch + SND_STATE), 0x05);
    ww((uint16_t)(ch + SND_SEQ), seq);
    wb((uint16_t)(ch + SND_LEFT), 0x01);
    plat_ei();
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0CBF(void)
{
    snd_start(cpu.ix, HL);
    z80_ret();
}
#endif

/* 0CA4 snd_start_if_idle (PC 1000:0543, CPC 6128 1034): snd_start(channel C, seq) only if channel C is
 * idle (state 0).  In: HL = seq.  Out: - */
void snd_start_if_idle(uint16_t seq)
{
    if (rb((uint16_t)(D64_SND_CHANNEL_C + SND_STATE)) != 0) return;
    snd_start(D64_SND_CHANNEL_C, seq);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0CA4(void)
{
    snd_start_if_idle(HL);
    z80_ret();
}
#endif

/* the triggers: LD HL,seq and a JR to snd_start with the channel (0CAF A, 0CB5 B, 0CBB C) or to
 * snd_start_if_idle.  In: -  Out: - (interrupts enabled when started). */

/* 0C6D snd_play_mirror_open (PC 1000:6360 snd_stub_mirror_open, a RET there; CPC 6128 0FFD): the mirror
 * opens (from 2DE4). */
void snd_play_mirror_open(void)
{
    snd_start(D64_SND_CHANNEL_A, D64_SND_SEQ_MIRROR_OPEN);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C6D(void) { snd_play_mirror_open(); z80_ret(); }
#endif

/* 0C72 snd_play_footstep (PC 1000:6361, CPC 6128 1002). */
void snd_play_footstep(void)
{
    snd_start(D64_SND_CHANNEL_C, D64_SND_SEQ_FOOTSTEP);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C72(void) { snd_play_footstep(); z80_ret(); }
#endif

/* 0C77 snd_play_music_if_idle (PC 1000:6367, CPC 6128 1007). */
void snd_play_music_if_idle(void)
{
    snd_start_if_idle(D64_SND_SEQ_MUSIC);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C77(void) { snd_play_music_if_idle(); z80_ret(); }
#endif

/* 0C7C snd_play_hour_bells (PC 1000:636D snd_stub_event, a RET there; CPC 6128 100C): the bells at
 * prima, sexta and visperas. */
void snd_play_hour_bells(void)
{
    snd_start(D64_SND_CHANNEL_A, D64_SND_SEQ_HOUR_BELLS);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C7C(void) { snd_play_hour_bells(); z80_ret(); }
#endif

/* 0C81 snd_play_tercia_bells (PC 1000:636E snd_stub_bells, a RET there; CPC 6128 1011): the bells at
 * tercia. */
void snd_play_tercia_bells(void)
{
    snd_start(D64_SND_CHANNEL_A, D64_SND_SEQ_TERCIA_BELLS);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C81(void) { snd_play_tercia_bells(); z80_ret(); }
#endif

/* 0C86 snd_play_door_close (PC 1000:636F snd_stub_door_close, a RET there; CPC 6128 1016). */
void snd_play_door_close(void)
{
    snd_start(D64_SND_CHANNEL_B, D64_SND_SEQ_DOOR_CLOSE);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C86(void) { snd_play_door_close(); z80_ret(); }
#endif

/* 0C8B snd_play_door_open (PC 1000:6370, CPC 6128 101B). */
void snd_play_door_open(void)
{
    snd_start(D64_SND_CHANNEL_B, D64_SND_SEQ_DOOR_OPEN);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C8B(void) { snd_play_door_open(); z80_ret(); }
#endif

/* 0C90 snd_play_beep (PC 1000:6376, CPC 6128 1020). */
void snd_play_beep(void)
{
    snd_start(D64_SND_CHANNEL_C, D64_SND_SEQ_BEEP);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C90(void) { snd_play_beep(); z80_ret(); }
#endif

/* 0C95 snd_play_object_taken (PC 1000:637C, CPC 6128 1025). */
void snd_play_object_taken(void)
{
    snd_start(D64_SND_CHANNEL_B, D64_SND_SEQ_OBJECT_TAKEN);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C95(void) { snd_play_object_taken(); z80_ret(); }
#endif

/* 0C9A snd_play_severino (PC 1000:6382 snd_stub_counter, a RET there; CPC 6128 102A): day 5, nona, the
 * abbot and Guillermo find Severino dead. */
void snd_play_severino(void)
{
    snd_start(D64_SND_CHANNEL_B, D64_SND_SEQ_SEVERINO);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C9A(void) { snd_play_severino(); z80_ret(); }
#endif

/* 0C9F snd_play_object_dropped (PC 1000:6383, CPC 6128 102F). */
void snd_play_object_dropped(void)
{
    snd_start(D64_SND_CHANNEL_B, D64_SND_SEQ_OBJECT_DROPPED);
}
#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0C9F(void) { snd_play_object_dropped(); z80_ret(); }
#endif

/* ================================================================================================
 * Small helpers of the path search and the doors
 * ================================================================================================ */

/* 0BF8 chr_path_reset_alternatives (PC 1000:1498, CPC 6128 0F88): [D64_CHR_PATH_ALT_PTR] =
 * D64_CHR_PATH_ALTERNATIVES and FFh at its fourth byte: only the first candidate destination is kept.
 * In: -  Out: DE = D64_CHR_PATH_ALTERNATIVES + 3, A = FFh. */
void chr_path_reset_alternatives(void)
{
    ww(D64_CHR_PATH_ALT_PTR, D64_CHR_PATH_ALTERNATIVES);
    wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3), 0xFF);
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_0BF8(void)
{
    chr_path_reset_alternatives();
    SET_DE((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3));
    cpu.a = 0xFF;
    z80_ret();
}

static int r_0BF8(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = cmp16("DE", R_DE(cz), R_DE(zz), msg, n);
    ok &= cmp8("A", cz->a, zz->a, msg, n);
    return ok;
}
#endif

/* 09D7 obj_update_doors (PC 1000:1217, CPC 6128 0D67): main-loop step.  [D64_OBJ_DOOR_FLIP_WANTED] = 0;
 * for each door (D64_OBJ_DOORS, sprites D64_SPR_DOORS): [D64_OBJ_DOOR_MOVED] = 0;
 * obj_door_check_open_close; if visible (spr_project_entity) obj_door_sprite_update; then, when the
 * room is not being redrawn ([D64_ISO_ROOM_CHANGED] = 0) and the sprite is active (not FEh) and to be
 * redrawn (bit 7): the door-open sound if the door is open (bit 6 of [door+1]), else the door-close
 * sound.  In: -  Out: - */
void obj_update_doors(void)
{
    uint16_t spr = D64_SPR_DOORS, door = D64_OBJ_DOORS, screen;
    uint8_t depth, s;
    wb(D64_OBJ_DOOR_FLIP_WANTED, 0);
    while (rb(door) != 0xFF) {
        wb(D64_OBJ_DOOR_MOVED, 0);
        obj_door_check_open_close(door, spr);
        if (!spr_project_entity(door, spr, &screen, &depth)) obj_door_sprite_update(door, spr, screen, depth);
        if (rb(D64_ISO_ROOM_CHANGED) == 0) {
            s = rb(spr);
            if (s != 0xFE && (s & 0x80)) {
                if (rb((uint16_t)(door + 1)) & 0x40) snd_play_door_open();
                else snd_play_door_close();
            }
        }
        door = (uint16_t)(door + 5);
        spr = (uint16_t)(spr + 0x14);
    }
}

#ifndef JUEGO_PURO  /* the hybrid host */
static void w_09D7(void)
{
    obj_update_doors();
    z80_ret();
}

/* ---- the table of the group ---- */

const traducida_t traducidas_objetos_sonido[] = {
    { 0x0983, "obj_redraw_one_object", w_0983, r_0983 },
    { 0x0993, "obj_place_objects_in_room", w_0993, sin_resultados },
    { 0x09A0, "obj_place_doors_in_room", w_09A0, sin_resultados },
    { 0x09AB, "obj_for_each_visible", w_09AB, sin_resultados },
    { 0x09D7, "obj_update_doors", w_09D7, sin_resultados },
    { 0x0A2B, "obj_object_sprite_update", w_0A2B, sin_resultados },
    { 0x0A42, "obj_door_sprite_update", w_0A42, sin_resultados },
    { 0x0A89, "obj_door_mark_cells", w_0A89, r_0A89 },
    { 0x0A9C, "obj_door_cells", w_0A9C, r_0A9C },
    { 0x0ABC, "spr_project_entity", w_0ABC, r_0ABC },
    { 0x0AD6, "obj_door_flip_graphics", w_0AD6, sin_resultados },
    { 0x0AEC, "obj_door_camera_adjust", w_0AEC, r_0AEC },
    { 0x0AFC, "obj_door_adjust_grid_pos", w_0AFC, r_0AFC },
    { 0x0B1D, "obj_door_check_open_close", w_0B1D, sin_resultados },
    { 0x0BDC, "obj_door_unpermitted_near", w_0BDC, r_0BDC },
    { 0x0BEC, "util_read_indirect_pair", w_0BEC, r_0BEC },
    { 0x0BF8, "chr_path_reset_alternatives", w_0BF8, r_0BF8 },
    { 0x0C6D, "snd_play_mirror_open", w_0C6D, r_iff },
    { 0x0C72, "snd_play_footstep", w_0C72, r_iff },
    { 0x0C77, "snd_play_music_if_idle", w_0C77, r_iff },
    { 0x0C7C, "snd_play_hour_bells", w_0C7C, r_iff },
    { 0x0C81, "snd_play_tercia_bells", w_0C81, r_iff },
    { 0x0C86, "snd_play_door_close", w_0C86, r_iff },
    { 0x0C8B, "snd_play_door_open", w_0C8B, r_iff },
    { 0x0C90, "snd_play_beep", w_0C90, r_iff },
    { 0x0C95, "snd_play_object_taken", w_0C95, r_iff },
    { 0x0C9A, "snd_play_severino", w_0C9A, r_iff },
    { 0x0C9F, "snd_play_object_dropped", w_0C9F, r_iff },
    { 0x0CA4, "snd_start_if_idle", w_0CA4, r_iff },
    { 0x0CBF, "snd_start", w_0CBF, r_iff },
    { 0x0CD0, "snd_interrupt", w_0CD0, r_0CD0 },
    { 0x0D40, "snd_channel_output", w_0D40, sin_resultados },
    { 0x0DBC, "snd_channel_tick", w_0DBC, sin_resultados },
    { 0x0EA1, "snd_tone_env_next", w_0EA1, sin_resultados },
    { 0x0EE5, "snd_vol_env_step", w_0EE5, sin_resultados },
    { 0x0F0B, "snd_vol_env_next", w_0F0B, sin_resultados },
    { 0x0F88, "snd_cmd_jump", w_0F88, r_0F88 },
    { 0x0F8B, "snd_cmd_start_b", w_0F8B, resultado_a },
    { 0x0F9A, "snd_cmd_start_c", w_0F9A, resultado_a },
    { 0x0FA9, "snd_cmd_tone_env", w_0FA9, sin_resultados },
    { 0x0FB0, "snd_cmd_vol_env", w_0FB0, sin_resultados },
    { 0x0FB7, "snd_cmd_nothing", w_0FB7, sin_resultados },
    { 0x0FB8, "snd_add_hl_a", w_0FB8, r_0FB8 },
    { 0x0FBE, "snd_psg_write", w_0FBE, sin_resultados },
    { 0x0FDC, "snd_shift_right", w_0FDC, r_0FDC },
    { 0x0FE6, "snd_silence_all", w_0FE6, sin_resultados },
    { 0, NULL, NULL, NULL }
};
#endif

