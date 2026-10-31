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

/* abadia64ks, group logica_b (64K 4C46-5FFF): the data its functions use, at their CPC 64 KiB
 * addresses.  PC names (c/include/direcciones.h of the PC rebuild) where the datum is the same thing.
 * "SMC" = an operand (or opcode) of the game's own code that the code rewrites: data at its code address. */
#ifndef DATOS_LOGICA_B_H
#define DATOS_LOGICA_B_H

/* ---- characters (records of 0Fh bytes: +0 flags, +1 orientation, +2 x, +3 y, +4 height, +5 ...) ---- */
#define D64_CHR_GUILLERMO            0x2B87u  /* Guillermo's record; PC CHR_GUILLERMO (BAF4) */
#define D64_GUILLERMO_X              0x2B89u  /* script var 80; PC GUILLERMO_X (BAF6) */
#define D64_GUILLERMO_Y              0x2B8Au  /* script var 81; PC GUILLERMO_Y */
#define D64_GUILLERMO_Z              0x2B8Bu  /* script var 82: height (>= 0Ch upstairs, >= 16h library); PC GUILLERMO_Z */
#define D64_CHR_ADSO                 0x2B96u  /* Adso's record; PC CHR_ADSO (BB03) */
#define D64_ADSO_X                   0x2B98u  /* script var 83; PC ADSO_X */
#define D64_ADSO_Z                   0x2B9Au  /* script var 85: Adso's height (>= 18h in the library); PC ADSO_Z */
#define D64_CHR_MALACHI              0x2BA5u  /* Malaquias' record; PC CHR_MALACHI (BB12) */
#define D64_CHR_ABBOT                0x2BB4u  /* the abbot's record; PC CHR_ABBOT (BB21) */
#define D64_CHR_BERENGAR             0x2BC3u  /* the Berengario slot's record; PC CHR_BERENGAR (BB30) */
#define D64_BERENGAR_X               0x2BC5u  /* script var 9D: 0 = out of play; PC BERENGAR_X */
#define D64_BERENGAR_Y               0x2BC6u  /* script var 84; PC BERENGAR_Y */
#define D64_CHR_SEVERIN              0x2BD2u  /* the Severino slot's record; PC CHR_SEVERIN (BB3F) */

/* ---- places tables of the scripts (IX): [IX-3] reached, [IX-2] state, [IX-1] destination ---- */
#define D64_AI_MALACHI_PLACES        0x37F8u  /* PC AI_MALACHI_PLACES (C01C) */
#define D64_AI_MALACHI_REACHED       0x37F5u  /* script var 87; PC AI_MALACHI_REACHED */
#define D64_AI_MALACHI_STATE         0x37F6u  /* script var 8E; PC AI_MALACHI_STATE */
#define D64_AI_MALACHI_DEST          0x37F7u  /* script var 86; PC AI_MALACHI_DEST */
#define D64_AI_ABBOT_PLACES          0x3816u  /* PC AI_ABBOT_PLACES (C03A) */
#define D64_AI_ABBOT_REACHED         0x3813u  /* script var 8A; PC AI_ABBOT_REACHED */
#define D64_AI_ABBOT_STATE           0x3814u  /* script var 8C: 0B expel, bit 7 offended; PC AI_ABBOT_STATE */
#define D64_AI_ABBOT_DEST            0x3815u  /* script var 8B; PC AI_ABBOT_DEST */
#define D64_AI_BERENGAR_PLACES       0x3837u  /* PC AI_BERENGAR_PLACES (C05B) */
#define D64_AI_BERENGAR_REACHED      0x3834u  /* script var 91; PC AI_BERENGAR_REACHED */
#define D64_AI_BERENGAR_STATE        0x3835u  /* script var 92; PC AI_BERENGAR_STATE */
#define D64_AI_BERENGAR_DEST         0x3836u  /* script var 90; PC AI_BERENGAR_DEST */
#define D64_AI_SEVERIN_PLACES        0x384Fu  /* PC AI_SEVERIN_PLACES (C073) */
#define D64_AI_SEVERIN_REACHED       0x384Cu  /* script var 94; PC AI_SEVERIN_REACHED */
#define D64_AI_SEVERIN_STATE         0x384Du  /* script var 95; PC AI_SEVERIN_STATE */
#define D64_AI_SEVERIN_DEST          0x384Eu  /* script var 93; PC AI_SEVERIN_DEST */
#define D64_AI_ADSO_PLACES           0x3861u  /* PC AI_ADSO_PLACES (C085) */
#define D64_AI_ADSO_REACHED          0x385Eu  /* script var 97; PC AI_ADSO_REACHED */
#define D64_AI_ADSO_STATE            0x385Fu  /* script var 98; PC AI_ADSO_STATE */
#define D64_AI_ADSO_DEST             0x3860u  /* script var 96; PC AI_ADSO_DEST */

/* ---- the other script variables (table 386Ah, operands 80h-C0h; same order as the PC's C08E) ---- */
#define D64_AI_SCRIPT_VARS           0x386Au  /* 65 words: address of variable 80h+i; PC AI_SCRIPT_VARS */
#define D64_AI_SCRIPT_DEST_PTR       0x390Du  /* SMC: operand of LD (nn),A at 390Ch, the address of the variable the
                                                 last RST 10h assignment wrote; PC AI_SCRIPT_DEST_PTR (C120) */
#define D64_GAME_DAY                 0x28D1u  /* script var 8D: day 1..7; PC GAME_DAY */
#define D64_GAME_HOUR                0x28D2u  /* script var 88: 0 noche .. 6 completas; PC GAME_HOUR */
#define D64_TXT_PHRASE_BUSY          0x28F2u  /* script var 89: a phrase is being shown; PC TXT_PHRASE_BUSY */
#define D64_ISO_ROOM_NUMBER          0x290Eu  /* script var 9A; PC ISO_ROOM_NUMBER */
#define D64_GAME_BONUS2              0x290Fu  /* script var BF: bonus mask low byte; PC GAME_BONUS2 */
#define D64_GAME_BONUS               0x2910u  /* script var C0: bonus mask high byte; PC GAME_BONUS */
#define D64_AI_BERENGAR_DOOR_MASK    0x04B0u  /* script var A9 (SMC: operand of LD C,3Fh at 04AFh); PC AI_BERENGAR_DOOR_MASK */
#define D64_GAME_BOOK_POISON_COUNT   0x37D2u  /* script var BD; PC GAME_BOOK_POISON_COUNT */
#define D64_AI_LAMP_IN_USE           0x37D8u  /* script var B7; PC AI_LAMP_IN_USE */
#define D64_AI_NIGHT_ENDING          0x37D9u  /* script var B4; PC AI_NIGHT_ENDING */
#define D64_AI_LAMP_EVENT            0x37DAu  /* script var B5: 1 low, 2 exhausted; PC AI_LAMP_EVENT */
#define D64_AI_DARK_COUNT            0x37DBu  /* script var B6; PC AI_DARK_COUNT */
#define D64_AI_PARCHMENT_AT_ABBOT    0x37DDu  /* script var B3; PC AI_PARCHMENT_AT_ABBOT */
#define D64_AI_CAMERA_TARGET         0x37DFu  /* script var A7; PC AI_CAMERA_TARGET */
#define D64_AI_PARCHMENT_REPORTED    0x37E1u  /* script var A5; PC AI_PARCHMENT_REPORTED */
#define D64_AI_LAST_HOUR_DONE        0x37E2u  /* script var AA; PC AI_LAST_HOUR_DONE */
#define D64_AI_READY_FOR_CEREMONY    0x37E3u  /* script var A3: 00 = the monks are at their places; PC AI_READY_FOR_CEREMONY */
#define D64_GAME_GUILLERMO_DEAD      0x37E4u  /* script var 9C: end of the game; PC GAME_GUILLERMO_DEAD */
#define D64_AI_WAIT_COUNT            0x37E5u  /* script var 99; PC AI_WAIT_COUNT */
#define D64_AI_SLEEP_ANSWER_COUNT    0x37E6u  /* script var A1; PC AI_SLEEP_ANSWER_COUNT */
#define D64_AI_ADVANCE_HOUR          0x37E7u  /* script var 9B; PC AI_ADVANCE_HOUR */
#define D64_AI_GUILLERMO_IN_PLACE    0x37E8u  /* script var AF; PC AI_GUILLERMO_IN_PLACE */
#define D64_AI_RANDOM                0x37EAu  /* script var B2; PC AI_RANDOM */
#define D64_AI_MALACHI_WARN_COUNT    0x37EBu  /* script var 8F; PC AI_MALACHI_WARN_COUNT */
#define D64_AI_BERENGAR_SLOT_BUSY    0x37EEu  /* script var AB; PC AI_BERENGAR_SLOT_BUSY */
#define D64_AI_MALACHI_DYING         0x37EFu  /* script var AC: 0 alive, 1 dying, 2 dead; PC AI_MALACHI_DYING */
#define D64_AI_SEVERIN_SLOT_BUSY     0x37F0u  /* script var AD; PC AI_SEVERIN_SLOT_BUSY */
#define D64_AI_SEVERIN_BOOK_TOLD     0x37F1u  /* script var B1; PC AI_SEVERIN_BOOK_TOLD */
#define D64_AI_MONK_FLAGS            0x37F2u  /* script var AE; PC AI_MONK_FLAGS */
#define D64_OBJ_DOOR_CHECK_MASK      0x37F3u  /* script var 9E: doors the monks may open; PC OBJ_DOOR_CHECK_MASK */
#define D64_GAME_INVESTIGATION_OPEN  0x37F4u  /* script var B9: 0 = solved; PC GAME_INVESTIGATION_OPEN */
#define D64_AI_PHRASE_PARAM          0x3A5Bu  /* script var A2 (SMC: the inline phrase byte of CALL 4B7C at 3A58,
                                                 ai_say_phrase_param); PC AI_PHRASE_PARAM */
#define D64_AI_UNUSED_3CAD           0x3CADu  /* script var BC: write-only (a byte after the code of 3C9D); PC AI_UNUSED_C123 */
#define D64_AI_IDLE_FRAMES           0x37E0u  /* frames without movement keys (3D07 with an inline byte); PC GAME_IDLE_FRAMES */

/* ---- objects ---- */
#define D64_OBJ_CHAR_OBJECTS         0x293Du  /* holders, 7 bytes, FF end (Guillermo 293D, Adso 2944, Malaquias 294B,
                                                 abbot 2952, Berengario 2959, Severino 2960): +0 flags (bit 7 lamp, bit 0
                                                 cannot take), +1/+2 address of the character's x, +3 objects, +4/+5
                                                 take masks, +6 frame counter; PC OBJ_CHAR_OBJECTS (B8AA) */
#define D64_GUILLERMO_OBJECTS        0x2940u  /* script var A4; PC GUILLERMO_OBJECTS (B8AD) */
#define D64_GAME_ADSO_LAMP           0x2944u  /* script var B8: Adso's holder +0, bit 7 = the lamp; PC GAME_ADSO_LAMP */
#define D64_OBJ_ADSO_OBJECTS         0x2947u  /* script var BE; PC OBJ_ADSO_OBJECTS */
#define D64_OBJ_MALACHI_OBJECTS      0x294Eu  /* script var BB; PC OBJ_MALACHI_OBJECTS */
#define D64_OBJ_MALACHI_TAKEMASK     0x2950u  /* script var BA; PC OBJ_MALACHI_TAKEMASK */
#define D64_OBJ_ABBOT_OBJECTS        0x2955u  /* script var A6; PC OBJ_ABBOT_OBJECTS */
#define D64_OBJ_BERENGAR_OBJECTS     0x295Cu  /* script var A8; PC OBJ_BERENGAR_OBJECTS */
#define D64_OBJ_BERENGAR_TAKEMASK    0x295Eu  /* script var B0; PC OBJ_BERENGAR_TAKEMASK */
#define D64_OBJ_DOOR_PERMISSIONS     0x292Au  /* door entries of 3 bytes (bits, word); Guillermo's bits here; PC OBJ_DOOR_PERMISSIONS (B897) */
#define D64_OBJ_DOOR_PERMISSIONS_ADSO 0x292Du /* Adso's door bits (bit 4 key 3); PC 1800:B89A */
#define D64_OBJ_SPRITES              0x2A6Cu  /* object sprites, 14h bytes each; PC B2_SPR_OBJECTS (B9D9) */
#define D64_OBJ_OBJECTS              0x2B59u  /* object records, 5 bytes, FF end: +0 flags (7 held, 6 hidden, 0 taken this
                                                 frame), +1 orientation, +2 x, +3 y, +4 height; PC OBJ_OBJECTS (BAC6) */
#define D64_OBJ_DOOR_WING1           0x2B4Fu  /* script var 9F; PC OBJ_DOOR_WING1 */
#define D64_OBJ_DOOR_WING2           0x2B54u  /* script var A0; PC OBJ_DOOR_WING2 */
#define D64_CHR_STEP_TABLE           0x23A8u  /* steps per orientation, 8 bytes each (dx, dy, ...); PC 1800:AE39 */
#define D64_CHR_SHOWN_FLOOR          0x290Bu  /* floor base of the room shown; PC CHR_SHOWN_FLOOR */
#define D64_OBJ_HOLDER_LOCKED        0x4CAAu  /* SMC: operand of LD A,n at 4CA9: holder +0 bit 0; PC OBJ_HOLDER_LOCKED */
#define D64_OBJ_FRONT_Z              0x4CBDu  /* SMC: operand of SUB n at 4CBC; PC OBJ_FRONT_Z */
#define D64_OBJ_FRONT_X              0x4CC4u  /* SMC: operand of CP n at 4CC3; PC OBJ_FRONT_X */
#define D64_OBJ_FRONT_Y              0x4CC9u  /* SMC: operand of CP n at 4CC8; PC OBJ_FRONT_Y */
#define D64_OBJ_DROP_LEVEL           0x4E17u  /* SMC: operand of SUB n at 4E16: height above the floor; PC OBJ_DROP_LEVEL */
#define D64_OBJ_DROP_INDEX           0x4E4Au  /* SMC: operand of LD C,n at 4E49: 1-based object index; PC OBJ_DROP_INDEX */
#define D64_OBJ_MIRROR_NUMERAL       0x290Du  /* stair numeral of the mirror riddle 1..3 (0 = not chosen); PC OBJ_MIRROR_NUMERAL */
#define D64_OBJ_MIRROR_NUMERALS      0x5177u  /* 'IXX', 'XIX', 'XXI' (font codes 49h 58h D8h...); PC OBJ_MIRROR_NUMERALS */
#define D64_TXT_WORD_AAA             0xB59Eu  /* the dictionary word the numeral is written over; PC 1800:7DDF */

/* ---- the mirror ---- */
#define D64_OBJ_MIRROR_CLOSED        0x28DDu  /* PC OBJ_MIRROR_CLOSED */
#define D64_ISO_MIRROR_STATE_GUILLERMO 0x28DEu /* +0 shown flag (00/FE), +1 position word, +3 size word; PC ISO_MIRROR_STATE_GUILLERMO */
#define D64_ISO_MIRROR_STATE_ADSO    0x28E3u  /* PC ISO_MIRROR_STATE_ADSO */
#define D64_SPR_GUILLERMO            0x29A4u  /* Guillermo's sprite; PC B2_SPR_GUILLERMO */
#define D64_SPR_ADSO                 0x29B8u  /* Adso's sprite; PC B2_SPR_ADSO */
#define D64_CHR_ANIM_GUILLERMO       0x2CF0u  /* PC CHR_ANIM_GUILLERMO */
#define D64_CHR_ANIM_ADSO            0x2D10u  /* PC CHR_ANIM_ADSO */
#define D64_ISO_MIRROR_BUF_GUILLERMO 0x855Cu  /* graphics buffer of Guillermo's image; PC 1800:EC6A */
#define D64_ISO_MIRROR_BUF_ADSO      0x8656u  /* PC 1800:ED64 */
#define D64_CHR_HBUF_ORIGIN_Y        0x22F2u  /* SMC: operand of SUB n at 22F1 (chr_to_hbuf_coords); PC CHR_HBUF_ORIGIN_Y */
#define D64_CHR_HBUF_ORIGIN_X        0x22FEu  /* SMC: operand of SUB n at 22FD; PC CHR_HBUF_ORIGIN_X */
#define D64_CHR_CUR_FLIP             0x25AEu  /* SMC: operand of CALL NZ,nn at 25AD; PC CHR_CUR_FLIP */
#define D64_CHR_CUR_ANIM             0x25D9u  /* SMC: operand of LD DE,nn at 25D8; PC CHR_CUR_ANIM */
#define D64_ISO_MIRROR_OLD_POS_OP    0x4F9Au  /* SMC: operand of LD HL,(nn) at 4F99 (state+1) */
#define D64_ISO_MIRROR_OLD_SIZE_OP   0x4F9Eu  /* SMC: operand of LD DE,(nn) at 4F9C (state+3) */
#define D64_ISO_MIRROR_NEW_POS_OP    0x4FA2u  /* SMC: operand of LD (nn),HL at 4FA1 (state+1) */
#define D64_ISO_MIRROR_NEW_SIZE_OP   0x4FA6u  /* SMC: operand of LD (nn),DE at 4FA4 (state+3) */
#define D64_ISO_MIRROR_SHOWN         0x4FA9u  /* SMC: operand of LD A,n at 4FA8 (state +0); PC ISO_MIRROR_SHOWN */
#define D64_ISO_MIRROR_BUFFER        0x4FD9u  /* SMC: operand of LD DE,nn at 4FD8; PC ISO_MIRROR_BUFFER */
#define D64_ISO_MIRROR_DRAW_CALLBACK 0x4FC9u  /* iso_mirror_draw_callback, the value stored in chr_cur_flip */

/* ---- clock and score bar ---- */
#define D64_HUD_OBSEQUIUM            0x28D0u  /* 0..1Fh; PC HUD_OBSEQUIUM */
#define D64_HUD_HOUR_NAME_PTR        0x28D3u  /* word; PC HUD_HOUR_NAME_PTR */
#define D64_AI_HOUR_FRAMES_LEFT      0x28D7u  /* word; PC AI_HOUR_FRAMES_LEFT */
#define D64_TXT_CURSOR               0x28E8u  /* word: position of the next character (txt_draw_char); PC TXT_CURSOR */
#define D64_TXT_CURSOR_HOUR_NAME     0xB40Du  /* txt_cursor value of the new letter of the hour name */
#define D64_HUD_HOUR_SCROLL_STEPS    0x28F6u  /* PC HUD_HOUR_SCROLL_STEPS */
#define D64_AI_HOUR_DURATIONS        0x4AD0u  /* 7 per day, units of 256 frames; PC AI_HOUR_DURATIONS */
#define D64_HUD_ROMAN_DAYS           0x4AFDu  /* 7 x 3 glyph codes (0 blank, 1 V, 2 I); PC HUD_ROMAN_DAYS */
#define D64_HUD_HOUR_NAMES           0x4B12u  /* 7 x 7 font codes; PC HUD_HOUR_NAMES */
#define D64_HUD_DAY_GLYPH_STEP       0x50FEu  /* SMC: the opcode at 50FE, 03 INC BC or 0Bh DEC BC (blank glyph) */
#define D64_HUD_GFX_ROMAN_BLANK      0x50D7u  /* FF FF: the blank glyph's row (read again each row) */
#define D64_HUD_GFX_ROMAN_V          0xAB39u  /* 2 bytes x 8 rows; PC hud_gfx_roman V */
#define D64_HUD_GFX_ROMAN_I          0xAB49u  /* PC hud_gfx_roman I */
#define D64_HUD_OBSEQUIUM_TAIL       0x5180u  /* FF 7F 3F 1F: the partial byte of the bar; PC HUD_OBSEQUIUM_TAIL */
#define D64_GAME_START_DAY           0xBF4Fu  /* day of a new game (BF4F, read by ai_clock_init) */
#define D64_GAME_START_HOUR          0xBF4Eu  /* hour of a new game */

/* ---- the screen (C000h-FFFFh) positions ---- */
#define D64_SCR_OBJECT_SLOTS         0xC591u  /* the six object slots of the score bar */
#define D64_SCR_HOUR_NAME            0xE583u  /* the 12-byte box of the hour name */
#define D64_SCR_DAY_NUMERAL          0xED09u  /* the day numeral */
#define D64_SCR_OBSEQUIUM_BAR        0xCDB4u  /* the obsequium bar */

#endif
