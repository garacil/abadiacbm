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

/* abadia64ks, group motor_iso (64K 128F-2225): the isometric engine.  The addresses it uses in the
 * CPC 64 KiB memory (ds[]), with the PC rebuild's names (c/include/direcciones.h) when the datum is
 * the same; "SMC" marks an operand or an instruction of the code that the program rewrites (it is
 * data at its code address).  Then the interpreter's state and the group's functions. */
#ifndef DATOS_MOTOR_ISO_H
#define DATOS_MOTOR_ISO_H

#include <stdbool.h>
#include <stdint.h>

/* ---- rooms and the tile buffer ---------------------------------------------------------------- */
#define D64_ISO_ROOM_PTR            0x11DAu  /* word: the record of the current room in the room table 6100h (written by iso_select_room 2855); PC iso_room_ptr */
#define D64_ISO_ROOM_DARK           0x11DCu  /* byte: not 0 when the room shown is dark; PC iso_room_dark */
#define D64_ISO_BLOCK_TABLE         0x11DDu  /* words: block type (entry byte 0 & FEh) -> block (word tile list, then the script); PC iso_block_table */
#define D64_ISO_PUT_TILE_JUMP       0x12C0u  /* word, SMC: target of the JP at 12BF in iso_put_tile: 12C9h (cell update) or 12C2h (tile at cell + 780h) */
#define D64_ISO_PUT_TILE_UPDATE     0x12C9u  /* the cell update of iso_put_tile (set by iso_draw_room before building) */
#define D64_ISO_PUT_TILE_MARK       0x12C2u  /* the other form: the tile number at cell + 780h (set by iso_draw_room after building) */
#define D64_ISO_CUR_BLOCK           0x1697u  /* word, SMC: operand of LD HL,nn at 1696: the block of the room entry being built; PC iso_cur_block */
#define D64_VID_FILL_BYTE           0x16C0u  /* byte, SMC: operand of LD (HL),n at 16BF: the fill byte of vid_fill_play_area */
#define D64_ISO_TILE_BUFFER         0x8780u  /* bytes:0x780, 20 rows x 16 columns x 6 bytes: [0],[1] lower depth, [2] lower tile, [3],[4] depth, [5] tile; PC iso_tile_buffer */
#define D64_ISO_TILE_BUFFER_SIZE    0x0780u
#define D64_ISO_TILE_MARKS          0x8F00u  /* bytes:0x780, = tile buffer + 780h: written only by the 12C2h form of iso_put_tile (never in the 64K game) */
#define D64_VID_SCREEN              0xC000u  /* the CPC screen (mode 1, 64 bytes a line): the play area is its first 160 lines */

/* ---- the block interpreter -------------------------------------------------------------------- */
#define D64_ISO_KEEP_FLAG           0x1BDCu  /* byte: set by CALL_KEEP, the next END keeps the mirror state; PC iso_keep_flag */
#define D64_ISO_BLOCK_TILES         0x1BDDu  /* bytes:12, registers 61h-6Ch (t1-t12): the tile list of the block; PC iso_block_tiles */
#define D64_ISO_BLOCK_P1            0x1BE9u  /* byte, register 6Dh: p1 (bits 5-7 of entry byte 1); with p2 the word BC; PC iso_block_p1 */
#define D64_ISO_BLOCK_P2            0x1BEAu  /* byte, register 6Eh: p2 (bits 5-7 of entry byte 2); PC iso_block_p2 */
#define D64_ISO_BLOCK_HEIGHT        0x1BEBu  /* byte, register 6Fh: the entry's height, FF = none; PC iso_block_height */
#define D64_ISO_DEPTH_X             0x1BECu  /* byte, register 70h: depth x put with every tile; PC iso_depth_x */
#define D64_ISO_DEPTH_Y             0x1BEDu  /* byte, register 71h: depth y; PC iso_depth_y */
#define D64_ISO_BLOCK_OPCODE_TABLE  0x1BEEu  /* words:28, the handlers of opcodes FF down to E4 (index (~op * 2) & FFh); PC iso_block_opcode_table */
#define D64_ISO_OP_X_INC_INSN       0x1C60u  /* byte, SMC: the instruction of X_INC (F5): INC L (2Ch), DEC L (2Dh) while mirroring */
#define D64_ISO_OP_X_DEC_INSN       0x1C66u  /* byte, SMC: the instruction of X_DEC (F3): DEC L (2Dh), INC L (2Ch) while mirroring */
#define D64_ISO_STEP_UP_INSN        0x1CF8u  /* byte: the step after the CALL of TILES_UP (F9): DEC H (25h) */
#define D64_ISO_STEP_LEFT_INSN      0x1CFFu  /* byte: the step after the CALL of TILES_LEFT (EB): DEC L (2Dh) */
#define D64_ISO_STEP_RIGHT_INSN     0x1D06u  /* byte, SMC: the step after the CALL of TILES_RIGHT (F8): INC L (2Ch), DEC L while mirroring */
#define D64_ISO_TILE_STEP_INSN      0x1D29u  /* byte, SMC: the step instruction of iso_put_tile_step, copied by iso_tile_run from its caller */
#define D64_ISO_ENTER_VECTOR        0x1DFCu  /* word, SMC: operand of JP nn at 1DFB: 17F1h (CALL) or 17EEh (CALL_KEEP); PC iso_enter_vector */
#define D64_ISO_MIRROR              0x1E3Eu  /* byte, SMC: operand of XOR n at 1E3D: 1 while the block is mirrored (operands 70h/71h swap); PC iso_mirror */

#define D64_ISO_INSN_INC_H          0x24u    /* the step instructions the program writes or keeps at the SMC sites */
#define D64_ISO_INSN_DEC_H          0x25u
#define D64_ISO_INSN_INC_L          0x2Cu
#define D64_ISO_INSN_DEC_L          0x2Du

/* the handlers of the opcode table (code addresses) and the two return tags of END */
#define D64_ISO_OP_END              0x1C40u  /* FF END */
#define D64_ISO_OP_Y_INC            0x1C5Du  /* F6 */
#define D64_ISO_OP_X_INC            0x1C60u  /* F5 (SMC instruction) */
#define D64_ISO_OP_Y_DEC            0x1C63u  /* F4 */
#define D64_ISO_OP_X_DEC            0x1C66u  /* F3 (SMC instruction) */
#define D64_ISO_OP_Y_ADD            0x1C69u  /* F2 expr */
#define D64_ISO_OP_X_ADD            0x1C74u  /* F1 expr */
#define D64_ISO_OP_P2_INC           0x1C7Fu  /* EF */
#define D64_ISO_OP_P1_INC           0x1C85u  /* F0 */
#define D64_ISO_OP_P2_DEC           0x1C8Bu  /* ED */
#define D64_ISO_OP_P1_DEC           0x1C91u  /* EE */
#define D64_ISO_OP_LOOP_P1          0x1C9Fu  /* FE */
#define D64_ISO_OP_LOOP_P2          0x1CACu  /* FD */
#define D64_ISO_OP_PUSH_POS         0x1CDDu  /* FC */
#define D64_ISO_OP_POP_POS          0x1CE1u  /* FB */
#define D64_ISO_OP_NEXT             0x1CE5u  /* FA */
#define D64_ISO_OP_TILES_UP         0x1CF5u  /* F9 tiles */
#define D64_ISO_OP_TILES_LEFT       0x1CFCu  /* EB tiles */
#define D64_ISO_OP_TILES_RIGHT      0x1D03u  /* F8 tiles */
#define D64_ISO_OP_SET              0x1D4Fu  /* F7 reg expr */
#define D64_ISO_OP_MIRROR           0x1D9Bu  /* E9-E5 */
#define D64_ISO_OP_JUMP             0x1DAFu  /* EA addr */
#define D64_ISO_OP_CALL_KEEP        0x1DB8u  /* E4 block */
#define D64_ISO_OP_CALL             0x1DC2u  /* EC block */
#define D64_ISO_ENTER_BLOCK_KEEP    0x17EEu  /* iso_enter_block_keep_tiles, the vector of CALL_KEEP */
#define D64_ISO_ENTER_BLOCK         0x17F1u  /* iso_enter_block, the vector of CALL */
#define D64_ISO_TAG_NEXT_ENTRY      0x163Fu  /* END returns here: the next entry of the room (iso_build_room) */
#define D64_ISO_TAG_CALL_RETURN     0x1DFEu  /* END returns here: the end of a called block (iso_call_return) */

/* ---- the camera and the room shown ------------------------------------------------------------ */
#define D64_ISO_FLOOR0_MAP          0x1E79u  /* bytes, room map of floor 0 (room number per (Y << 4) | X) */
#define D64_ISO_FLOOR1_MAP          0x1F09u  /* room map of floor 1 */
#define D64_ISO_FLOOR2_MAP          0x1F11u  /* room map of floor 2 */
#define D64_ISO_CAMERA_ROTATIONS    0x1E81u  /* ptrs:4, the camera transform per orientation: 20AE, 20A9, 20AF, 20B8; PC iso_camera_rotations */
#define D64_ISO_FLOOR_MAP_PTR       0x2013u  /* word, SMC: operand of LD HL,nn at 2012: the map of the floor shown; PC iso_floor_map_ptr */
#define D64_ISO_SETUP_SPRITE        0x2070u  /* word, SMC: operand of LD IX,nn at 206E: the sprite of the chr_table entry being set up; PC iso_setup_sprite */
#define D64_ISO_SETUP_RECORD        0x2074u  /* word, SMC: operand of LD IY,nn at 2072: its character record; PC iso_setup_record */
#define D64_ISO_CAMERA_ORIENT       0x20A5u  /* byte, SMC: operand of SUB n at 20A4: the camera orientation of the room shown; PC iso_camera_orient */
#define D64_CHR_CUR_FLIP            0x25AEu  /* word, SMC: operand of CALL NZ,nn at 25AD: the flip routine of the character; PC chr_cur_flip */
#define D64_CHR_CUR_ANIM            0x25D9u  /* word, SMC: operand of LD DE,nn at 25D8: its animation table; PC chr_cur_anim */
#define D64_CHR_ROOM_ORIGIN_X       0x2636u  /* byte, SMC: operand of SUB n at 2635 (chr_project): (room x & F0) - 0Ch; PC chr_room_origin_x */
#define D64_CHR_ROOM_ORIGIN_Y       0x2640u  /* byte, SMC: operand of SUB n at 263F: (room y & F0) - 0Ch; PC chr_room_origin_y */
#define D64_CHR_ROOM_FLOOR          0x264Eu  /* byte, SMC: operand of CP n at 264D: the floor base of the room shown; PC chr_room_floor */
#define D64_CHR_CAMERA_TRANSFORM    0x2656u  /* word, SMC: operand of CALL nn at 2655: the camera transform; PC chr_camera_transform */
#define D64_CHR_TABLE               0x2703u  /* bytes, entries of 10 (sprite, record, -, flip, anim), FF in byte 1 ends; PC chr_table */
#define D64_CHR_ROOM_X              0x28C6u  /* byte: x & F0 of the room shown; PC chr_room_x */
#define D64_CHR_ROOM_Y              0x28C7u  /* byte: y & F0 of the room shown; PC chr_room_y */
#define D64_CHR_ROOM_Z              0x28C8u  /* byte: floor base of the room shown; PC chr_room_z */
#define D64_CHR_SPRITE_OFFSETS      0x28D5u  /* word: chr_sprite_offset_tables + 40h * orientation; PC chr_sprite_offsets */
#define D64_CHR_CAMERA_TARGET       0x28D9u  /* word: the record of the character the camera follows; PC chr_camera_target */
#define D64_ISO_ROOM_CHANGED        0x2909u  /* byte: not 0 when the camera changed room (the main loop redraws it); PC iso_room_changed */
#define D64_SPR_LIGHT               0x2B20u  /* the sprite record of the lamp light (FE = hidden); PC spr_light */
#define D64_CHR_SPRITE_OFFSET_TABLES 0x2BF0u /* bytes:0x100, 4 orientations x 40h; PC chr_sprite_offset_tables */
#define D64_ISO_DARK_FLOOR          0x16u    /* the floor base whose rooms can be dark (CP 16h at 1FCD; PC reads it from iso_dark_floor) */

/* ---- the interpreter's state ------------------------------------------------------------------ */
/* What the Z80 keeps in registers and on its stack while it interprets a room (a local of the
 * builder: nothing of it lives after the room is built).  hl, bc, de and ix are the Z80 registers as
 * the handlers leave them; pila holds, in the Z80's order, the words it pushes and pops across
 * handlers: the return tags (163F, 1DFE), the saved script pointers, the loop frames (start, count),
 * the positions of PUSH_POS and the CALL frames. */
#define ISO_VM_PILA 64
typedef struct {
    uint16_t hl;                 /* HL: the position, H = y, L = x */
    uint16_t bc;                 /* BC: C = the last operand value or loop count, B kept or a leftover */
    uint16_t de;                 /* DE: the address of the last handler (what the dispatcher leaves) */
    uint16_t ix;                 /* IX: the script (or room entry) pointer */
    uint16_t ret;                /* the tag END returned to; 0 while interpreting */
    uint8_t sp;                  /* words in pila */
    uint16_t pila[ISO_VM_PILA];
} iso_vm;

/* ---- the functions of the group (f_motor_iso.c) ----------------------------------------------- */
uint16_t util_add_bx_al(uint16_t hl, uint8_t a);
uint8_t iso_put_tile(uint16_t pos, uint8_t tile, uint16_t *de);
bool iso_draw_room(iso_vm *vm);
void iso_build_room(iso_vm *vm);
uint16_t vid_fill_play_area_ff(uint16_t *de);
uint16_t iso_clear_tile_buffer(uint8_t fill, uint16_t *de);
uint16_t vid_fill_play_area(uint8_t fill, uint16_t *de);
void iso_enter_block_keep_tiles(iso_vm *vm, uint8_t height);
void iso_enter_block(iso_vm *vm, uint16_t tiles, uint8_t height);
void iso_block_depth(uint16_t pos, uint8_t height);
uint8_t iso_tile_run(uint16_t step, uint16_t *pos, uint16_t *ix, uint16_t *bc);
uint16_t iso_put_tile_step(uint16_t pos, uint8_t tile, uint8_t *a, uint16_t *de);
uint16_t iso_put_tile_times(uint16_t pos, uint8_t tile, uint16_t *de);
uint8_t iso_expression(uint8_t first, uint16_t *ix);
uint16_t iso_fetch_word(uint16_t *ix);
uint8_t iso_fetch_operand(uint16_t *ix, uint16_t *reg);
uint8_t iso_operand_value(uint8_t code, uint16_t *ix, uint16_t *reg);
uint16_t vid_set_crtc(uint16_t data);
bool iso_update_camera_room(void);
void spr_update_char_sprite(uint16_t spr, uint16_t chr);
uint8_t iso_floor_base(uint8_t z);
uint8_t iso_orient_relative(uint8_t o);
uint16_t iso_rotate_cam1(uint16_t xy);
uint16_t iso_rotate_cam0(uint16_t xy);
uint16_t iso_rotate_cam2(uint16_t xy);
uint16_t iso_rotate_cam3(uint16_t xy);

#endif
