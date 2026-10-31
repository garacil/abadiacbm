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

/* abadia64ks, group principal (f_principal.c): the CPC 64 KiB addresses of the start, the main loop, the
 * debug exit, the interrupt vector, the CTRL+TAB menu (save and load to tape) and the tape blocks.  Names
 * of data other groups use are those of their headers (the same value). */
#ifndef DATOS_PRINCIPAL_H
#define DATOS_PRINCIPAL_H

#define D64_SYS_STACK_TOP           0xC000u  /* the SP the game is started with (estado.txt): the main loop's SP */
#define D64_SYS_SAVED_SP            0x2913u  /* word: SP saved by the main start (215E) and by the tape routines
                                                (32B5, 337B); read by the debug exit (1E5A, 2212) */
#define D64_SYS_STARTUP_DONE        0x00FEu  /* byte: 0Dh once sys_startup_init (3568) has run */
#define D64_SYS_TICKS               0x289Cu  /* the 300 Hz tick counter (sys_tick) */
#define D64_SYS_FRAME_TICKS         0x21DAu  /* the operand of the CP n at 21D9: the ticks a frame waits for */
#define D64_SYS_FRAME_TICKS_NORMAL  0xBF49u  /* the normal frame budget (copied to 21DA at a new game) */
#define D64_VEC_INTERRUPT           0x0038u  /* the IM 1 vector: JP 2899 (sys_tick) from 20EA, a RET from 1E5E */
#define D64_VEC_RST08               0x0008u  /* RST 08h: JP 391E (ai_script_test) from 20F2 */
#define D64_VEC_RST10               0x0010u  /* RST 10h: JP 38FC (ai_script_assign) from 20F5 */
#define D64_VEC_4AFC                0x4AFCu  /* a byte the start sets to C3h (JP) as the three vectors; never executed */
#define D64_SND_TEMPO_RELOAD        0x0CF6u  /* the operand of LD A,n at 0CF5 (the sound's tempo reload): 6 */
#define D64_GAME_START_POS          0xBF50u  /* word: Guillermo's x, y at a new game (Adso: x - 2, y + 2) */
#define D64_GAME_START_Z            0xBF52u  /* byte: their height at a new game */
#define D64_CHR_GUILLERMO           0x2B87u  /* Guillermo's record (byte 0: the animation counter, bit 0 = half step) */
#define D64_CHR_GUILLERMO_XY        0x2B89u  /* Guillermo's x, y (record 2B87 + 2) */
#define D64_CHR_GUILLERMO_Z         0x2B8Bu  /* Guillermo's height */
#define D64_CHR_ADSO_XY             0x2B98u  /* Adso's x, y (record 2B96 + 2) */
#define D64_CHR_ADSO_Z              0x2B9Au  /* Adso's height */
#define D64_CHR_GUILLERMO_FLIP      0x2B8Du  /* Guillermo's flip state (record + 6); the others 0Fh apart */
#define D64_CHR_ADSO_FLIP           0x2B9Cu  /* Adso's flip state */
#define D64_SPR_GFX_SOURCE          0xAB59u  /* 2D5h bytes of graphics copied to AE2Eh at a new game and mirrored */
#define D64_SPR_GFX_COPY            0xAE2Eu  /* their copy (5 bytes x 91h lines, then mirrored by 2F57) */
#define D64_CHR_CMD_BUFFER_HEADS    0x3568u  /* the 5 command buffers of the characters, 2Dh bytes apart: 10h (think
                                                again) at a new game */
#define D64_CHR_ROOM_X              0x28C6u  /* x & F0 of the room shown; 0 forces a rebuild */
#define D64_CHR_GUILLERMO_STATE     0x23E4u  /* 0 normal, >1 the fall of the mirror trap */
#define D64_CHR_GUILLERMO_FALL_DY   0x2406u  /* the sprite y step of that fall */
#define D64_CHR_GUILLERMO_ANIM_COPY 0x0600u  /* the operand of LD A,n at 05FF: [2B87] copied each frame */
#define D64_ISO_ROOM_CHANGED        0x2909u  /* not 0 when the camera changed room (the room is drawn again) */
#define D64_OBJ_ROOM_REDRAW         0x0A6Du  /* the operand of OR n at 0A6C: 80h after a room was drawn */
#define D64_CHR_PATH_FOUND_NOW      0x28FAu  /* 1 when a route was found in this iteration */
#define D64_SND_CHANNEL_MASK_COPY   0x0C07u  /* the PSG mixer copy: 3Fh in the pauses */
#define D64_OBJ_MIRROR_HEIGHT_PTR   0x2EDEu  /* word: the address of the mirror's height byte */
#define D64_OBJ_MIRROR_NUMERAL      0x290Du  /* the stair numeral of the mirror riddle (0: not chosen) */
#define D64_AI_UNUSED_3CAD          0x3CADu  /* script var BCh, write-only */
#define D64_STATE_BUFFER            0x7F80u  /* the saved game: 28D0h-2C07h (338h bytes), 37D2h-3899h (C8h), the
                                                command buffers 3568h-3666h (FFh) and a checksum, 5DCh bytes
                                                (the tape block ends at 855Bh: loaded downwards) */
#define D64_STATE_PART1             0x28D0u  /* 338h bytes saved (320h restored) */
#define D64_STATE_PART2             0x37D2u  /* C8h bytes saved (98h restored), at buffer + 338h */
#define D64_STATE_PART3             0x3568u  /* FFh bytes saved (E0h restored), at buffer + 400h */
#define D64_STATE_BLOCK_END         0x855Bu  /* the last byte of the saved block */
#define D64_STATE_BLOCK_LEN         0x05DCu  /* its length */
#define D64_STATE_BLOCK_ID          0x0Cu    /* its sync byte on the tape */
#define D64_STATE_SUM_LEN           0x05DAu  /* the bytes summed by 3254 (its loop stops when BC < 100h) */
#define D64_TAPE_LOADER_STATE       0x33E3u  /* the operand of ADD A,n at 33E2 (the loader's border step): 0 while
                                                looking for the leader, 4, then 1 for the bytes */
#define D64_TAPE_MARKER_TABLE       0x328Bu  /* 8 bytes swapped with the screen column C000h (the menu's blinking mark) */
#define D64_ENDING_BLOCK_END        0x8BFFu  /* the ending on the tape: 2C00h bytes ending at 8BFFh (6000h-8BFFh), block 2Ah */
#define D64_ENDING_BLOCK_LEN        0x2C00u
#define D64_ENDING_BLOCK_ID         0x2Au

#endif
