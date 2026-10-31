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

/* abadia64ks, group camino (64K 0000-0982: the monks' AI drivers, route planning, path search, the
 * grid): the 64K data addresses its functions use.  PC names (c/include/direcciones.h) where the datum
 * is the same thing; a code address means a self-modified operand (data kept in the code). */
#ifndef DATOS_CAMINO_H
#define DATOS_CAMINO_H

/* ---- the characters (15-byte records: +1 orientation, +2 x, +3 y, +4 z, +5 bit 7 = one cell,
 *      +9 command bit counter (bit 7 = no plan), +0Ah command byte, +0Bh index, +0Ch word buffer,
 *      +0Eh mark value in the height buffer) ---- */
#define D64_CHR_GUILLERMO               0x2B87u  /* Guillermo's record; CHR_GUILLERMO */
#define D64_CHR_ADSO                    0x2B96u  /* Adso's record; CHR_ADSO */
#define D64_CHR_MALACHI                 0x2BA5u  /* Malachi's record; CHR_MALACHI */
#define D64_CHR_ABBOT                   0x2BB4u  /* the abbot's record; CHR_ABBOT */
#define D64_CHR_BERENGAR                0x2BC3u  /* Berengar's record; CHR_BERENGAR */
#define D64_CHR_SEVERIN                 0x2BD2u  /* Severin's record; CHR_SEVERIN */
#define D64_OBJ_DOORS                   0x2B35u  /* the doors, 5 bytes each (+1 bit 6 = open), FF end; OBJ_DOORS */
#define D64_OBJ_OBJECTS                 0x2B59u  /* the objects, 5 bytes each; the first is the book; OBJ_OBJECTS */
#define D64_OBJ_PARCHMENT               0x2B68u  /* the parchment (object 3, OBJ_OBJECTS + 0Fh; PC BAD5) */
#define D64_CHR_TABLE                   0x2703u  /* 6 entries x 10 bytes (sprite, data = record, ...); CHR_TABLE */
#define D64_CHR_TABLE_MALACHI           0x2717u  /* chr_table entry of Malachi (PC AE98) */
#define D64_CHR_TABLE_ABBOT             0x2721u  /* chr_table entry of the abbot (PC AEA2) */
#define D64_CHR_TABLE_BERENGAR          0x272Bu  /* chr_table entry of Berengar (PC AEAC) */
#define D64_CHR_TABLE_SEVERIN           0x2735u  /* chr_table entry of Severin (PC AEB6) */
#define D64_CHR_TABLE_ADSO              0x270Du  /* chr_table entry of Adso (PC AE8E) */
#define D64_CHR_GUILLERMO_ANIM_COPY     0x0600u  /* operand of LD A,n at 05FF: copy of [2B87] taken by the main loop (217D); odd = mid-step; CHR_GUILLERMO_ANIM_COPY */
#define D64_CHR_MOVED                   0x2912u  /* FF when the character being updated moved or turned; CHR_MOVED */

/* ---- the AI blocks ---- */
#define D64_AI_NO_ROUTE                 0x37E9u  /* cleared by each driver; not 0 = no route wanted; AI_NO_ROUTE */
#define D64_GAME_CAMERA_OTHER           0x37DCu  /* not 0 when the camera follows another character; GAME_CAMERA_OTHER */
#define D64_AI_MALACHI_PLACES           0x37F8u  /* Malachi's places, 3 bytes each; [-1] destination, [-3] reached; AI_MALACHI_PLACES */
#define D64_AI_ABBOT_PLACES             0x3816u  /* the abbot's places; AI_ABBOT_PLACES */
#define D64_AI_BERENGAR_PLACES          0x3837u  /* Berengar's places; AI_BERENGAR_PLACES */
#define D64_AI_SEVERIN_PLACES           0x384Fu  /* Severin's places; AI_SEVERIN_PLACES */
#define D64_AI_ADSO_PLACES              0x3861u  /* Adso's places; AI_ADSO_PLACES */
#define D64_AI_ADSO_DEST                0x3860u  /* Adso's destination (FF = follow Guillermo); AI_ADSO_DEST */
#define D64_AI_ADSO_BLOCKED_COUNT       0x28FBu  /* failed planned moves of Adso, 0..9; AI_ADSO_BLOCKED_COUNT */
#define D64_CHR_PROBE                   0x2916u  /* 4x4 cells in front of the character (chr_probe_ahead_flat); Adso tests +1 +2 +5 +6; CHR_PROBE */

/* ---- route planning ---- */
#define D64_CHR_PATH_SLOT               0x0201u  /* candidate slot - 2 for the four positions around a target (PC AAC1) */
#define D64_CHR_PATH_ALTERNATIVES       0x0203u  /* candidate destinations, 3 bytes each (x, y, orient<<6 | z), FF end; CHR_PATH_ALTERNATIVES */
#define D64_CHR_PATH_ALT_PTR            0x0213u  /* the candidate being tried; CHR_PATH_ALT_PTR */
#define D64_CHR_BESIDE_OFFSETS          0x0215u  /* dx, dy per orientation beside a target; CHR_BESIDE_OFFSETS */
#define D64_CHR_ROOM_LINKS              0x023Du  /* room links of the 3 floors, 130h bytes (ground floor 023D, 02ED, 02F5); CHR_ROOM_LINKS */
#define D64_CHR_ROOM_LINKS_SIZE         0x0130u
#define D64_CHR_ROOM_LINKS_FLOOR1       0x02EDu  /* room links of the first floor (PC ABAD) */
#define D64_CHR_ROOM_LINKS_FLOOR2       0x02F5u  /* room links of the second floor (PC ABB5) */
#define D64_CHR_STAIRS_HEIGHT           0x0692u  /* operand of CP n at 0691: height of the stairs cells (0Dh up, 01h down); CHR_STAIRS_HEIGHT */
#define D64_CHR_EXIT_MARK_ROUTINE       0x076Bu  /* operand of CALL nn at 076A: the exit band routine; CHR_EXIT_MARK_ROUTINE */
#define D64_CHR_GRID_OWNER              0x08A0u  /* operand of LD BC,nn at 089F: the character the grid is built for; CHR_GRID_OWNER */
#define D64_CHR_EXIT_TABLE              0x08FAu  /* per exit direction: word routine, word grid target; CHR_EXIT_TABLE */
#define D64_CHR_PATH_FOUND_NOW          0x28FAu  /* 1 when a route was found in this main-loop iteration; CHR_PATH_FOUND_NOW */
#define D64_CHR_PATH_ORIGIN             0x2903u  /* start of the grid search, or destination room; CHR_PATH_ORIGIN */
#define D64_CHR_PATH_DEST               0x2905u  /* destination of the grid search, or start room; CHR_PATH_DEST */
#define D64_CHR_PATH_RESULT             0x2907u  /* FE not searched, 00 not found, FF found, FD already there; CHR_PATH_RESULT */
#define D64_CHR_PATH_ROOM_LINKS_PTR     0x3F73u  /* room links of the searching character's floor; CHR_PATH_ROOM_LINKS_PTR */
#define D64_CHR_PATH_ORIENTATION        0x3F81u  /* orientation (exit direction) found by the last search; CHR_PATH_ORIENTATION */
#define D64_CHR_PATH_LENGTH             0x3F82u  /* length of the last search; CHR_PATH_LENGTH */
#define D64_CHR_PATH_SOLUTION           0x41D4u  /* operand of LD SP,nn at 41D3: the search-queue entry that reached the target; CHR_PATH_SOLUTION */
#define D64_CHR_PATH_FLOOR_TARGET_TEST  0x440Du  /* second byte of BIT n,(HL) at 440C: 76h (bit 6, a marked cell), 66h (bit 4, stairs up), 6Eh (bit 5, stairs down); CS_ST_CHR_PATH_FLOOR_TARGET_TEST_2 */
#define D64_BIT6_HL                     0x76u    /* the values of D64_CHR_PATH_FLOOR_TARGET_TEST */
#define D64_BIT4_HL                     0x66u
#define D64_CHR_CUR_DATA                0x247Eu  /* word, operand of LD IY at 247C: the record chr_update works on (it leaves IY = it); datos_personajes.h */
#define D64_BIT5_HL                     0x6Eu

/* ---- the height buffers and the grid ---- */
#define D64_CHR_PATH_GRID               0x8174u  /* the 24x24 grid of the path search; CHR_PATH_GRID */
#define D64_CHR_HEIGHT_BUFFER           0xAE2Eu  /* the 24x24 height buffer of the screen; CHR_HEIGHT_BUFFER */
#define D64_CHR_HBUF_SIZE               0x0240u  /* 24 x 24 cells */
#define D64_CHR_HBUF_PTR                0x28DBu  /* the height buffer in use; CHR_HBUF_PTR */
#define D64_ISO_CAMERA_RECORD           0x28C4u  /* pseudo record of the room shown (+2 x, +3 y, +4 z); ISO_CAMERA_RECORD */
#define D64_CHR_ROOM_X                  0x28C6u  /* x & F0 of the room shown; CHR_ROOM_X */
#define D64_CHR_ROOM_Y                  0x28C7u  /* y & F0 of the room shown; CHR_ROOM_Y */
#define D64_CHR_ROOM_Z                  0x28C8u  /* floor base of the room shown; CHR_ROOM_Z */
#define D64_CHR_SHOWN_FLOOR             0x290Bu  /* floor base (0, 0Bh, 16h) of the height buffer in use; CHR_SHOWN_FLOOR */
#define D64_CHR_HBUF_ORIGIN_Y           0x22F2u  /* operand of SUB n at 22F1 (chr_to_hbuf_coords): world y of row 0; CHR_HBUF_ORIGIN_Y */
#define D64_CHR_HBUF_ORIGIN_X           0x22FEu  /* operand of SUB n at 22FD: world x of column 0; CHR_HBUF_ORIGIN_X */

#endif
