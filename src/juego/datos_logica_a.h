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

/* abadia64ks, group logica_a (CPC 64 KiB addresses 3AAF-4C45): the data its functions use, named after
 * the PC rebuild (c/include/direcciones.h) when the datum is the same thing.  Every address is the CPC
 * 64K version's.  Bytes inside the Z80 code (self-modified operands, inline data that changes) are data
 * too and are named here with their code address. */
#ifndef DATOS_LOGICA_A_H
#define DATOS_LOGICA_A_H

/* ---- low memory and the system ---- */
#define D64_SND_PHRASE_VOICE        0x1127u  /* voice/pitch byte of the current phrase (PC SND_PHRASE_VOICE C16D) */
#define D64_ISO_ROOM_DARK           0x11DCu  /* not 0 when the room is dark (PC ISO_ROOM_DARK B71C) */
#define D64_SYS_FRAME_TICKS         0x21DAu  /* frame budget of the main loop (PC SYS_FRAME_TICKS AE2B) */
#define D64_CHR_GUILLERMO_STATE     0x23E4u  /* 0 normal, >1 scripted animation counter (PC CHR_GUILLERMO_STATE AE2D) */
#define D64_CHR_GUILLERMO_FALL_DY   0x2406u  /* sprite y step while chr_guillermo_state counts (PC CHR_GUILLERMO_FALL_DY AE2E) */

/* ---- 28xx-29xx: game variables ---- */
#define D64_SYS_TICKS               0x289Cu  /* the 300 Hz tick counter: operand of LD A,n at 289B in the interrupt handler 2899;
                                                FFh = the main loop does not wait (PC SYS_TICKS AE2C) */
#define D64_CHR_ROOM_X              0x28C6u  /* x & F0 of the room shown; 0 forces a rebuild (PC CHR_ROOM_X B830) */
#define D64_GAME_DAY                0x28D1u  /* day 1-7 (PC GAME_DAY B83D) */
#define D64_GAME_HOUR               0x28D2u  /* moment of the day 0 noche .. 6 completas (PC GAME_HOUR B83E) */
#define D64_AI_HOUR_FRAMES_LEFT     0x28D7u  /* word: frames left in the moment of the day (PC AI_HOUR_FRAMES_LEFT B843) */
#define D64_CHR_CAMERA_TARGET       0x28D9u  /* word: record of the character the camera follows (PC CHR_CAMERA_TARGET B845) */
#define D64_CHR_HBUF_PTR            0x28DBu  /* word: the 24x24 height buffer (PC CHR_HBUF_PTR B847) */
#define D64_TXT_CURSOR              0x28E8u  /* word: text position, low x in bytes, high y in lines (PC TXT_CURSOR B854) */
#define D64_OBJ_GUILLERMO_OBJECTS_BEFORE 0x28EAu /* Guillermo's objects at the start of obj_update_inventory (PC B856) */
#define D64_TXT_TRAILING_BLANKS     0x28ECu  /* blanks still to print after the phrase (PC TXT_TRAILING_BLANKS B858) */
#define D64_TXT_PHRASE_PTR          0x28EFu  /* word: next byte of the phrase (PC TXT_PHRASE_PTR B85B) */
#define D64_TXT_WORD_DONE           0x28F1u  /* 1 when the next phrase byte must be read (PC TXT_WORD_DONE B85D) */
#define D64_TXT_PHRASE_BUSY         0x28F2u  /* non 0 while a phrase is shown (PC TXT_PHRASE_BUSY B85E) */
#define D64_TXT_PHRASE_ACTIVE       0x28F3u  /* non 0 while a phrase scrolls (PC TXT_PHRASE_ACTIVE B85F) */
#define D64_CHR_PATH_SAVED_SP       0x2901u  /* word: SP saved by the path searches, which use the stack as their queue (PC CHR_PATH_SAVED_SP B86D) */
#define D64_CHR_PATH_ORIGIN         0x2903u  /* word: start of the search (grid x, y) (PC CHR_PATH_ORIGIN B86F) */
#define D64_CHR_PATH_DEST           0x2905u  /* word: destination of the search (PC CHR_PATH_DEST B871) */
#define D64_CHR_PATH_RESULT         0x2907u  /* FF found, 00 not found (PC CHR_PATH_RESULT B873) */
#define D64_GAME_BONUS2             0x290Fu  /* bonus bits, low byte of the word read by the percentage (PC GAME_BONUS2 B87B) */
#define D64_GAME_BONUS              0x2910u  /* bonus bits, high byte (PC GAME_BONUS B87C) */
#define D64_SPR_RECT_POS            0x2926u  /* x, y of the rectangle being composed (PC SPR_RECT_POS B893) */
#define D64_SPR_RECT_SIZE           0x2928u  /* w, h of the rectangle being composed (PC SPR_RECT_SIZE B895) */

/* the object holders (PC OBJ_CHAR_OBJECTS B8AA): 6 entries of 7 bytes from 293D, FF end at 2967:
 * +0 flags (bit 7 lamp), +1/+2 address of the character's x, +3 objects, +4/+5 take masks, +6 counter */
#define D64_OBJ_CHAR_OBJECTS        0x293Du  /* holder 0: Guillermo (PC OBJ_CHAR_OBJECTS B8AA) */
#define D64_B2_GUILLERMO_OBJECTS    0x2940u  /* Guillermo's objects, holder 0 +3 (PC B2_GUILLERMO_OBJECTS B8AD) */
#define D64_GAME_ADSO_LAMP          0x2944u  /* holder 1 (Adso) +0: bit 7 = Adso carries the lamp (PC GAME_ADSO_LAMP B8B1) */
#define D64_OBJ_ADSO_OBJECTS        0x2947u  /* Adso's objects, bit 1 key 3 (PC OBJ_ADSO_OBJECTS B8B4) */
#define D64_OBJ_MALACHI_HOLDER      0x294Bu  /* holder 2 (Malaquias) +0 (PC OBJ_MALACHI_HOLDER B8B8) */
#define D64_OBJ_MALACHI_OBJECTS     0x294Eu  /* Malaquias' objects, bit 1 key 3 (PC OBJ_MALACHI_OBJECTS B8BB) */
#define D64_OBJ_ABBOT_HOLDER        0x2952u  /* holder 3 (the abbot) (PC 1800:B8BF) */
#define D64_OBJ_ABBOT_OBJECTS       0x2955u  /* the abbot's objects, bit 4 the parchment (PC OBJ_ABBOT_OBJECTS B8C2) */
#define D64_OBJ_ABBOT_TAKEMASK      0x2957u  /* objects the abbot may take (PC OBJ_ABBOT_TAKEMASK B8C4) */
#define D64_OBJ_BERENGAR_OBJECTS    0x295Cu  /* objects of the Berengario slot (PC OBJ_BERENGAR_OBJECTS B8C9) */
#define D64_OBJ_SEVERIN_HOLDER      0x2960u  /* holder 5 (Severino) (PC 1800:B8CD) */
#define D64_OBJ_SEVERIN_OBJECTS     0x2963u  /* objects of the Severino slot, 80h the book (PC OBJ_SEVERIN_OBJECTS B8D0) */
#define D64_SPR_TABLE               0x2968u  /* sprite records of 20 bytes, FF end (PC SPR_TABLE B8D5) */

/* ---- 2Bxx: object records and characters ---- */
#define D64_OBJ_OBJECTS             0x2B59u  /* object records of 5 bytes, FF end at 2B86 (PC OBJ_OBJECTS BAC6) */
#define D64_CHR_GUILLERMO           0x2B87u  /* Guillermo's record, 15 bytes: +1 orientation, +2 x, +3 y, +4 height (PC CHR_GUILLERMO BAF4) */
#define D64_CHR_ADSO                0x2B96u  /* Adso's record (PC CHR_ADSO BB03) */
#define D64_CHR_MALACHI             0x2BA5u  /* Malaquias' record (PC CHR_MALACHI BB12) */
#define D64_CHR_BERENGAR            0x2BC3u  /* the Berengario slot's record (PC CHR_BERENGAR BB30) */
#define D64_CHR_SEVERIN             0x2BD2u  /* the Severino slot's record (PC CHR_SEVERIN BB3F) */
#define D64_SPR_SORTED_TOP          0x2BE1u  /* word: the lowest address of the sprite list pushed on the stack (PC SPR_SORTED_TOP BB4E) */
#define D64_SPR_SORTED_CURSOR       0x2BE3u  /* word: the next entry of that list to compose (PC SPR_SORTED_CURSOR BB50) */
#define D64_SPR_TILE_POS            0x2BE6u  /* word: tile-buffer entry of the rectangle's first tile (PC SPR_TILE_POS BB53) */
#define D64_SPR_MONK_FACES          0x2BE8u  /* 4 words: face graphics of Malaquias, the abbot, Berengario, Severino (PC SPR_MONK_FACES BB55) */

/* ---- 37xx: the logic variables (PC C000 area) ---- */
#define D64_GAME_BOOK_POISON_COUNT  0x37D2u  /* frames reading the book without gloves (PC GAME_BOOK_POISON_COUNT BFF6) */
#define D64_AI_LAMP_TIME            0x37D4u  /* word: frames the lamp has burnt (PC AI_LAMP_TIME BFF8) */
#define D64_AI_LAMP_IN_USE          0x37D8u  /* 1 while Adso is in the library with the lamp (PC AI_LAMP_IN_USE BFFC) */
#define D64_AI_NIGHT_ENDING         0x37D9u  /* result of ai_night_end_tick (PC AI_NIGHT_ENDING BFFD) */
#define D64_AI_LAMP_EVENT           0x37DAu  /* result of ai_lamp_tick (PC AI_LAMP_EVENT BFFE) */
#define D64_GAME_CAMERA_OTHER       0x37DCu  /* character the camera follows, 0 Guillermo (PC GAME_CAMERA_OTHER C000) */
#define D64_OBJ_LAMP_PLACED         0x37DEu  /* the lamp was put in the kitchen (PC OBJ_LAMP_PLACED C002) */
#define D64_AI_CAMERA_TARGET        0x37DFu  /* character the camera should follow (PC AI_CAMERA_TARGET C003) */
#define D64_GAME_IDLE_FRAMES        0x37E0u  /* frames without movement keys (PC GAME_IDLE_FRAMES C004) */
#define D64_GAME_GUILLERMO_DEAD     0x37E4u  /* 1 = Guillermo dies (PC GAME_GUILLERMO_DEAD C008) */
#define D64_AI_SLEEP_ANSWER_COUNT   0x37E6u  /* (PC AI_SLEEP_ANSWER_COUNT C00A) */
#define D64_AI_ADVANCE_HOUR         0x37E7u  /* (PC AI_ADVANCE_HOUR C00B) */
#define D64_AI_GUILLERMO_IN_PLACE   0x37E8u  /* result of ai_check_guillermo_at (PC AI_GUILLERMO_IN_PLACE C00C) */
#define D64_AI_MALACHI_DYING        0x37EFu  /* (PC AI_MALACHI_DYING C013) */
#define D64_AI_MONK_FLAGS           0x37F2u  /* (PC AI_MONK_FLAGS C016) */
#define D64_GAME_INVESTIGATION_OPEN 0x37F4u  /* 0 = investigation solved (PC GAME_INVESTIGATION_OPEN C018) */
#define D64_AI_MALACHI_REACHED      0x37F5u  /* (PC AI_MALACHI_REACHED C019) */
#define D64_AI_SEVERIN_STATE        0x384Du  /* (PC AI_SEVERIN_STATE C071) */

/* ---- data inside the code of the group ---- */
#define D64_VID_SPIRAL_SIDES        0x3AABu  /* 4 bytes: side lengths of vid_spiral_pass (PC VID_SPIRAL_SIDES BFC0) */
#define D64_CHR_RECORD_PTRS         0x3D30u  /* 6 words: character records by camera index (PC CHR_RECORD_PTRS BFCA) */
#define D64_GAME_PERCENT_DIGITS     0x3E61u  /* 3 bytes written by game_compute_percentage into the inline text
                                                " xx  POR CIENTO" of game_check_end (3E60-3E6F; PC 1000:6254) */
#define D64_CHR_MALACHI_RISING      0x3EEDu  /* (PC CHR_MALACHI_RISING BFD6) */
#define D64_CHR_MALACHI_RISE_DELAY  0x3EEEu  /* (PC CHR_MALACHI_RISE_DELAY BFD7) */
#define D64_CHR_PATH_ROOM_LINKS_PTR 0x3F73u  /* word: room connection map of the floor searched (PC CHR_PATH_ROOM_LINKS_PTR BED7) */
#define D64_CHR_CMD_TURN_LEN        0x3F75u  /* 4 bytes: bit counts of the turn commands (PC CHR_CMD_TURN_LEN BED9) */
#define D64_CHR_CMD_TURN_BITS       0x3F79u  /* 4 words (high byte first): the turn commands (PC CHR_CMD_TURN_BITS BEDD) */
#define D64_CHR_PATH_ORIENTATION    0x3F81u  /* orientation found by the last search (PC CHR_PATH_ORIENTATION BEE5) */
#define D64_CHR_PATH_LENGTH         0x3F82u  /* level reached by the last room search (PC CHR_PATH_LENGTH BEE6) */
#define D64_CHR_CMD_STEP_TABLE      0x3F83u  /* 5 entries of 3 bytes (bits high, low, count) of the step commands
                                                (3F83, 3F86, 3F89, 3F8C, 3F8F; PC CHR_CMD_STEP_TABLE BEE7) */
#define D64_CHR_PATH_HEIGHT         0x4085u  /* operand of LD A,n at 4084: height of the cell expanded (PC CHR_PATH_HEIGHT BEF6) */
#define D64_CHR_PATH_SMC_RET        0x40C2u  /* opcode at 40C2: C9 (RET) the square check only checks, 00 (NOP) search mode
                                                (PC CS:3B02) */
#define D64_CHR_DIR_BUFFER_STEP     0x4180u  /* 4 words: height-buffer step of each orientation (+1, -24, -1, +24) (PC BEAB) */
#define D64_CHR_ADSO_DIR_CHOICES    0x4188u  /* 8 entries of 4 orientations (PC CHR_ADSO_DIR_CHOICES BEB3) */
#define D64_CHR_PATH_SOLUTION       0x41D4u  /* operand of LD SP,nn at 41D3: the queue word that reached the target
                                                (PC CHR_PATH_SOLUTION AC5B) */
#define D64_CHR_PATH_DY_TMP         0x4211u  /* operand of ADD A,n at 4210: dy+1 during the reconstruction (PC CHR_PATH_DY_TMP BEF9) */
#define D64_CHR_PATH_CANDIDATE      0x422Cu  /* operand of LD DE,nn at 422B: the queued cell next to the current one
                                                (PC CHR_PATH_CANDIDATE BEFA) */
#define D64_CHR_CMD_GENERATOR       0x436Au  /* operand of CALL nn at 4369: the command generator, 41C9 the path found or
                                                41B8 one step (PC CHR_CMD_GENERATOR BEF7) */
#define D64_SPR_MONK_ROBES          0x4431u  /* 16 words: robe graphics of the monks; bit 14 = drawn mirrored (PC SPR_MONK_ROBES AC9E) */
#define D64_SPR_LIGHT_PATTERN       0x4451u  /* 15 big-endian words: the lamp's circle of light (PC SPR_LIGHT_PATTERN ACBE) */
#define D64_SPR_BUF_FREE            0x4471u  /* word: first free byte of the sprite buffer (PC SPR_BUF_FREE ACDE) */
#define D64_SPR_SAVED_SP            0x4473u  /* word: SP at the entry of spr_draw_all (PC SPR_SAVED_SP ACE0) */
#define D64_SPR_OVERLAY_CURSOR      0x4475u  /* word: the next sprite of the list to overlay (PC SPR_OVERLAY_CURSOR ACE2) */
#define D64_SPR_OV_SRC_Y            0x4614u  /* word operand of LD HL,nn at 4613: lines of the sprite skipped (PC SPR_OV_SRC_Y ACF2) */
#define D64_SPR_OV_SRC_X            0x467Cu  /* operand of LD A,n at 467B: bytes of the sprite skipped (PC SPR_OV_SRC_X ACEA) */
#define D64_SPR_OV_DST_Y            0x4684u  /* word operand of LD HL,nn at 4683: first line in the rectangle (PC SPR_OV_DST_Y ACF4) */
#define D64_SPR_CUR_BUFFER          0x4690u  /* word operand of LD HL,nn at 468F: the buffer of the rectangle (PC SPR_CUR_BUFFER ACE4) */
#define D64_SPR_OV_DST_X            0x4694u  /* operand of LD A,n at 4693: first byte in the rectangle (PC SPR_OV_DST_X ACEE) */
#define D64_SPR_OV_LINE             0x46A1u  /* operand of LD C,n at 46A0: the sprite line counter's start (PC SPR_OV_LINE ACF6) */
#define D64_SPR_OV_LINES            0x46A4u  /* operand of LD B,n at 46A3: lines to merge (PC SPR_OV_LINES ACF0) */
#define D64_SPR_OV_WIDTH            0x46A7u  /* operand of LD B,n at 46A6: bytes per line to merge (PC SPR_OV_WIDTH ACE8) */
#define D64_SPR_OV_MIRROR_CALL      0x46AEu  /* opcode at 46AE: CC (CALL Z: plain) or C4 (CALL NZ: mirrored, spr_mirror_byte) */
#define D64_SPR_OV_SRC_STEP         0x46C3u  /* opcode at 46C3: 23 (INC HL) or 2B (DEC HL, mirrored) */
#define D64_SPR_OV_SRC_STRIDE       0x46C9u  /* word operand of LD DE,nn at 46C8: the sprite's width (PC SPR_OV_SRC_STRIDE ACF8) */
#define D64_SPR_OV_SRC_X_ROBE       0x4703u  /* operand of ADD A,n at 4702: bytes skipped in the robe (PC SPR_OV_SRC_X_ROBE ACEC) */
#define D64_SPR_OV_DST_STRIDE       0x470Bu  /* operand of LD A,n at 470A: the rectangle's width (PC SPR_OV_DST_STRIDE ACFA) */
#define D64_SPR_LIGHT_FILL_A        0x4738u  /* word operand of LD BC,nn at 4737: the light's top band (PC SPR_LIGHT_FILL_A AD1A) */
#define D64_SPR_LIGHT_DX            0x4756u  /* operand of LD B,n at 4755: dark bytes left of the circle (PC SPR_LIGHT_DX AD16) */
#define D64_SPR_LIGHT_FLIP          0x476Du  /* opcode at 476D: 29 (ADD HL,HL, one more shift) or 00, written by 22D0 */
#define D64_SPR_LIGHT_DX_REST       0x4782u  /* operand of LD B,n at 4781: dark bytes right of the circle (PC SPR_LIGHT_DX_REST AD18) */
#define D64_SPR_LIGHT_FILL_B        0x479Eu  /* word operand of LD BC,nn at 479D: the light's bottom band (PC AD1C) */
#define D64_SPR_BLIT_LINES          0x4863u  /* operand of LD B,n at 4862 (PC SPR_BLIT_LINES AD08) */
#define D64_SPR_BLIT_WIDTH          0x4868u  /* word operand of LD BC,nn at 4867 (PC SPR_BLIT_WIDTH AD06) */
#define D64_SPR_BLIT_SKIP           0x486Du  /* operand of LD A,n at 486C (PC SPR_BLIT_SKIP AD00) */
#define D64_SPR_TILE_UNMARK_HOOK    0x491Bu  /* opcode at 491B: C9 (RET) or 00 (NOP: spr_tile_unmark_body) (PC CS:1A2A) */
#define D64_SPR_DEPTH_UPPER         0x4972u  /* word operand of LD BC,nn at 4971 (PC SPR_DEPTH_UPPER ACE6) */
#define D64_SPR_DEPTH_LOWER         0x4975u  /* word operand of LD HL,nn at 4974 (PC SPR_DEPTH_LOWER AD0A) */
#define D64_SPR_TILE_TEST_JUMP      0x497Du  /* word operand of JP NZ,nn at 497C: 497F the depth test, 49AA draw (PC AD0C) */
#define D64_SPR_TILE_DST_SKIP       0x4A28u  /* operand of LD A,n at 4A27 (low) ... */
#define D64_SPR_TILE_DST_SKIP_HI    0x4A2Cu  /* ... and of LD A,n at 4A2B (high): the merge's next-line step (PC SPR_TILE_DST_SKIP AD0E) */
#define D64_SPR_TILE_COPY_SKIP      0x4A44u  /* operand of LD A,n at 4A43 (low) ... */
#define D64_SPR_TILE_COPY_SKIP_HI   0x4A48u  /* ... and of LD A,n at 4A47 (high): the opaque copy's next-line step */
#define D64_ISO_SPIRAL_RUNS         0x4A4Fu  /* 4 entries of 4 bytes (run length, buffer step low, screen step low, high
                                                byte of both) of iso_draw_room_spiral (PC ISO_SPIRAL_DOWN/RIGHT/UP/LEFT) */

/* ---- other groups' tables ---- */
#define D64_TXT_PHRASE_SOUND        0x51AFu  /* one byte per phrase (PC TXT_PHRASE_SOUND BF4B) */
#define D64_SPR_BUFFER              0x7F80u  /* sprite buffer; the path records of chr_cmd_write_path (PC SPR_BUFFER E68E) */
#define D64_ISO_TILE_GFX_HIGH       0x8300u  /* graphics of the tiles 80h-FFh, 32 bytes each from 8300h + 32n (tiles below
                                                80h live in the unused tails of the screen's 2 KiB blocks, C6xx-FFxx) */
#define D64_PATH_QUEUE              0x877Eu  /* the searches' queue: SP is set here and the queue grows down (PC 1800:EE8C) */
#define D64_CHR_PATH_FLOOR_TARGET_TEST  0x440Du  /* the opcode byte of the BIT n,(IX+0) of 440A, the floor search's target test (datos_camino.h) */
#define D64_ISO_TILE_BUFFER         0x8780u  /* the tile buffer 8780-8EFF (spr_tile_ptr_check); 8594 + 12 y + 1.5 x */
#define D64_VID_TILE_OR_A           0x8F00u  /* OR table (AND at 9000) of the tiles 0Bh-7Fh */
#define D64_VID_TILE_OR_B           0x9100u  /* OR table (AND at 9200) of the tiles 80h-FFh */
#define D64_TXT_PHRASES             0xBB00u  /* the phrases, FF-terminated (PC TXT_PHRASES C565) */
#define D64_SYS_FRAME_TICKS_NORMAL  0xBF49u  /* the normal frame budget (PC SYS_FRAME_TICKS_NORMAL AE83) */

#endif
