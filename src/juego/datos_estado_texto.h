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

/* abadia64ks: the CPC 64 KiB addresses used by the group estado_texto (f_estado_texto.c): the game
 * state blocks, the text and the phrase scroller, the room height buffer, the script engine (RST 08h /
 * RST 10h), the palette and the start-up.  PC names (c/include/direcciones.h) where the datum is the
 * same; self-modified operands are named at their code address. */
#ifndef DATOS_ESTADO_TEXTO_H
#define DATOS_ESTADO_TEXTO_H

/* ---- low RAM ---- */
#define D64_SYS_STARTUP_DONE          0x00FEu  /* byte: 0Dh once sys_startup_init (3568) has run; 20BE skips it then */
#define D64_GAME_INITIAL_STATE        0x0103u  /* A7h bytes: copy of the 16 state blocks taken at start-up; PC game_initial_state */
#define D64_CHR_ROOM_LINKS            0x023Du  /* room connection bytes of the 3 floors; PC chr_room_links */
#define D64_SND_CHANNEL_MASK_COPY     0x0C07u  /* byte: copy of the PSG mixer value; the pause sets 3Fh; PC snd_channel_mask_copy */
#define D64_SND_VOICE_TONE_A          0x0FF9u  /* byte: low 3 bits of each letter printed; PC snd_voice_tone_a */
#define D64_SND_VOICE_TONE_NEG        0x0FFCu  /* byte: their negation; PC snd_voice_tone_neg */
#define D64_SND_VOICE_TONE_B          0x0FFFu  /* byte: = snd_voice_tone_a; PC snd_voice_tone_b */
#define D64_SND_VOICE_LEVEL           0x1032u  /* byte: 6 while a letter is printed, 0 for a blank; PC snd_voice_level */

/* ---- the height buffer window (motor) ---- */
#define D64_CHR_HBUF_ORIGIN_Y         0x22F2u  /* byte: world y of row 0 of the 24x24 height buffer; PC chr_hbuf_origin_y */
#define D64_CHR_HBUF_ORIGIN_X         0x22FEu  /* byte: world x of column 0; PC chr_hbuf_origin_x */

/* ---- 28D0-28F3: state block 6 and the text variables ---- */
#define D64_CHR_CAMERA_TARGET         0x28D9u  /* word: record of the character followed by the camera; PC chr_camera_target */
#define D64_CHR_HBUF_PTR              0x28DBu  /* word: the height buffer (24x24 bytes); PC chr_hbuf_ptr */
#define D64_ISO_MIRROR_STATE_GUILLERMO 0x28DEu /* 4Ch bytes cleared by a new game (28DE-2929); PC iso_mirror_state_guillermo */
#define D64_TXT_CURSOR                0x28E8u  /* word: text position, low byte x in bytes, high byte y in lines; PC txt_cursor */
#define D64_TXT_SCROLL_TIMER          0x28EBu  /* byte: interrupts counted by txt_phrase_tick, a character every 2Dh; PC txt_scroll_timer */
#define D64_TXT_TRAILING_BLANKS       0x28ECu  /* byte: blanks still to print after the phrase end (11h); PC txt_trailing_blanks */
#define D64_TXT_WORD_PTR              0x28EDu  /* word: next letter of the word being printed; PC txt_word_ptr */
#define D64_TXT_PHRASE_PTR            0x28EFu  /* word: next byte of the phrase; PC txt_phrase_ptr */
#define D64_TXT_WORD_DONE             0x28F1u  /* byte: 1 when the word is finished; PC txt_word_done */
#define D64_TXT_PHRASE_BUSY           0x28F2u  /* byte: copy of txt_phrase_active taken each frame; PC txt_phrase_busy */
#define D64_TXT_PHRASE_ACTIVE         0x28F3u  /* byte: nonzero while a phrase scrolls; PC txt_phrase_active */

/* ---- objects, characters, sprites ---- */
#define D64_OBJ_DOOR_PERMISSIONS      0x292Au  /* 6 x 3 bytes; PC obj_door_permissions */
#define D64_OBJ_CHAR_OBJECTS          0x293Du  /* 7-byte entries, +3 = the objects mask; PC obj_char_objects */
#define D64_GAME_ADSO_LAMP            0x2944u  /* the holder of the lamp when taken; PC game_adso_lamp */
#define D64_SPR_TABLE                 0x2968u  /* sprite records of 20 bytes, byte 0 FEh = inactive, FFh ends; PC spr_table */
#define D64_OBJ_DOORS                 0x2B35u  /* door records of 5 bytes; PC obj_doors */
#define D64_OBJ_OBJECTS               0x2B59u  /* object records of 5 bytes; PC obj_objects */
#define D64_CHR_GUILLERMO             0x2B87u  /* character records of 15 bytes (Guillermo first); PC chr_guillermo */
#define D64_CHR_MALACHI               0x2BA5u  /* the record of Malaquias (first of the 4 monks); PC chr_malachi */
#define D64_SPR_MONK_FACES            0x2BE8u  /* 4 words: face graphics of the 4 monks; PC spr_monk_faces */
#define D64_OBJ_MIRROR_HEIGHT_PTR     0x2EDEu  /* word: the end of the second-floor height list; PC obj_mirror_height_ptr */
#define D64_OBJ_MIRROR_ENTRY_PTR      0x2EE5u  /* word: byte 2 of the mirror block of room 72h (11h closed, 51h open); PC obj_mirror_entry_ptr */
#define D64_CHR_POS_PTRS              0x30F0u  /* 6 words: the characters' position pointers; PC chr_pos_ptrs */

/* ---- the state blocks ---- */
#define D64_GAME_STATE_BLOCK_FN       0x312Au  /* word: operand of the CALL at 3129 (self-modified): 3166 save / 316B restore; PC game_state_block_fn */
#define D64_GAME_STATE_BLOCKS         0x3134u  /* 16 x (word address, byte length) and a zero word; PC game_state_blocks */
#define D64_GAME_STATE_BLOCKS_END     0x3164u  /* the zero word that ends them */

/* ---- the height buffer fill (f_346E), self-modified code ---- */
#define D64_CHR_FLOOR_HEIGHTS_PTR     0x3454u  /* word: height list of the current floor; PC chr_floor_heights_ptr */
#define D64_CHR_HBUF_FLAT_WIDTH_OP    0x34EAu  /* byte: operand of LD B,n at 34E9: visible columns of a flat block */
#define D64_CHR_HBUF_SLOPE_WIDTH_OP   0x3510u  /* byte: operand of LD A,n at 350F: visible columns of a slope */
#define D64_CHR_HBUF_COL_STEP_OP      0x3515u  /* byte: opcode at 3515, the height step per column: NOP, INC C or DEC C */
#define D64_CHR_HBUF_ROW_STEP_OP      0x351Cu  /* byte: opcode at 351C, the height step per row: NOP, INC C or DEC C */
#define D64_CHR_HBUF_WIN_X_OP         0x354Au  /* byte: operand of LD L,n at 3549: the window's world x (= origin x) */
#define D64_CHR_HBUF_WIN_Y_OP         0x354Eu  /* byte: operand of LD L,n at 354D: the window's world y (= origin y) */
#define D64_OP_NOP                    0x00u    /* the opcodes stored there */
#define D64_OP_INC_C                  0x0Cu
#define D64_OP_DEC_C                  0x0Du
#define D64_CHR_HBUF_SIZE             0x18u    /* the buffer is 24 x 24 */

/* ---- the text ---- */
#define D64_TXT_PUNCTUATION           0x3447u  /* 5 glyph codes for the phrase bytes FA-FE; PC txt_punctuation */
#define D64_TXT_GLYPH_BLANK           0x344Cu  /* 8 zero bytes: the glyph of code 20h; PC txt_glyph_blank */
#define D64_TXT_FONT                  0xB400u  /* 8 bytes per glyph, codes 2Dh-5Ah; PC txt_font */
#define D64_TXT_WORDS                 0xB580u  /* the word dictionary (bit 7 ends a word); PC txt_words */
#define D64_TXT_STRIP                 0xE512u  /* screen: 1st byte moved by the phrase scroll (8 lines of 30 bytes from E510) */
#define D64_TXT_STRIP_CURSOR          0xA42Eu  /* txt_cursor of the letter printed at the right end of the strip (y A4h, x 2Eh) */

/* ---- the start-up ---- */
#define D64_CHR_COMMAND_BUFFERS       0x3568u  /* movement command buffers, over the start-up code once it has run; PC chr_command_buffers */
#define D64_ISO_ROOM_TABLE            0x6100u  /* the rooms, each led by its length byte; PC iso_room_table */
#define D64_HUD_HIDDEN_ROWS_SRC       0x8300u  /* 1000h bytes loaded into the hidden screen rows 24-31 at start-up */
#define D64_VID_COLOUR_TABLES         0x8F00u  /* 4 x 256 bytes of pixel masks built by vid_init_stub (over the end of 8300-92FF) */
#define D64_ISO_TILE_BUFFER           0x8780u  /* the tile buffer of the sprite drawing (8780-8EFF); PC iso_tile_buffer */
#define D64_ISO_TILE_BUFFER_SIZE      0x0780u
#define D64_CHR_FLOOR2_HEIGHTS        0x9F60u  /* the height list of the second floor; PC chr_floor2_heights */
#define D64_SCR_ROW20                 0xC500u  /* screen: character row 20 (the score bar) */
#define D64_SCR_ROW24                 0xC600u  /* screen: character row 24, the first hidden row (CRTC R6 = 24) */

/* ---- the script engine and the AI helpers ---- */
#define D64_OBJ_DOOR_LINK_TABLE       0x37B4u  /* per door: (index into chr_room_links, bits) pairs, FFh ends; PC obj_door_link_table */
#define D64_GAME_BOOK_POISON_COUNT    0x37D2u  /* first of the 21h bytes cleared by a new game (37D2-37F2); PC game_book_poison_count */
#define D64_AI_ADVANCE_HOUR           0x37E7u  /* byte: pass to the next hour when the phrase ends; PC ai_advance_hour */
#define D64_AI_NO_ROUTE               0x37E9u  /* byte: 1 = the character plans no route this frame; PC ai_no_route */
#define D64_AI_RANDOM                 0x37EAu  /* byte: copy of chr_command_buffers[0]; PC ai_random */
#define D64_OBJ_DOOR_CHECK_MASK       0x37F3u  /* byte: the doors whose permissions are applied; PC obj_door_check_mask */
#define D64_AI_SCRIPT_VARS            0x386Au  /* 64 words: the address of script variable 80h+i; PC ai_script_vars */
#define D64_AI_CLOSE_BOX_TABLE        0x38ECu  /* 4 x 4 bytes per orientation: x offset, x size, y offset, y size; PC ai_close_box_table */
#define D64_AI_SCRIPT_DEST_PTR        0x390Du  /* word: operand of LD (nn),A at 390C (self-modified): the variable assigned; PC ai_script_dest_ptr */
#define D64_AI_PHRASE_PARAM           0x3A5Bu  /* the inline phrase byte of the CALL 4B7C at 3A58: script variable A2h; datos_logica_b.h */
#define D64_OBJ_DOOR_ALLOW_OP         0x3A24u  /* byte: opcode at 3A24, CCF (3Fh, door allowed) or NOP (door forbidden) */
#define D64_OP_CCF                    0x3Fu
#define D64_VID_PALETTE_BLACK         0x3A73u  /* 5 hardware colours (pens 3, 2, 1, 0, border): all black */
#define D64_VID_PALETTE_DAY           0x3A78u  /* the day palette */
#define D64_VID_PALETTE_NIGHT         0x3A7Du  /* the night palette */

#endif
