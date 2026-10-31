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

/* abadia64ks, group camino: the CPC 64 KiB code 036D-0982 in C (the monks' AI drivers, the route
 * planner, the path search's high level, the grid of the search and the command writer).  Each
 * function cites its 64K address and the PC rebuild's function it corresponds to (c/src/ai.c, chr.c,
 * iso.c); the 64K code is the reference.
 *
 * The SP.  The path searches of logica_a (3F92, 3F9E, 438F/4399, 434F/41A8 -> 41C9) store SP into
 * chr_path_saved_sp [2901] and use their own queue as a stack, so the functions on the way to them take
 * `sp`, the Z80 SP at their entry (pointing at their return address), as the PC rebuild does, and give
 * each callee the SP it has at its entry: sp minus what the Z80 pushed before the CALL, minus 2 for the
 * CALL itself.  The 0008 / 0010 entries of the group are the RST 08h / 10h stubs
 * (JP 391E / JP 38FC, written by the game at its start): they are not functions of their own. */
#include <stdio.h>
#include <string.h>
#include "juego64.h"
#include "datos_camino.h"

/* ================================================================================ the drivers */

/* 036D ai_update_malachi (PC 1000:0AE6): per-frame driver of Malachi (record 2BA5, places 37F8):
 * ai_no_route [37E9] = 0, his behaviour 52B4 (IY record, IX places, A = 0), door permissions 3Fh (39F1),
 * chr_update of his chr_table entry 2717, then JP 03AC (ai_plan_route) with the record chr_update leaves
 * in IY.  In: sp.  Out: nothing. */
void ai_update_malachi(uint16_t sp)
{
    wb(D64_AI_NO_ROUTE, 0);
    ai_malachi_think(D64_CHR_MALACHI, D64_AI_MALACHI_PLACES);                 /* CALL 52B4 (IY, IX, A = 0) */
    obj_set_door_permissions(0x3F);
    (void)chr_update(D64_CHR_TABLE_MALACHI);
    ai_plan_route(rw(D64_CHR_CUR_DATA), D64_AI_MALACHI_PLACES, sp);   /* IY = the record chr_update worked on */
}

/* 038E ai_update_abbot (PC 1000:0B04): driver of the abbot (record 2BB4, places 3816): ai_abbot_think
 * 5B21, doors mask 3Fh, chr_update(2721), then falls into ai_plan_route.  In: sp. */
void ai_update_abbot(uint16_t sp)
{
    wb(D64_AI_NO_ROUTE, 0);
    ai_abbot_think(D64_CHR_ABBOT, D64_AI_ABBOT_PLACES);                 /* CALL 5B21 (IY, IX, A = 0) */
    obj_set_door_permissions(0x3F);
    (void)chr_update(D64_CHR_TABLE_ABBOT);
    ai_plan_route(rw(D64_CHR_CUR_DATA), D64_AI_ABBOT_PLACES, sp);   /* IY = the record chr_update worked on */
}

/* 03AC ai_plan_route (PC 1000:0B20): the shared tail of the drivers (fall-through from 038E, JP from
 * 036D, 04A0, 04C1, 050E; nothing pushed: sp = the driver's entry SP).  A move already planned (bit 7
 * of [chr+9] clear) -> JP ai_check_planned_move.  ai_no_route set -> nothing.  Destination d =
 * [places-1]: FF/FE/FD/FC = Guillermo / the abbot / the book / the parchment, whose four neighbours are
 * the candidates (slot 0201); else the place p = places + 3d (8 bit) is copied to 0203 (FF after it)
 * and its four neighbours follow (slot 0204).  chr_path_alt_ptr [0213] = 0203; no candidate -> return;
 * else chr_path_find(chr, 0203) (IX and the return address pushed) and, when the result is FD (already
 * there), [places-3] = [places-1] (destination reached).  In: IY = chr, IX = places, sp. */
void ai_plan_route(uint16_t chr, uint16_t places, uint16_t sp)
{
    uint8_t d;
    uint16_t target, slot, p;
    if (!(rb((uint16_t)(chr + 9)) & 0x80)) {
        ai_check_planned_move(chr);                      /* 03B0 JP Z,04E2 */
        return;
    }
    if (rb(D64_AI_NO_ROUTE) != 0) return;
    d = rb((uint16_t)(places - 1));
    slot = D64_CHR_PATH_SLOT;
    switch (d) {
    case 0xFF: target = D64_CHR_GUILLERMO; break;
    case 0xFE: target = D64_CHR_ABBOT; break;
    case 0xFD: target = D64_OBJ_OBJECTS; break;          /* the book */
    case 0xFC: target = D64_OBJ_PARCHMENT; break;
    default:
        p = (uint16_t)(places + (uint8_t)(d * 3));
        wb(D64_CHR_PATH_ALTERNATIVES, rb(p));             /* 03DC LDI x 3 */
        wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 1), rb((uint16_t)(p + 1)));
        wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 2), rb((uint16_t)(p + 2)));
        wb((uint16_t)(D64_CHR_PATH_ALTERNATIVES + 3), 0xFF);
        target = (uint16_t)(p - 2);
        slot = (uint16_t)(D64_CHR_PATH_ALTERNATIVES + 1);
        break;
    }
    chr_path_add_targets_around(target, slot);
    ww(D64_CHR_PATH_ALT_PTR, D64_CHR_PATH_ALTERNATIVES);
    if (rb(D64_CHR_PATH_ALTERNATIVES) == 0xFF) return;
    chr_path_find(chr, D64_CHR_PATH_ALTERNATIVES, (uint16_t)(sp - 4));
    if (rb(D64_CHR_PATH_RESULT) == 0xFD) wb((uint16_t)(places - 3), rb((uint16_t)(places - 1)));
}

/* 042D chr_path_add_targets_around (PC 1000:0BAF): one candidate beside the target for each of the
 * four orientations, starting with the target's own [target+1]: chr_path_add_target_beside three
 * times with the orientation o, o+1, o+2, then falls into it with o+3.  target = a record (x +2, y +3,
 * z +4) or, for a place, the place - 2; slot = the candidate buffer - 2.  In: HL = target, DE = slot.
 * Out: the last slot (IY); IX = target. */
uint16_t chr_path_add_targets_around(uint16_t target, uint16_t slot)
{
    uint8_t o = rb((uint16_t)(target + 1));
    slot = chr_path_add_target_beside(target, slot, &o);
    o++;
    slot = chr_path_add_target_beside(target, slot, &o);
    o++;
    slot = chr_path_add_target_beside(target, slot, &o);
    o++;
    return chr_path_add_target_beside(target, slot, &o);
}

/* 0442 chr_path_add_target_beside (PC 1000:0BC5): *orient &= 3; candidate at slot+2..+4: x =
 * [target+2] + dx, y = [target+3] + dy (chr_beside_offsets 0215, 2 bytes per orientation), byte 2 =
 * the orientation to face on arrival (((o ror 2) xor 80h) & C0h) | [target+4].  The slot is located
 * as a pseudo record ([slot+4] = [target+4] meanwhile): outside the height buffer -> accepted; inside
 * -> accepted when (z - floor base(z) - ([cell] & EFh) + 1) < 6 (8 bit).  Accepted: returns slot+3
 * with FF at slot+5; rejected: returns slot with FF at slot+2.  In: B = orientation, IX = target,
 * IY = slot.  Out: IY = the next slot, B = orientation & 3, C = byte 2. */
uint16_t chr_path_add_target_beside(uint16_t target, uint16_t slot, uint8_t *orient)
{
    uint8_t o, byte2, c, z;
    uint16_t off, cell;
    bool outside;
    o = (uint8_t)(*orient & 3);
    *orient = o;
    off = util_add_bx_al(D64_CHR_BESIDE_OFFSETS, (uint8_t)(o + o));
    byte2 = (uint8_t)(((uint8_t)((o >> 2) | (o << 6)) ^ 0x80) & 0xC0);
    byte2 = (uint8_t)(byte2 | rb((uint16_t)(target + 4)));
    wb((uint16_t)(slot + 4), rb((uint16_t)(target + 4)));
    wb((uint16_t)(slot + 2), (uint8_t)(rb((uint16_t)(target + 2)) + rb(off)));
    wb((uint16_t)(slot + 3), (uint8_t)(rb((uint16_t)(target + 3)) + rb((uint16_t)(off + 1))));
    cell = target;
    outside = iso_grid_cell_of(slot, &cell);
    wb((uint16_t)(slot + 4), byte2);
    if (!outside) {
        c = (uint8_t)(rb(cell) & 0xEF);                  /* the 10h mark of other characters ignored */
        z = rb((uint16_t)(target + 4));
        if ((uint8_t)(z - iso_floor_base(z) - c + 1) >= 6) {
            wb((uint16_t)(slot + 2), 0xFF);
            return slot;
        }
    }
    slot = (uint16_t)(slot + 3);
    wb((uint16_t)(slot + 2), 0xFF);
    return slot;
}

/* 04A0 ai_update_berengar (PC 1000:0C2A): driver of Berengar (record 2BC3, places 3837): 5495, doors
 * mask 3Fh, chr_update(272B), JP ai_plan_route.  In: sp. */
void ai_update_berengar(uint16_t sp)
{
    wb(D64_AI_NO_ROUTE, 0);
    ai_berengar_think(D64_CHR_BERENGAR);                         /* CALL 5495 (IY, IX, A = 0) */
    obj_set_door_permissions(0x3F);
    (void)chr_update(D64_CHR_TABLE_BERENGAR);
    ai_plan_route(rw(D64_CHR_CUR_DATA), D64_AI_BERENGAR_PLACES, sp);   /* IY = the record chr_update worked on */
}

/* 04C1 ai_update_severin (PC 1000:0C4B): driver of Severin (record 2BD2, places 384F): 571C, doors
 * mask 2Fh, chr_update(2735), JP ai_plan_route.  In: sp. */
void ai_update_severin(uint16_t sp)
{
    wb(D64_AI_NO_ROUTE, 0);
    ai_severin_think(D64_CHR_SEVERIN);                         /* CALL 571C (IY, IX, A = 0) */
    obj_set_door_permissions(0x2F);
    (void)chr_update(D64_CHR_TABLE_SEVERIN);
    ai_plan_route(rw(D64_CHR_CUR_DATA), D64_AI_SEVERIN_PLACES, sp);   /* IY = the record chr_update worked on */
}

/* 04E2 ai_check_planned_move (PC 1000:0C6A): the character has a planned move; if the last move
 * attempt failed (chr_moved [2912] != FF) its commands are discarded (JP NZ chr_cmd_discard) so that
 * a new route is planned.  In: IY = chr.  Reached only by JP (03B0). */
void ai_check_planned_move(uint16_t chr)
{
    if (rb(D64_CHR_MOVED) != 0xFF) chr_cmd_discard(chr);
}

/* 04EB ai_update_adso (PC 1000:0C72): driver of Adso (record 2B96, places 3861): ai_adso_think 58F7,
 * doors mask 3Ch, chr_update(270D).  With a destination ([3860] != FF) he goes there like a monk
 * (JP ai_plan_route).  Following Guillermo: nothing while the camera follows another character
 * ([37DC] >= 2).  A planned move that failed is counted in [28FB] up to 10, then discarded (falls into
 * chr_cmd_discard).  No plan: sys_key_down(17h) and f_3D05 (XOR A: always Z, never stops him);
 * [2907] = 0; Adso outside the height buffer -> chr_path_find(Adso, Guillermo's position 2B89) and,
 * when found, the driver runs again (JP 04EB).  Key 0 down and one of the cells ahead of Guillermo
 * (chr_probe_ahead_flat, bit 20h of 2917/2918/291B/291C) holds Adso -> JP 410D (he steps aside); key 2
 * -> JP 40EB; both run the driver again (JP 04EB) when Adso moved.  Else both are taken out of the
 * buffer, a grid search from Guillermo to Adso (3F92) gives the path length [3F82]; both are marked
 * again; a long enough path (4 when Adso uses one cell or shares no coordinate with Guillermo, else 3)
 * writes one step in orientation [3F81] (41A8) and the driver runs again.  Every JP 04EB keeps the SP:
 * a loop here.  In: sp. */
void ai_update_adso(uint16_t sp)
{
    uint16_t chr, cell, xy, step;
    uint8_t count, need, code, found, ahead2;
    for (;;) {
        wb(D64_AI_NO_ROUTE, 0);
        ai_adso_think(D64_CHR_ADSO);                     /* CALL 58F7 (IY, IX, A = 0) */
        obj_set_door_permissions(0x3C);
        (void)chr_update(D64_CHR_TABLE_ADSO);
        chr = rw(D64_CHR_CUR_DATA);                      /* IY = the record chr_update worked on */
        if (rb(D64_AI_ADSO_DEST) != 0xFF) {
            ai_plan_route(chr, D64_AI_ADSO_PLACES, sp);  /* 050E JP NZ,03AC */
            return;
        }
        if (rb(D64_GAME_CAMERA_OTHER) >= 2) return;
        if (!(rb((uint16_t)(chr + 9)) & 0x80)) {
            if (rb(D64_CHR_MOVED) == 0xFF) return;
            count = (uint8_t)(rb(D64_AI_ADSO_BLOCKED_COUNT) + 1);
            wb(D64_AI_ADSO_BLOCKED_COUNT, count);
            if (count < 10) return;
            wb(D64_AI_ADSO_BLOCKED_COUNT, 0);
            chr_cmd_discard(chr);                        /* 052E: falls into it */
            return;
        }
        (void)sys_key_down(0x17, &code);                 /* 053F */
        if (!util_return_zero()) return;                 /* 0544 CALL 3D05 / RET NZ */
        wb(D64_CHR_PATH_RESULT, 0);
        if (iso_grid_cell_of(D64_CHR_ADSO, &cell)) {
            /* 05EF: outside the buffer: route to Guillermo */
            if (chr_path_find(D64_CHR_ADSO, (uint16_t)(D64_CHR_GUILLERMO + 2), (uint16_t)(sp - 2))) continue;
            return;
        }
        found = sys_key_down(0, &code);                  /* 0556 */
        if (found) {
            ahead2 = code;                               /* 0561: B = A; C, HL as sys_key_down leaves them */
            step = 0;
            (void)chr_probe_ahead_flat(D64_CHR_GUILLERMO, found, &ahead2, &step);
            if ((rb((uint16_t)(D64_CHR_PROBE + 1)) | rb((uint16_t)(D64_CHR_PROBE + 2))
                 | rb((uint16_t)(D64_CHR_PROBE + 5)) | rb((uint16_t)(D64_CHR_PROBE + 6))) & 0x20) {
                if (chr_adso_step_aside(D64_CHR_ADSO, sp, cell)) continue;   /* JP 410D: Adso steps aside */
                return;
            }
        }
        if (sys_key_down(2, &code)) {                    /* 0579 */
            if (chr_adso_step_guillermo_dir(D64_CHR_ADSO, sp, cell)) continue;   /* JP 40EB */
            return;
        }
        /* 0581: grid search from Guillermo to Adso */
        (void)chr_mark_hbuf(D64_CHR_GUILLERMO, 0, cell);
        (void)chr_mark_hbuf(D64_CHR_ADSO, 0, cell);
        xy = rw((uint16_t)(D64_CHR_ADSO + 2));
        chr_to_hbuf_coords(&xy);
        ww(D64_CHR_PATH_DEST, xy);
        xy = rw((uint16_t)(D64_CHR_GUILLERMO + 2));
        chr_to_hbuf_coords(&xy);
        ww(D64_CHR_PATH_ORIGIN, xy);
        ww(D64_CHR_PATH_SOLUTION, chr_path_room_to_marked((uint16_t)(sp - 2)));   /* 05A5 */
        chr_path_clear_grid_marks();
        (void)chr_mark_hbuf(D64_CHR_GUILLERMO, rb((uint16_t)(D64_CHR_GUILLERMO + 0x0E)), cell);
        (void)chr_mark_hbuf(D64_CHR_ADSO, rb((uint16_t)(D64_CHR_ADSO + 0x0E)), cell);
        if (rb(D64_CHR_PATH_RESULT) == 0) return;
        need = 4;
        if (!(rb((uint16_t)(D64_CHR_ADSO + 5)) & 0x80)) {
            need = 3;
            xy = rw((uint16_t)(D64_CHR_GUILLERMO + 2));
            if (rb((uint16_t)(D64_CHR_ADSO + 2)) != (uint8_t)xy
                && rb((uint16_t)(D64_CHR_ADSO + 3)) != (uint8_t)(xy >> 8))
                need = 4;
        }
        if (rb(D64_CHR_PATH_LENGTH) < need) return;
        chr_cmd_write_one_step(D64_CHR_ADSO, rb(D64_CHR_PATH_ORIENTATION), (uint16_t)(sp - 2));   /* 05E9 */
    }                                                    /* 05EC JP 04EB */
}

/* 052E chr_cmd_discard (PC 1000:0CC0): writes command 10h ('think again') at the start of the
 * character's command buffer [[chr+0Ch]] and clears the bit counter [chr+9] and the index [chr+0Bh].
 * In: IY = chr.  Out: HL = the buffer. */
uint16_t chr_cmd_discard(uint16_t chr)
{
    uint16_t buf = rw((uint16_t)(chr + 0x0C));
    wb(buf, 0x10);
    wb((uint16_t)(chr + 9), 0);
    wb((uint16_t)(chr + 0x0B), 0);
    return buf;
}

/* ================================================================================ the path search */

static bool path_room_to_room(uint16_t chr, uint16_t room, uint16_t sp);
static bool path_search_to_marks(uint16_t chr, uint16_t sp);
static bool path_check_result(uint16_t chr, uint16_t solution, uint16_t sp);

/* 05FA chr_path_find (PC 1000:0DA5): route character chr towards the target position target (x, y,
 * orient<<6 | z).  chr_path_result [2907] = FE; returns false at once while Guillermo is in mid-step
 * ([0600] odd) or when a route was already found in this iteration ([28FA]).  Else the floor test of
 * the room search [440D] = BIT 6,(HL), [2907] = 0, chr_path_room_links_ptr [3F73] = the room links of
 * the character's floor.  Other floor: if the character's room has stairs in the wanted direction
 * (bit 10h up / 20h down), every grid cell of height [0692] (0Dh / 01h) becomes a target and the search
 * goes on at 076D; else the room graph (4399, with the test BIT 4 / BIT 5,(HL)) gives the nearest room
 * with stairs (DE) and the route continues room to room (0734).  Same floor: another room ->
 * chr_path_via_rooms; the same cell -> [2907] = FD and chr_path_face_target (falls into it); another
 * cell -> the grid towards it (chr_path_search_to_dest).  In: IY = chr, IX = target, sp.  Out: CF =
 * a route was found (or chr_path_face_target's carry). */
bool chr_path_find(uint16_t chr, uint16_t target, uint16_t sp)
{
    uint8_t chr_base, target_base, want, room, dx, dy;
    uint16_t links, p, n, xy, found;
    wb(D64_CHR_PATH_RESULT, 0xFE);
    if (rb(D64_CHR_GUILLERMO_ANIM_COPY) & 1) return false;
    if (rb(D64_CHR_PATH_FOUND_NOW) != 0) return false;
    wb(D64_CHR_PATH_FLOOR_TARGET_TEST, D64_BIT6_HL);
    wb(D64_CHR_PATH_RESULT, 0);
    chr_base = iso_floor_base(rb((uint16_t)(chr + 4)));
    target_base = iso_floor_base((uint8_t)(rb((uint16_t)(target + 2)) & 0x3F));
    links = chr_base == 0 ? D64_CHR_ROOM_LINKS : chr_base == 0x0B ? D64_CHR_ROOM_LINKS_FLOOR1 : D64_CHR_ROOM_LINKS_FLOOR2;
    ww(D64_CHR_PATH_ROOM_LINKS_PTR, links);

    if (chr_base != target_base) {
        /* 0638: another floor */
        want = chr_base < target_base ? 0x10 : 0x20;
        room = (uint8_t)((rb((uint16_t)(chr + 3)) & 0xF0) | (rb((uint16_t)(chr + 2)) >> 4));
        p = util_add_bx_al(links, room);
        if (!(rb(p) & want)) {
            /* 0657: no stairs here: the room graph gives the nearest room with them */
            wb(D64_CHR_PATH_FLOOR_TARGET_TEST, want == 0x10 ? D64_BIT4_HL : D64_BIT5_HL);
            ww(D64_CHR_PATH_ORIGIN, chr_room_coords(chr));
            (void)chr_path_floor_search((uint16_t)(sp - 2), &found);   /* 0668 */
            chr_path_clear_room_marks();
            wb(D64_CHR_PATH_FLOOR_TARGET_TEST, D64_BIT6_HL);
            if (rb(D64_CHR_PATH_RESULT) == 0) return false;
            return path_room_to_room(chr, found, sp);    /* 0678 EX DE,HL / JP 0734 */
        }
        /* 067C: stairs in this room: their cells are the targets */
        wb(D64_CHR_STAIRS_HEIGHT, want == 0x10 ? 0x0D : 0x01);
        chr_path_build_grid(chr);
        for (p = D64_CHR_PATH_GRID, n = D64_CHR_HBUF_SIZE; n; n--, p++)
            if (rb(p) == rb(D64_CHR_STAIRS_HEIGHT)) wb(p, (uint8_t)(rb(p) | 0x40));
        ww(D64_CHR_PATH_DEST, 0);                        /* BC = 0 after the loop */
        chr_path_reset_alternatives();
        return path_search_to_marks(chr, sp);            /* 06A4 JP 076D */
    }

    /* 06A7: same floor */
    xy = rw(target);
    dx = (uint8_t)(rb((uint16_t)(chr + 2)) ^ (uint8_t)xy);
    if (dx & 0xF0) return chr_path_via_rooms(chr, xy, sp);
    dy = (uint8_t)(rb((uint16_t)(chr + 3)) ^ (uint8_t)(xy >> 8));
    if (dy & 0xF0) return chr_path_via_rooms(chr, xy, sp);
    wb(D64_CHR_PATH_RESULT, 0xFD);
    if ((dx | dy) == 0) return chr_path_face_target(chr, target);
    /* 06EC: same room, another cell */
    wb(D64_CHR_PATH_RESULT, 0);
    chr_path_build_grid(chr);
    chr_to_hbuf_coords(&xy);
    ww(D64_CHR_PATH_DEST, xy);
    return chr_path_search_to_dest(chr, sp);             /* 06FB JP 077E */
}

/* 06C8 chr_path_face_target (PC 1000:0EA5): the character stands on the target cell.  Wanted
 * orientation = [target+2] >> 6; already facing it -> false (CP equal).  Else chr_cmd_rewind, the turn
 * commands (432C: from [chr+1] to the wanted one), the 12-bit command 1000h (chr_cmd_write_bits) and
 * falls into chr_cmd_rewind: returns chr_cmd_write_bits' carry.  In: IY = chr, IX = target.
 * Out: CF (ZF set). */
bool chr_path_face_target(uint16_t chr, uint16_t target)
{
    uint8_t wanted = (uint8_t)(rb((uint16_t)(target + 2)) >> 6);
    uint8_t cur = rb((uint16_t)(chr + 1));
    uint16_t bits = 0x1000;
    bool carry;
    if (cur == wanted) return false;
    chr_cmd_rewind(chr);
    (void)chr_cmd_write_turn(chr, cur, wanted);          /* 06D8 */
    chr_cmd_write_bits(chr, &bits, 12, &carry);
    chr_cmd_rewind(chr);
    return carry;
}

/* 06E3 chr_cmd_rewind (PC 1000:0EC6): [chr+9] = [chr+0Bh] = 0 (bit counter and index of the command
 * buffer).  In: IY = chr. */
void chr_cmd_rewind(uint16_t chr)
{
    wb((uint16_t)(chr + 9), 0);
    wb((uint16_t)(chr + 0x0B), 0);
}

/* 06FE chr_room_coords (PC 1000:0EE3): room coordinates of record rec: L = [rec+2] >> 4, H = [rec+3]
 * >> 4.  In: IY = rec.  Out: HL (A = H). */
uint16_t chr_room_coords(uint16_t rec)
{
    uint8_t x = (uint8_t)(rb((uint16_t)(rec + 2)) >> 4), y = (uint8_t)(rb((uint16_t)(rec + 3)) >> 4);
    return (uint16_t)(y << 8 | x);
}

/* 0713 chr_path_clear_room_marks (PC 1000:0F02): AND 3Fh over the 130h bytes of room links 023D-036C
 * (the marks the room-graph search leaves in bits 6-7). */
void chr_path_clear_room_marks(void)
{
    uint16_t p, n;
    for (p = D64_CHR_ROOM_LINKS, n = D64_CHR_ROOM_LINKS_SIZE; n; n--, p++) wb(p, (uint8_t)(rb(p) & 0x3F));
}

/* 0724 chr_path_via_rooms (PC 1000:0F17): target in another room of the same floor: target_xy >> 4
 * (both bytes) is the destination room, then label 0734.  In: IY = chr, HL = target x, y, sp.  Out: CF
 * as chr_path_find's.  Reached only by JR (06B4, 06BD). */
bool chr_path_via_rooms(uint16_t chr, uint16_t target_xy, uint16_t sp)
{
    uint8_t x = (uint8_t)((uint8_t)target_xy >> 4), y = (uint8_t)((uint8_t)(target_xy >> 8) >> 4);
    return path_room_to_room(chr, (uint16_t)(y << 8 | x), sp);
}

/* Label 0734 (PC 0F27, chr_path_room_to_room; also JP from 0679 with the room 4399 found):
 * chr_path_origin [2903] = destination room, chr_path_dest [2905] = the character's room, the room
 * graph search 438F, chr_path_clear_room_marks; nothing found -> false.  Found: entry [3F81] of
 * chr_exit_table 08FA (routine word, grid target word): [076B] = routine, chr_path_reset_alternatives,
 * [2905] = target, chr_path_build_grid, CALL [076B] (marks the exit band), then label 076D. */
static bool path_room_to_room(uint16_t chr, uint16_t room, uint16_t sp)
{
    uint16_t e;
    ww(D64_CHR_PATH_ORIGIN, room);
    ww(D64_CHR_PATH_DEST, chr_room_coords(chr));
    (void)chr_path_floor_to_screen((uint16_t)(sp - 2));  /* 073D */
    chr_path_clear_room_marks();
    if (rb(D64_CHR_PATH_RESULT) == 0) return false;
    e = (uint16_t)(D64_CHR_EXIT_TABLE + (uint8_t)(rb(D64_CHR_PATH_ORIENTATION) * 4));
    ww(D64_CHR_EXIT_MARK_ROUTINE, rw(e));
    chr_path_reset_alternatives();
    ww(D64_CHR_PATH_DEST, rw((uint16_t)(e + 2)));
    chr_path_build_grid(chr);
    switch (rw(D64_CHR_EXIT_MARK_ROUTINE)) {             /* 076A CALL [076B] (chr_exit_table) */
    case 0x090A: chr_path_mark_exit_up(); break;
    case 0x091C: chr_path_mark_exit_right(); break;
    case 0x0924: chr_path_mark_exit_left(); break;
    case 0x0929: chr_path_mark_exit_down(); break;
    default: break;                                      /* the table 08FA holds only those four */
    }
    return path_search_to_marks(chr, sp);
}

/* Label 076D (PC 0F71, chr_path_search_to_marks): [2903] = the character's cell in grid coordinates
 * (stored whatever CF), the grid search 3F92 towards [2905] or any bit-6 cell, then label 078D. */
static bool path_search_to_marks(uint16_t chr, uint16_t sp)
{
    uint16_t pos = rw((uint16_t)(chr + 2));
    chr_to_hbuf_coords(&pos);
    ww(D64_CHR_PATH_ORIGIN, pos);
    return path_check_result(chr, chr_path_room_to_marked((uint16_t)(sp - 2)), sp);   /* 0779, 077C JR 078D */
}

/* 077E chr_path_search_to_dest (PC 1000:0F83): [2903] = the character's cell in grid coordinates
 * (stored whatever CF), the grid search 3F9E towards [2905], then label 078D.  In: IY = chr, sp.
 * Out: CF as chr_path_find's.  Reached by JP 06FB and by its own retry (JR 07D4). */
bool chr_path_search_to_dest(uint16_t chr, uint16_t sp)
{
    uint16_t pos = rw((uint16_t)(chr + 2));
    chr_to_hbuf_coords(&pos);
    ww(D64_CHR_PATH_ORIGIN, pos);
    return path_check_result(chr, chr_path_room_search((uint16_t)(sp - 2)), sp);   /* 078A */
}

/* Label 078D (PC 0F93, chr_path_check_result): chr_path_solution [41D4] = solution.  Found ([2907] !=
 * 0, 07DB): chr_path_found_now [28FA] = 1, chr_path_clear_grid_marks, chr_cmd_generate 434F, falls
 * into chr_path_restore_screen_grid: true.  Else the next candidate ([0213] += 3): FF -> restore and
 * false (AND A); else chr_path_clear_grid_marks, [2907] = FD, the character on that candidate ->
 * chr_path_face_target (flags kept by PUSH AF / POP AF) and the same false exit; else [2907] = 0,
 * [2905] = the candidate in grid coordinates, retry 077E. */
static bool path_check_result(uint16_t chr, uint16_t solution, uint16_t sp)
{
    uint16_t cand, xy, pos;
    for (;;) {
        ww(D64_CHR_PATH_SOLUTION, solution);
        if (rb(D64_CHR_PATH_RESULT) != 0) {
            wb(D64_CHR_PATH_FOUND_NOW, 1);
            chr_path_clear_grid_marks();                 /* leaves C = 0, HL = the end of the buffer */
            chr_cmd_generate(chr, 0, (uint16_t)(rw(D64_CHR_HBUF_PTR) + D64_CHR_HBUF_SIZE), (uint16_t)(sp - 2));   /* 07E3 */
            chr_path_restore_screen_grid();              /* falls into 07E6: SCF */
            return true;
        }
        cand = (uint16_t)(rw(D64_CHR_PATH_ALT_PTR) + 3);
        ww(D64_CHR_PATH_ALT_PTR, cand);
        if (rb(cand) == 0xFF) {
            chr_path_restore_screen_grid();
            return false;                                /* 07D9 AND A */
        }
        chr_path_clear_grid_marks();
        xy = rw(cand);
        wb(D64_CHR_PATH_RESULT, 0xFD);
        if (((rb((uint16_t)(chr + 2)) ^ (uint8_t)xy) | (rb((uint16_t)(chr + 3)) ^ (uint8_t)(xy >> 8))) == 0) {
            chr_path_face_target(chr, cand);             /* 07C4 CALL Z,06C8 */
            chr_path_restore_screen_grid();
            return false;
        }
        wb(D64_CHR_PATH_RESULT, 0);
        chr_to_hbuf_coords(&xy);
        ww(D64_CHR_PATH_DEST, xy);
        /* 07D4 JR 077E */
        pos = rw((uint16_t)(chr + 2));
        chr_to_hbuf_coords(&pos);
        ww(D64_CHR_PATH_ORIGIN, pos);
        solution = chr_path_room_search((uint16_t)(sp - 2));   /* 078A */
    }
}

/* 07E6 chr_path_restore_screen_grid (PC 1000:0FF4): chr_hbuf_ptr [28DB] = AE2E (the screen height
 * buffer), iso_grid_set_origin(camera pseudo record 28C4), chr_shown_floor [290B] = [28C8].
 * Out: CF = 1 (SCF), A = [28C8] (returned), B = iso_grid_set_origin's B. */
uint8_t chr_path_restore_screen_grid(void)
{
    uint8_t z;
    ww(D64_CHR_HBUF_PTR, D64_CHR_HEIGHT_BUFFER);
    iso_grid_set_origin(D64_ISO_CAMERA_RECORD);
    z = rb((uint16_t)(D64_ISO_CAMERA_RECORD + 4));
    wb(D64_CHR_SHOWN_FLOOR, z);
    return z;
}

/* 07FF iso_grid_set_origin (PC 1000:100B): grid origin for the room of record rec: the operands of
 * chr_to_hbuf_coords [22FE] = ([rec+2] & F0) - 4 (x) and [22F2] = ([rec+3] & F0) - 4 (y);
 * chr_shown_floor [290B] = iso_floor_base([rec+4]), returned.  In: IY = rec.  Out: A = B = the floor
 * base (flags of 2097). */
uint8_t iso_grid_set_origin(uint16_t rec)
{
    uint8_t base;
    wb(D64_CHR_HBUF_ORIGIN_X, (uint8_t)((rb((uint16_t)(rec + 2)) & 0xF0) - 4));
    wb(D64_CHR_HBUF_ORIGIN_Y, (uint8_t)((rb((uint16_t)(rec + 3)) & 0xF0) - 4));
    base = iso_floor_base(rb((uint16_t)(rec + 4)));
    wb(D64_CHR_SHOWN_FLOOR, base);
    return base;
}

/* 081E chr_path_clear_grid_marks (PC 1000:102B): AND 3Fh over the 240h bytes of the height buffer
 * [28DB] (the search marks in bits 6-7). */
void chr_path_clear_grid_marks(void)
{
    uint16_t p = rw(D64_CHR_HBUF_PTR), n;
    for (n = D64_CHR_HBUF_SIZE; n; n--, p++) wb(p, (uint8_t)(rb(p) & 0x3F));
}

/* 082F chr_path_build_grid (PC 1000:1041): chr_hbuf_ptr [28DB] = 8174 (chr_path_grid);
 * chr_fill_height_buffer (2873) for chr; then, if Guillermo, or else the camera room (28C6-28C8), is
 * within one room of chr in x and y (chr_room_distance_near) and on its floor: chr_grid_owner [08A0] =
 * chr, the records of 5 chr_table entries from 270F (6 from 2705 when both distances are 1) except chr
 * get the mark 10h (chr_mark_hbuf), the leaves of the open doors (bit 6 of [door+1]) get height 0Fh
 * (obj_door_mark_cells 0A89) and the cells of chr are cleared (chr_mark_hbuf with 0).  In: IY = chr. */
void chr_path_build_grid(uint16_t chr)
{
    uint8_t dx = 0, dy = 0, n, base;
    bool adjacent, mark = false;
    uint16_t e, rec, door, cell = 0;
    ww(D64_CHR_HBUF_PTR, D64_CHR_PATH_GRID);
    chr_fill_height_buffer(chr);                         /* 0836 */
    dx = chr_room_distance_near(rb((uint16_t)(D64_CHR_GUILLERMO + 2)), rb((uint16_t)(chr + 2)), &adjacent);
    if (adjacent) {
        dy = chr_room_distance_near(rb((uint16_t)(D64_CHR_GUILLERMO + 3)), rb((uint16_t)(chr + 3)), &adjacent);
        if (adjacent) {
            base = iso_floor_base(rb((uint16_t)(chr + 4)));
            mark = iso_floor_base(rb((uint16_t)(D64_CHR_GUILLERMO + 4))) == base;
        }
    }
    if (!mark) {
        /* 0864: near the camera room? */
        dx = chr_room_distance_near(rb(D64_CHR_ROOM_X), rb((uint16_t)(chr + 2)), &adjacent);
        if (!adjacent) return;
        dy = chr_room_distance_near(rb(D64_CHR_ROOM_Y), rb((uint16_t)(chr + 3)), &adjacent);
        if (!adjacent) return;
        if (rb(D64_CHR_ROOM_Z) != iso_floor_base(rb((uint16_t)(chr + 4)))) return;
    }
    /* 0887 */
    ww(D64_CHR_GRID_OWNER, chr);
    e = (uint16_t)(D64_CHR_TABLE + 0x0C);
    n = 5;
    if (dx == 1 && dy == 1) {
        e = (uint16_t)(D64_CHR_TABLE + 2);
        n = 6;
    }
    do {
        rec = rw(e);
        if (rec != rw(D64_CHR_GRID_OWNER)) (void)chr_mark_hbuf(rec, 0x10, 0);
        e = (uint16_t)(e + 10);
    } while (--n);
    door = D64_OBJ_DOORS;
    do {
        if (rb((uint16_t)(door + 1)) & 0x40) (void)obj_door_mark_cells(door, 0x0F, &cell);   /* 08CC */
        door = (uint16_t)(door + 5);
    } while (rb(door) != 0xFF);
    (void)chr_mark_hbuf(rw(D64_CHR_GRID_OWNER), 0, 0);
}

/* The loop 0910 shared by the four exit bands: bit 6 in 16 cells of [28DB] + offset, step step. */
static void mark_band(uint16_t offset, uint16_t step)
{
    uint16_t p = (uint16_t)(rw(D64_CHR_HBUF_PTR) + offset);
    uint8_t n;
    for (n = 16; n; n--) {
        wb(p, (uint8_t)(rb(p) | 0x40));
        p = (uint16_t)(p + step);
    }
}

/* 090A chr_path_mark_exit_up (PC 1000:1128): exit band towards -y: row 3, x = 4..19 (offset 4Ch, step
 * +1).  Called through chr_exit_mark_routine [076B]. */
void chr_path_mark_exit_up(void)
{
    mark_band(0x4C, 1);
}

/* 091C chr_path_mark_exit_right (PC 1000:1140): exit band towards +x: column 20, y = 4..19 (74h, +24). */
void chr_path_mark_exit_right(void)
{
    mark_band(0x74, 0x18);
}

/* 0924 chr_path_mark_exit_left (PC 1000:1148): exit band towards -x: column 3, y = 4..19 (63h, +24). */
void chr_path_mark_exit_left(void)
{
    mark_band(0x63, 0x18);
}

/* 0929 chr_path_mark_exit_down (PC 1000:114D): exit band towards +y: row 20, x = 4..19 (1E4h, +1). */
void chr_path_mark_exit_down(void)
{
    mark_band(0x1E4, 1);
}

/* 092E iso_grid_cell_of (PC 1000:1152): the cell of record rec (x +2, y +3, z +4) in the height buffer
 * in use.  Another floor than chr_shown_floor [290B] (SCF) or outside the 24x24 window
 * (chr_to_hbuf_coords' carry) -> true, *cell unchanged.  Else falls into iso_grid_cell_ptr: *cell =
 * its address, false.  In: IY = rec.  Out: CF; IX = the cell when CF = 0. */
bool iso_grid_cell_of(uint16_t rec, uint16_t *cell)
{
    uint16_t xy, idx, lo;
    if (rb(D64_CHR_SHOWN_FLOOR) != iso_floor_base(rb((uint16_t)(rec + 4)))) return true;
    xy = rw((uint16_t)(rec + 2));
    if (chr_to_hbuf_coords(&xy)) return true;
    *cell = iso_grid_cell_ptr((uint8_t)xy, (uint8_t)(xy >> 8), &idx, &lo);
    return false;
}

/* 0959 chr_cmd_write_bits (PC 1000:118E): appends the n most significant bits of *bits (n = 0: 256)
 * to the command stream of chr, MSB first: when the bit counter [chr+9] is 8 the byte [chr+0Ah] is
 * stored at word [chr+0Ch] + [chr+0Bh], the index [chr+0Bh] is incremented and the counter cleared;
 * then *bits is shifted left and its bit 15 rotated into [chr+0Ah] (RL), counter + 1.  In: IY = chr,
 * HL = bits, B = n.  Out: HL = *bits, B = 0, A as the last pass leaves it (the counter read, or the
 * byte stored), CF = *carry = bit 7 of [chr+0Ah] before the last RL. */
uint8_t chr_cmd_write_bits(uint16_t chr, uint16_t *bits, uint8_t n, bool *carry)
{
    uint8_t a, v, idx, in;
    uint16_t p;
    do {
        a = rb((uint16_t)(chr + 9));
        if (a == 8) {
            wb((uint16_t)(chr + 9), 0);
            idx = rb((uint16_t)(chr + 0x0B));
            p = (uint16_t)(rw((uint16_t)(chr + 0x0C)) + idx);
            wb((uint16_t)(chr + 0x0B), (uint8_t)(idx + 1));
            a = rb((uint16_t)(chr + 0x0A));
            wb(p, a);
        }
        in = (uint8_t)(*bits >> 15);
        *bits = (uint16_t)(*bits << 1);
        v = rb((uint16_t)(chr + 0x0A));
        wb((uint16_t)(chr + 0x0A), (uint8_t)(v << 1 | in));
        *carry = (v & 0x80) != 0;
        wb((uint16_t)(chr + 9), (uint8_t)(rb((uint16_t)(chr + 9)) + 1));
    } while (--n);
    return a;
}

#ifndef JUEGO_PURO  /* the hybrid host */
/* ================================================================================ hybrid host */

static int compara8(const char *nombre, uint8_t c, uint8_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %02X Z80 %02X", nombre, c, z);
    return 0;
}

static int compara16(const char *nombre, uint16_t c, uint16_t z, char *msg, size_t n)
{
    if (c == z) return 1;
    snprintf(msg + strlen(msg), n - strlen(msg), " %s C %04X Z80 %04X", nombre, c, z);
    return 0;
}

static int r_cf(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    return compara8("CF", cz->cf, zz->cf, msg, n);
}

static int r_ixiy(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = compara16("IX", cz->ix, zz->ix, msg, n);
    ok &= compara16("IY", cz->iy, zz->iy, msg, n);
    return ok;
}

/* every main and index register (the flags apart) */
static int r_regs(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = compara8("A", cz->a, zz->a, msg, n);
    ok &= compara16("BC", (uint16_t)(cz->b << 8 | cz->c), (uint16_t)(zz->b << 8 | zz->c), msg, n);
    ok &= compara16("DE", (uint16_t)(cz->d << 8 | cz->e), (uint16_t)(zz->d << 8 | zz->e), msg, n);
    ok &= compara16("HL", (uint16_t)(cz->h << 8 | cz->l), (uint16_t)(zz->h << 8 | zz->l), msg, n);
    ok &= r_ixiy(cz, zz, msg, n);
    return ok;
}

static int r_regs_cf(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = r_regs(cz, zz, msg, n);
    ok &= r_cf(cz, zz, msg, n);
    return ok;
}

/* the drivers: nothing for the caller (2226) */
static void w_036D(void) { uint16_t sp = cpu.sp; ai_update_malachi(sp); cpu.sp = sp; z80_ret(); }
static void w_038E(void) { uint16_t sp = cpu.sp; ai_update_abbot(sp); cpu.sp = sp; z80_ret(); }
static void w_04A0(void) { uint16_t sp = cpu.sp; ai_update_berengar(sp); cpu.sp = sp; z80_ret(); }
static void w_04C1(void) { uint16_t sp = cpu.sp; ai_update_severin(sp); cpu.sp = sp; z80_ret(); }
static void w_04EB(void) { uint16_t sp = cpu.sp; ai_update_adso(sp); cpu.sp = sp; z80_ret(); }

/* 042D: IX = target, IY = the last slot */
static void w_042D(void)
{
    uint16_t sp = cpu.sp, target = HL;
    uint16_t slot = chr_path_add_targets_around(target, DE);
    cpu.ix = target;
    cpu.iy = slot;
    cpu.sp = sp;
    z80_ret();
}

/* 0442: IX = target (kept), IY = the next slot, B = orientation & 3 (042D goes on with INC B) */
static void w_0442(void)
{
    uint16_t sp = cpu.sp;
    uint8_t o = cpu.b;
    uint16_t target = cpu.ix;
    uint16_t slot = chr_path_add_target_beside(target, cpu.iy, &o);
    cpu.ix = target;
    cpu.iy = slot;
    cpu.b = o;
    cpu.sp = sp;
    z80_ret();
}

static int r_0442(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = r_ixiy(cz, zz, msg, n);
    ok &= compara8("B", cz->b, zz->b, msg, n);
    return ok;
}

static void w_04E2(void) { ai_check_planned_move(cpu.iy); z80_ret(); }

/* 052E: HL = the command buffer, the rest kept (the script code after 5FCD goes on with them) */
static void w_052E(void)
{
    uint16_t buf = chr_cmd_discard(cpu.iy);
    SET_HL(buf);
    z80_ret();
}

/* the searches: CF = a route was found (05F6 JP C) */
static void w_05FA(void)
{
    uint16_t sp = cpu.sp;
    bool r = chr_path_find(cpu.iy, cpu.ix, sp);
    cpu.sp = sp;
    cpu.cf = r;
    z80_ret();
}

static void w_06C8(void)
{
    uint16_t sp = cpu.sp;
    bool r = chr_path_face_target(cpu.iy, cpu.ix);
    cpu.sp = sp;
    cpu.cf = r;
    cpu.zf = 1;
    z80_ret();
}

static int r_06C8(const z80 *cz, const z80 *zz, char *msg, size_t n)
{
    int ok = compara8("CF", cz->cf, zz->cf, msg, n);
    ok &= compara8("ZF", cz->zf, zz->zf, msg, n);
    return ok;
}

static void w_06E3(void) { chr_cmd_rewind(cpu.iy); z80_ret(); }

static void w_06FE(void)
{
    uint16_t hl = chr_room_coords(cpu.iy);
    SET_HL(hl);
    cpu.a = (uint8_t)(hl >> 8);
    z80_ret();
}

/* 0713, 081E: the loops leave BC = 0, HL = the end, A = 0 (LD A,B / OR C) */
static void w_0713(void)
{
    chr_path_clear_room_marks();
    SET_BC(0);
    SET_HL(D64_CHR_ROOM_LINKS + D64_CHR_ROOM_LINKS_SIZE);
    cpu.a = 0;
    z80_ret();
}

static void w_0724(void)
{
    uint16_t sp = cpu.sp;
    bool r = chr_path_via_rooms(cpu.iy, HL, sp);
    cpu.sp = sp;
    cpu.cf = r;
    z80_ret();
}

static void w_077E(void)
{
    uint16_t sp = cpu.sp;
    bool r = chr_path_search_to_dest(cpu.iy, sp);
    cpu.sp = sp;
    cpu.cf = r;
    z80_ret();
}

/* 07E6: A = [28C8], B = the floor base, HL = AE2E, IY kept (PUSH/POP), CF = 1 */
static void w_07E6(void)
{
    uint16_t sp = cpu.sp, iy = cpu.iy;
    uint8_t a = chr_path_restore_screen_grid();
    cpu.sp = sp;
    cpu.iy = iy;
    cpu.a = a;
    SET_HL(D64_CHR_HEIGHT_BUFFER);
    cpu.cf = 1;
    z80_ret();
}

/* 07FF: A = B = the floor base (2880 tests A) */
static void w_07FF(void)
{
    uint16_t sp = cpu.sp;
    uint8_t base = iso_grid_set_origin(cpu.iy);
    cpu.sp = sp;
    cpu.a = cpu.b = base;
    z80_ret();
}

static void w_081E(void)
{
    uint16_t end = (uint16_t)(rw(D64_CHR_HBUF_PTR) + D64_CHR_HBUF_SIZE);
    chr_path_clear_grid_marks();
    SET_BC(0);
    SET_HL(end);
    cpu.a = 0;
    z80_ret();
}

/* 082F: IY = chr again (08DB), the callers go on with it */
static void w_082F(void)
{
    uint16_t sp = cpu.sp, chr = cpu.iy;
    chr_path_build_grid(chr);
    cpu.sp = sp;
    cpu.iy = chr;
    z80_ret();
}

static int r_082F(const z80 *cz, const z80 *zz, char *msg, size_t n) { return compara16("IY", cz->iy, zz->iy, msg, n); }

/* the exit bands: HL = the cell after the last one, BC = the offset with B = 0, DE = the step */
static void banda(uint16_t offset, uint16_t step)
{
    SET_HL(rw(D64_CHR_HBUF_PTR) + offset + 16 * step);
    SET_BC(offset & 0xFF);
    SET_DE(step);
    z80_ret();
}

static void w_090A(void) { chr_path_mark_exit_up(); banda(0x4C, 1); }
static void w_091C(void) { chr_path_mark_exit_right(); banda(0x74, 0x18); }
static void w_0924(void) { chr_path_mark_exit_left(); banda(0x63, 0x18); }
static void w_0929(void) { chr_path_mark_exit_down(); banda(0x1E4, 1); }

/* 092E: CF; B = the floor base (2097); inside: IX = the cell and, as 0944 leaves them, DE = its index
 * 24 y + x, HL = A = x + 8 y; another floor: A = [290B]; outside the window: A, HL as 22F0 leaves them
 * (A = the coordinate that failed, minus its origin; HL = the position, H converted when x failed) */
static void w_092E(void)
{
    uint16_t sp = cpu.sp, cell = cpu.ix, idx, lo, xy;
    uint8_t base = iso_floor_base(rb((uint16_t)(cpu.iy + 4))), y, x;
    bool r = iso_grid_cell_of(cpu.iy, &cell);
    cpu.sp = sp;
    cpu.ix = cell;
    cpu.cf = r;
    cpu.b = base;
    if (!r) {
        idx = (uint16_t)(cell - rw(D64_CHR_HBUF_PTR));
        lo = (uint16_t)(idx / 24 * 8 + idx % 24);
        SET_DE(idx);
        SET_HL(lo);
        cpu.a = (uint8_t)lo;
    } else if (base != rb(D64_CHR_SHOWN_FLOOR)) {
        cpu.a = rb(D64_CHR_SHOWN_FLOOR);
    } else {
        xy = rw((uint16_t)(cpu.iy + 2));
        y = (uint8_t)(rb((uint16_t)(cpu.iy + 3)) - rb(D64_CHR_HBUF_ORIGIN_Y));
        x = (uint8_t)(rb((uint16_t)(cpu.iy + 2)) - rb(D64_CHR_HBUF_ORIGIN_X));
        cpu.a = (rb((uint16_t)(cpu.iy + 3)) < rb(D64_CHR_HBUF_ORIGIN_Y) || y < 2 || y >= 0x16) ? y : x;
        (void)chr_to_hbuf_coords(&xy);
        SET_HL(xy);
    }
    z80_ret();
}

/* 0959: HL = the bits left, B = 0, A, CF; DE = the address of the last byte stored, if any */
static void w_0959(void)
{
    uint16_t bits = HL, chr = cpu.iy;
    uint8_t idx0 = rb((uint16_t)(chr + 0x0B)), idx1;
    bool carry;
    uint8_t a = chr_cmd_write_bits(chr, &bits, cpu.b, &carry);
    SET_HL(bits);
    cpu.b = 0;
    cpu.a = a;
    cpu.cf = carry;
    idx1 = rb((uint16_t)(chr + 0x0B));
    if (idx1 != idx0) SET_DE(rw((uint16_t)(chr + 0x0C)) + (uint8_t)(idx1 - 1));
    z80_ret();
}

const traducida_t traducidas_camino[] = {
    { 0x036D, "ai_update_malachi", w_036D, sin_resultados },
    { 0x038E, "ai_update_abbot", w_038E, sin_resultados },
    { 0x042D, "chr_path_add_targets_around", w_042D, r_ixiy },
    { 0x0442, "chr_path_add_target_beside", w_0442, r_0442 },
    { 0x04A0, "ai_update_berengar", w_04A0, sin_resultados },
    { 0x04C1, "ai_update_severin", w_04C1, sin_resultados },
    { 0x04E2, "ai_check_planned_move", w_04E2, sin_resultados },
    { 0x04EB, "ai_update_adso", w_04EB, sin_resultados },
    { 0x052E, "chr_cmd_discard", w_052E, r_regs },
    { 0x05FA, "chr_path_find", w_05FA, r_cf },
    { 0x06C8, "chr_path_face_target", w_06C8, r_06C8 },
    { 0x06E3, "chr_cmd_rewind", w_06E3, r_regs },
    { 0x06FE, "chr_room_coords", w_06FE, r_regs },
    { 0x0713, "chr_path_clear_room_marks", w_0713, r_regs },
    { 0x0724, "chr_path_via_rooms", w_0724, r_cf },
    { 0x077E, "chr_path_search_to_dest", w_077E, r_cf },
    { 0x07E6, "chr_path_restore_screen_grid", w_07E6, r_regs_cf },
    { 0x07FF, "iso_grid_set_origin", w_07FF, r_regs },
    { 0x081E, "chr_path_clear_grid_marks", w_081E, r_regs },
    { 0x082F, "chr_path_build_grid", w_082F, r_082F },
    { 0x090A, "chr_path_mark_exit_up", w_090A, r_regs },
    { 0x091C, "chr_path_mark_exit_right", w_091C, r_regs },
    { 0x0924, "chr_path_mark_exit_left", w_0924, r_regs },
    { 0x0929, "chr_path_mark_exit_down", w_0929, r_regs },
    { 0x092E, "iso_grid_cell_of", w_092E, r_regs_cf },
    { 0x0959, "chr_cmd_write_bits", w_0959, r_regs_cf },
    { 0, NULL, NULL, NULL }
};
#endif

