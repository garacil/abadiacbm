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

/* abadia64ks, group "personajes": the CPC 64 KiB addresses of the data the characters' functions use
 * (2226-2FAC: movement, probing, animation, projection, command streams, the height buffer, the keyboard,
 * the sprite flips).  PC names (c/include/direcciones.h) where the datum is the same.  Many of the
 * variables of the full game live here as operands of the code (self-modified): they are named as data
 * at their code address. */
#ifndef DATOS_PERSONAJES_H
#define DATOS_PERSONAJES_H

/* ---- the height buffer and the probe ---- */
#define D64_CHR_HBUF_ORIGIN_Y      0x22F2u  /* byte, operand of SUB at 22F1: world y of row 0 of the 24x24 height buffer (written by 07FF); PC CHR_HBUF_ORIGIN_Y */
#define D64_CHR_HBUF_ORIGIN_X      0x22FEu  /* byte, operand of SUB at 22FD: world x of column 0 of the height buffer (07FF); PC CHR_HBUF_ORIGIN_X */
#define D64_CHR_PROBE_HEIGHT       0x2374u  /* byte, operand of SUB at 2373: height of the character over its floor, subtracted from each probed cell; PC CHR_PROBE_HEIGHT */
#define D64_CHR_PROBE_INNER        0x2378u  /* word, operand of LD BC at 2377: inner stride of the 4x4 probe; PC CHR_PROBE_INNER */
#define D64_CHR_PROBE_OUTER        0x237Fu  /* word, operand of LD BC at 237E: outer stride of the 4x4 probe; PC CHR_PROBE_OUTER */
#define D64_CHR_STEP_TABLE_2X2     0x23A2u  /* 32 bytes: per orientation inner stride, outer stride, probe start, dx, dy (2x2 characters); PC CHR_STEP_TABLE_2X2 */
#define D64_CHR_STEP_TABLE_1X1     0x23C2u  /* 32 bytes: the same for 1-cell characters (on stairs); PC CHR_STEP_TABLE_1X1 */
#define D64_CHR_HBUF_PTR           0x28DBu  /* word: the height buffer (24x24 cells); PC CHR_HBUF_PTR */
#define D64_CHR_SHOWN_FLOOR        0x290Bu  /* byte: base height (0, 0Bh, 16h) of the floor in the height buffer (07FF); PC CHR_SHOWN_FLOOR */
#define D64_CHR_PROBE              0x2916u  /* 16 bytes: the 4x4 relative heights (or marks 10h/20h) in front of the character; PC CHR_PROBE */
#define D64_CHR_FLOOR_HEIGHTS_PTR  0x3454u  /* word: height data of the current floor for 3456 chr_hbuf_fill_room; PC CHR_FLOOR_HEIGHTS_PTR */
#define D64_CHR_FLOOR0_HEIGHTS     0x7B98u  /* height data of the ground floor; PC CHR_FLOOR0_HEIGHTS */
#define D64_CHR_FLOOR1_HEIGHTS     0x9E40u  /* height data of the first floor (base 0Bh); PC CHR_FLOOR1_HEIGHTS */
#define D64_CHR_FLOOR2_HEIGHTS     0x9F60u  /* height data of the second floor, the library (base 16h); PC CHR_FLOOR2_HEIGHTS */

/* ---- the character being updated (chr_update loads them from its chr_table entry) ---- */
#define D64_CHR_TABLE              0x2703u  /* 6 entries x 10 bytes, FFFF end: sprite, record, behaviour, flip routine, animation table; PC CHR_TABLE */
#define D64_CHR_PARAM_TARGETS      0x2741u  /* 5 words: where chr_load_params copies the 5 words of an entry (the 5 operands below); PC CHR_PARAM_TARGETS */
#define D64_CHR_CUR_SPRITE         0x2477u  /* word, operand of LD IX at 2475: sprite record of the character being updated; PC CHR_CUR_SPRITE */
#define D64_CHR_CUR_DATA           0x247Eu  /* word, operand of LD IY at 247C: its position/state record; PC CHR_CUR_DATA */
#define D64_CHR_CUR_BEHAVIOUR      0x24A6u  /* word, operand of LD HL at 24A5 (then JP (HL)): its behaviour routine, 23E2 or 278F; PC CHR_CUR_BEHAVIOUR */
#define D64_CHR_CUR_FLIP           0x25AEu  /* word, operand of CALL NZ at 25AD: its flip routine (2EE7.. 2F40, 4FC9); PC CHR_CUR_FLIP */
#define D64_CHR_CUR_ANIM           0x25D9u  /* word, operand of LD DE at 25D8: its animation table, or C0xx for a monk; PC CHR_CUR_ANIM */
#define D64_CHR_MOVED              0x2912u  /* byte: FF when the character being updated moved or turned; PC CHR_MOVED */
#define D64_CHR_MALACHI_RISING     0x3EEDu  /* byte: not 0 while Malachi rises when dying: chr_update only animates; PC CHR_MALACHI_RISING */
#define D64_CHR_BACKUP             0x28B9u  /* 10 bytes: copy of bytes 2-0Bh of the character moved by commands; PC CHR_BACKUP */

/* ---- Guillermo's behaviour ---- */
#define D64_CHR_GUILLERMO_BEHAVIOUR 0x23E2u /* code: Guillermo's behaviour routine (chr_table) */
#define D64_CHR_AI_FOLLOW_COMMANDS 0x278Fu  /* code: the behaviour routine of Adso and the monks (chr_table) */
#define D64_CHR_GUILLERMO_STATE    0x23E4u  /* byte, operand of LD A at 23E3: 0 normal, >1 scripted fall counter (14h: the mirror trap); PC CHR_GUILLERMO_STATE */
#define D64_CHR_GUILLERMO_FALL_DY  0x2406u  /* byte, operand of ADD A at 2405: sprite y step while the state counts down; PC CHR_GUILLERMO_FALL_DY */
#define D64_GAME_CAMERA_OTHER      0x37DCu  /* byte: not 0 when the camera follows another character (Guillermo ignores the keys); PC GAME_CAMERA_OTHER */

/* ---- the projection onto the screen ---- */
#define D64_CHR_ROOM_ORIGIN_X      0x2636u  /* byte, operand of SUB at 2635: local x origin of the room shown; PC CHR_ROOM_ORIGIN_X */
#define D64_CHR_ROOM_ORIGIN_Y      0x2640u  /* byte, operand of SUB at 263F: local y origin; PC CHR_ROOM_ORIGIN_Y */
#define D64_CHR_ROOM_FLOOR         0x264Eu  /* byte, operand of CP at 264D: floor base of the room shown; PC CHR_ROOM_FLOOR */
#define D64_CHR_CAMERA_TRANSFORM   0x2656u  /* word, operand of CALL at 2655: the camera rotation (20AE, 20A9, 20AF, 20B8); PC CHR_CAMERA_TRANSFORM */
#define D64_CHR_PROJECT_TEST       0x2684u  /* byte, code: 00 (NOP) normally, C9 (RET) in the test mode of 0AC2 (chr_project returns the screen position); PC CS_ST_L_25D9 */
#define D64_CHR_SPRITE_OFFSETS     0x28D5u  /* word: chr_sprite_offset_tables + 40h * camera orientation; PC CHR_SPRITE_OFFSETS */
#define D64_CHR_ANIM_MONK          0x2D30u  /* 32 bytes: the monks' shared body frames (graphics word = the face); PC CHR_ANIM_MONK */
#define D64_SPR_MONK_FACES         0x2BE8u  /* 4 words: the faces of the 4 monks (second face at +32h); PC SPR_MONK_FACES */

/* ---- the character records (15 bytes) and the sprites ---- */
#define D64_CHR_GUILLERMO          0x2B87u  /* Guillermo's record; +6 = graphics flipped; PC CHR_GUILLERMO */
#define D64_CHR_ADSO               0x2B96u  /* Adso's record; PC CHR_ADSO */
#define D64_CHR_MALACHI            0x2BA5u  /* 3rd character (Malachi); PC CHR_MALACHI */
#define D64_CHR_ABBOT              0x2BB4u  /* 4th (the Abbot); PC CHR_ABBOT */
#define D64_CHR_BERENGAR           0x2BC3u  /* 5th (Berengar); PC CHR_BERENGAR */
#define D64_CHR_SEVERIN            0x2BD2u  /* 6th (Severin); PC CHR_SEVERIN */
#define D64_SPR_TABLE              0x2968u  /* sprite records of 20 bytes, FF end (Guillermo, Adso at +14h, ...); PC SPR_TABLE */
#define D64_SPR_LIGHT              0x2B20u  /* the light sprite record (BCh drawn, FEh hidden); PC SPR_LIGHT */
#define D64_GAME_ADSO_LAMP         0x2944u  /* byte: bit 7 = Adso carries the lamp; PC GAME_ADSO_LAMP */
#define D64_ISO_ROOM_DARK          0x11DCu  /* byte: not 0 when the room shown is dark; PC ISO_ROOM_DARK */
#define D64_SPR_LIGHT_DX           0x4756u  /* byte, code operand in the light drawer: Adso's x & 3; PC SPR_LIGHT_DX */
#define D64_SPR_LIGHT_DX_REST      0x4782u  /* byte, code operand: 4 - spr_light_dx; PC SPR_LIGHT_DX_REST */
#define D64_SPR_LIGHT_FILL_A       0x4738u  /* word, code operand: EFh or 9Fh bytes before the light circle; PC SPR_LIGHT_FILL_A */
#define D64_SPR_LIGHT_FILL_B       0x479Eu  /* word, code operand: 9Fh or EFh; PC SPR_LIGHT_FILL_B */
#define D64_SPR_LIGHT_FLIP_PATCH   0x476Du  /* byte, code: 00 (NOP) or 29h (ADD HL,HL) when Adso's graphics are flipped; PC CS_ST_SPR_LIGHT_FLIP_PATCH */
#define D64_SPR_FLIP_WIDTH         0x2FA3u  /* word, operand of LD DE at 2FA2: row width of spr_flip_graphics_h; PC SPR_FLIP_WIDTH */
#define D64_SPR_GUILLERMO_GFX_W5   0xA300u  /* Guillermo's 5-byte-wide frames (AEh lines); PC SPR_GUILLERMO_GFX_W5 */
#define D64_SPR_GUILLERMO_GFX_W4   0xA666u  /* Guillermo's 4-byte-wide frames (21h lines); PC SPR_GUILLERMO_GFX_W4 */
#define D64_SPR_ADSO_GFX_W5        0xA6EAu  /* Adso's 5-byte-wide frames (5Fh lines); PC SPR_ADSO_GFX_W5 */
#define D64_SPR_ADSO_GFX_W4        0xA8C5u  /* Adso's 4-byte-wide frames (5Ah lines); PC SPR_ADSO_GFX_W4 */

/* ---- rooms ---- */
#define D64_ISO_ROOM_NUMBER        0x290Eu  /* byte: current room number; PC ISO_ROOM_NUMBER */
#define D64_ISO_ROOM_TABLE         0x6100u  /* the room records, each starting with its length byte; PC ISO_ROOM_TABLE */
#define D64_ISO_ROOM_PTR           0x11DAu  /* word: the current room record; PC ISO_ROOM_PTR */
#define D64_CHR_ROOM_X             0x28C6u  /* byte: x & F0 of the room shown, 0 forces a rebuild; PC CHR_ROOM_X */

/* ---- the clock ---- */
#define D64_SYS_TICKS              0x289Cu  /* byte, operand of LD A at 289B: ticks since the last frame, up to FFh; PC SYS_TICKS */

/* ---- the keyboard ---- */
#define D64_SYS_KEYS_DOWN          0x2DE8u  /* 10 bytes: keys down now, one bit per CPC key (0 = down); PC SYS_KEYS_DOWN */
#define D64_SYS_KEYS_PENDING       0x2DF2u  /* 10 bytes: presses not yet consumed by sys_key_pressed (0 = pending); PC SYS_KEYS_PENDING */
#define D64_SYS_KEY_SINGLE         0x2E2Cu  /* 2 bytes: the key being tested + FF; PC SYS_KEY_SINGLE */
#define D64_SYS_KEY_ALIAS_LEFT     0x2E2Eu  /* 4 bytes: key 8 and its aliases; PC SYS_KEY_ALIAS_LEFT */
#define D64_SYS_KEY_ALIAS_SPACE    0x2E32u  /* 4 bytes: key 2Fh and its aliases; PC SYS_KEY_ALIAS_SPACE */
#define D64_SYS_KEY_ALIAS_012      0x2E36u  /* 12 bytes: keys 0, 1, 2 and their aliases; PC SYS_KEY_ALIAS_012 */
#define D64_SYS_KEY_BITMAP         0x2E6Au  /* word, operand of LD DE at 2E69: the bitmap being tested; PC SYS_KEY_BITMAP */
#define D64_SYS_BIT_MASKS          0x2EB3u  /* 8 bytes: 01 02 04 .. 80; PC SYS_BIT_MASKS */

/* ---- the mirror ---- */
#define D64_OBJ_MIRROR_CLOSED      0x28DDu  /* byte: 1 = the mirror is closed (Q+R checked); PC OBJ_MIRROR_CLOSED */
#define D64_OBJ_MIRROR_NUMERAL     0x290Du  /* byte: the roman numeral of the enigma (1-3, 4 = always the trap); PC OBJ_MIRROR_NUMERAL */
#define D64_GAME_BONUS             0x2910u  /* byte: bonus bits, bit 2 = Q+R pressed on a mirror step; PC GAME_BONUS */
#define D64_GAME_GUILLERMO_DEAD    0x37E4u  /* byte: 1 = Guillermo dies; PC GAME_GUILLERMO_DEAD */
#define D64_OBJ_MIRROR_HEIGHT_PTR  0x2EDEu  /* word: the 5 height bytes of the mirror in the floor height data; PC OBJ_MIRROR_HEIGHT_PTR */
#define D64_OBJ_MIRROR_CLOSED_HEIGHTS 0x2EE0u /* 5 bytes: the heights with the mirror closed; PC OBJ_MIRROR_CLOSED_HEIGHTS */
#define D64_OBJ_MIRROR_ENTRY_PTR   0x2EE5u  /* word: the mirror's entry in the room data; PC OBJ_MIRROR_ENTRY_PTR */

#endif
