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

/* abadia64ks, group principal: the CPC 64 KiB code that is no function of the other groups, in C: the
 * start and the main loop (20BE-2225), the debug exit (1E4B-1E6D), the IM 1 interrupt (0038h), the
 * CTRL+TAB menu that saves and loads the game on tape (31C1-32AA, 2FD7-304E) and the tape blocks
 * (32AB, 3371: their turbo code is the platform's, plat_cinta_*).  Each function cites its 64K address;
 * the 64K code (the cassette's, data/cpc64/juego/ram.bin) is the reference.
 *
 * The main loop and the waits.  The game is synchronous with the 300 Hz interrupt only at its wait points
 * (data/sincrono/puntos64.txt): the main loop's wait for the tick counter (21D6-21DB: plat_espera at
 * every pass), the wait for the space key at the end of a game (3EB8-3EC0, in game_check_end) and the
 * wait while space is held at a new game (20C7-20DD): plat_pausa at every pass (they count as frames).
 * A frame is a main-loop iteration: plat_frame at 2179h.  The interrupt itself is sys_interrupt, which
 * the platform calls when it delivers a tick with the interrupts enabled (plat_ei).
 *
 * The SP.  game_main takes the SP it is started with (D64_SYS_STACK_TOP): it is stored at 2913h (215E)
 * and the main loop's callees that store theirs (the path searches through 2226, spr_draw_all through
 * 2236 and 2265, the tape routines through 31DF) get the main loop's SP - 2, the SP of a CALL from it.
 *
 * Functions that do not return to their caller (31DF when a game is loaded, 1E4B, 20BE) are not in the
 * hybrid host's table: the hybrid runs the main loop in Z80 and they stay Z80 there; the pure C program
 * (puro.c) runs them. */
#include <stdio.h>
#include <string.h>
#include "juego64.h"
#include "datos_principal.h"

/* LDIR of n bytes (n = 0: 65536), outside the screen */
static void copia(uint16_t dst, uint16_t src, uint16_t n)
{
    do {
        wb(dst, rb(src));
        dst = (uint16_t)(dst + 1);
        src = (uint16_t)(src + 1);
    } while (--n);
}

/* ================================================================================ the interrupt */

/* 0038 sys_interrupt: the IM 1 interrupt (RST 38h) through the vector the game writes at 0038h: JP 2899h
 * (sys_tick, from 20EA) or a RET (C9h, from the debug exit 1E5E: nothing, the interrupts stay off until an
 * EI).  At the start of the 64K image 0038h is JP B900h, but the game runs with the interrupts off until
 * its own vector is in place (2178 EI).  The platform calls it for each tick it delivers (IFF1 set; the
 * acceptance clears IFF1 and IFF2 first). */
void sys_interrupt(void)
{
    if (rb(D64_VEC_INTERRUPT) == 0xC3 && rw((uint16_t)(D64_VEC_INTERRUPT + 1)) == 0x2899) sys_tick();
}

/* ================================================================================ the debug exit */

/* 1E4B game_exit (PC -): the developers' exit of the main loop (21F7-2225: never reached, the test
 * before it is always true): DI; [obj_mirror_height_ptr] := FFh (1E4F; the LD BC,7FC6h / 7FC0h of
 * the 6128's banks do nothing), snd_silence_all, SP := [2913], the interrupt vector := RET (C9h at 0038h),
 * the standard CRTC (1E63 CALL 1E6E <R1 28h, R2 2Eh, R6 19h>), and RET to whatever word the saved SP
 * points at (2212 left 0000h there after copying the 8 bytes of 221E to 0000h: OUT 7F89h, the lower ROM
 * on, and JP 0591h, the ROM: the CPC's reset).  The game ends: plat_salir. */
void game_exit(void)
{
    plat_di();                                              /* 1E4B */
    wb(rw(D64_OBJ_MIRROR_HEIGHT_PTR), 0xFF);                /* 1E4F-1E53 */
    snd_silence_all();                                      /* 1E57 */
    wb(D64_VEC_INTERRUPT, 0xC9);                            /* 1E5A-1E61 (SP := [2913] first) */
    (void)vid_set_crtc(0x1E66);                             /* 1E63 CALL 1E6E <01 28 02 2E 06 19 FF> */
    plat_salir();                                           /* 1E6D RET */
}

/* ================================================================================ the tape */

/* 31C1 util_delay_units (PC -): a times (0: 256) util_delay_cx(0), 65536 passes each (AF and BC kept).
 * Not a wait point of the synchronous mode: no time passes for the interrupt. */
void util_delay_units(uint8_t a)
{
    do {
        util_delay_cx(0);                                   /* 31C3-31C6 */
    } while (--a);                                          /* 31CB-31CC */
}

/* 3293 tape_motor_off (PC -): OUT (F6xx),00h: the cassette motor off (PPI port C bit 4).  Out: CF = 0. */
void tape_motor_off(void)
{
    plat_cinta_motor(0);                                    /* 3293-3296 */
}

/* 329A tape_motor_on (PC -): OUT (F6xx),10h: the motor on, then util_delay_units(2) (JP 31C1). */
void tape_motor_on(void)
{
    plat_cinta_motor(1);                                    /* 329A-329D */
    util_delay_units(2);                                    /* 329F-32A1 */
}

/* 32AB tape_load_block (PC -): loads the tape block whose sync byte is id & 7Fh: len bytes stored
 * downwards from end (the turbo loader 32AB-343E, own code: no firmware).  DI; RET address 3293 pushed
 * (the motor goes off at every exit), then DE, HL: [2913] := that SP (32B5); the motor on (329A); the
 * loader's state [33E3] := 0 and the first look at ESC (343F: sys_read_keyboard, key 42h down gives
 * up); the rest of the loader (the edges, the sync, the bytes, the border colours; it restarts on a wrong
 * sync or checksum and looks at ESC again) is the platform's plat_cinta_carga, with the loader's own
 * operands (33E1, 33E3, 3344, 3438) as the platform leaves them.  In: HL = end, DE = len, A = id; sp = the SP at its entry.  Out: true (CF = 0)
 * when the block was loaded; the motor off (3293, or 32A4 POP POP / CALL 3293 / SCF on a failure). */
bool tape_load_block(uint16_t end, uint16_t len, uint8_t id, uint16_t sp)
{
    uint8_t code;
    bool ok = false;
    plat_di();                                              /* 32AB */
    ww(D64_SYS_SAVED_SP, (uint16_t)(sp - 6));               /* 32AC-32B5: PUSH BC, DE, HL; LD (2913),SP */
    tape_motor_on();                                        /* 32B9 */
    wb(D64_TAPE_LOADER_STATE, 0);                           /* 32BC-32BD */
    sys_read_keyboard();                                    /* 32C0 CALL 343F: ESC gives up */
    if (!sys_key_down(0x42, &code)) ok = plat_cinta_carga(end, len, (uint8_t)(id & 0x7F));
    tape_motor_off();                                       /* RET to 3293, or 32A6 */
    return ok;
}

/* 3371 tape_save_block (PC -): saves len bytes downwards from end as a tape block with the sync byte
 * id & 7Fh (the turbo writer 3371-3416: plat_cinta_guarda).  DI; 3293 pushed, DE, HL; [2913] := SP;
 * the motor on; the leader, the sync, the bytes; RET to 3293 (motor off).  sp = the SP at its entry. */
void tape_save_block(uint16_t end, uint16_t len, uint8_t id, uint16_t sp)
{
    plat_di();                                              /* 3371 */
    ww(D64_SYS_SAVED_SP, (uint16_t)(sp - 6));               /* 3372-337B */
    tape_motor_on();                                        /* 337F */
    plat_cinta_guarda(end, len, (uint8_t)(id & 0x7F));
    tape_motor_off();                                       /* RET to 3293 */
}

/* 3254 game_state_checksum (PC -): the 8-bit sum of the saved game's bytes from 7F80h; its loop (DEC BC /
 * INC B / DJNZ from BC = 06D9h) stops when B reaches 0: 5DAh bytes, up to 8559h.  Out: A = the sum,
 * *hl = 855Ah (where the sum is kept, the last but one byte of the tape block). */
uint8_t game_state_checksum(uint16_t *hl)
{
    uint16_t p = D64_STATE_BUFFER, n;
    uint8_t a = 0;
    for (n = D64_STATE_SUM_LEN; n; --n) {                  /* 3254-3260 */
        a = (uint8_t)(a + rb(p));
        p = (uint16_t)(p + 1);
    }
    *hl = p;
    return a;
}

/* 3276 hud_tape_marker_swap (PC -): swaps the 8 bytes of the screen column C000h (one per pixel line,
 * C000h, C800h ... F800h) with the 8 bytes at 328Bh: the menu's blinking mark in the top left corner. */
void hud_tape_marker_swap(void)
{
    uint16_t scr = 0xC000, de = D64_TAPE_MARKER_TABLE;
    uint8_t b, c;
    for (b = 8; b; --b) {                                   /* 3276-3288 */
        c = rscr(scr);
        wscr(scr, rb(de));
        wb(de, c);
        de = (uint16_t)(de + 1);
        scr = (uint16_t)(scr + 0x0800);
    }
}

/* 3262 tape_menu_leave (PC -): the border black (gate array pen 10h := colour 54h & 1Fh), then the keyboard
 * is read until ESC (CPC key 42h) is up. */
void tape_menu_leave(void)
{
    uint8_t code;
    plat_tinta(0x10, 0x14);                                 /* 3262-3269 OUT 7F10h, OUT 7F54h */
    do {
        sys_read_keyboard();                                /* 326B */
    } while (sys_key_down(0x42, &code));                    /* 326E-3273 */
}

/* 2FD7 game_state_gather (PC -): DI; the saved game into the buffer 7F80h: 338h bytes from 28D0h (the 307D
 * triple: HL = 7F80h, DE = 28D0h, BC = 338h, exchanged), C8h bytes from 37D2h, FFh bytes from 3568h (the
 * command buffers). */
void game_state_gather(void)
{
    plat_di();                                              /* 2FD7 */
    copia(D64_STATE_BUFFER, D64_STATE_PART1, 0x0338);       /* 2FD8-2FDC */
    copia((uint16_t)(D64_STATE_BUFFER + 0x0338), D64_STATE_PART2, 0x00C8);   /* 2FDE-2FE4 */
    copia((uint16_t)(D64_STATE_BUFFER + 0x0400), D64_STATE_PART3, 0x00FF);   /* 2FE6-2FEC */
}

/* 2FEF game_state_restore (PC -): a game loaded: DI; the flip states of Guillermo's and Adso's graphics
 * are kept (the graphics in memory are as they are); spr_unflip_monk_faces; the buffer back: 320h bytes to
 * 28D0h, then [obj_mirror_height_ptr] := F5h, 98h bytes to 37D2h, E0h bytes to 3568h; the two flip states
 * back, the four monks' 0 (their faces are unflipped); obj_fix_owner_pointers; [3CAD] := 0; the mirror
 * numeral's letters again when one was chosen (5199).  Then POP HL / JP 2151: the main loop starts again
 * (game_main does it). */
void game_state_restore(void)
{
    uint8_t g, a;
    plat_di();                                              /* 2FEF */
    g = rb(D64_CHR_GUILLERMO_FLIP);                         /* 2FF0-2FF7 */
    a = rb(D64_CHR_ADSO_FLIP);
    spr_unflip_monk_faces();                                /* 2FF9 */
    copia(D64_STATE_PART1, D64_STATE_BUFFER, 0x0320);       /* 2FFC-3003 */
    wb(rw(D64_OBJ_MIRROR_HEIGHT_PTR), 0xF5);                /* 3005-3008 */
    copia(D64_STATE_PART2, (uint16_t)(D64_STATE_BUFFER + 0x0338), 0x0098);   /* 300A-3016 */
    copia(D64_STATE_PART3, (uint16_t)(D64_STATE_BUFFER + 0x0400), 0x00E0);   /* 3018-3023 */
    wb(D64_CHR_GUILLERMO_FLIP, g);                          /* 3025-302D */
    wb(D64_CHR_ADSO_FLIP, a);
    wb((uint16_t)(D64_CHR_GUILLERMO_FLIP + 0x1E), 0);       /* 3030-303A */
    wb((uint16_t)(D64_CHR_GUILLERMO_FLIP + 0x2D), 0);
    wb((uint16_t)(D64_CHR_GUILLERMO_FLIP + 0x3C), 0);
    wb((uint16_t)(D64_CHR_GUILLERMO_FLIP + 0x4B), 0);
    obj_fix_owner_pointers();                               /* 303D */
    wb(D64_AI_UNUSED_3CAD, 0);                              /* 3040-3041 */
    a = rb(D64_OBJ_MIRROR_NUMERAL);                         /* 3044-3048 */
    if (a) obj_set_mirror_numeral(a);
}

/* 31DF sys_tape_menu (PC -, the 64K version's save and load): main-loop step.  Nothing unless TAB (CPC key
 * 44h) has a new press and CTRL (17h) is down.  Then DI, the PSG mixer off (snd_channel_mask_copy := 3Fh,
 * register 7 := 3Fh), the cassette motor on, and until a key: the mark at the top left blinks
 * (hud_tape_marker_swap, util_delay_units(1), twice), the keyboard is read; ESC (42h): the motor off;
 * S (3Ch): the game is saved (game_state_gather, its checksum at 855Ah, the block 7F80h-855Bh with the
 * sync byte 0Ch); L (24h): the block is loaded and, when its checksum is right, the game restored
 * (game_state_restore) and the main loop starts again at 2151 (POP HL / JP 2151: returns true).  Every
 * other way out: tape_menu_leave, EI, false.  sp = the SP at its entry (the main loop's - 2). */
bool sys_tape_menu(uint16_t sp)
{
    uint8_t code, a;
    uint16_t hl;
    if (!sys_key_pressed(0x44, &code)) return false;       /* 31DF-31E4 */
    if (!sys_key_down(0x17, &code)) return false;           /* 31E5-31EA */
    plat_di();                                              /* 31EB */
    wb(D64_SND_CHANNEL_MASK_COPY, 0x3F);                    /* 31EC-31EE */
    snd_psg_write(0x07, 0x3F);                              /* 31F1-31F4 */
    tape_motor_on();                                        /* 31F7 */
    for (;;) {
        hud_tape_marker_swap();                             /* 31FA */
        util_delay_units(1);                                /* 31FD-31FF */
        hud_tape_marker_swap();                             /* 3202 */
        util_delay_units(1);                                /* 3205-3207 */
        sys_read_keyboard();                                /* 320A */
        if (sys_key_down(0x42, &code)) {                    /* 320D-3212: ESC */
            tape_motor_off();                               /* 3214, JR 323B */
            break;
        }
        if (sys_key_down(0x3C, &code)) {                    /* 3219-321E: S */
            game_state_gather();                            /* 3240 */
            a = game_state_checksum(&hl);                   /* 3243 */
            wb(hl, a);                                      /* 3246 */
            tape_save_block(D64_STATE_BLOCK_END, D64_STATE_BLOCK_LEN, D64_STATE_BLOCK_ID, (uint16_t)(sp - 2));   /* 3247-324F */
            break;                                          /* 3252 JR 323B */
        }
        if (sys_key_down(0x24, &code)) {                    /* 3220-3225: L */
            if (tape_load_block(D64_STATE_BLOCK_END, D64_STATE_BLOCK_LEN, D64_STATE_BLOCK_ID, (uint16_t)(sp - 2))) {   /* 3227-3232 */
                a = game_state_checksum(&hl);               /* 3234 */
                if (a == rb(hl)) {                          /* 3237-3238 JP Z,2FEF */
                    game_state_restore();
                    return true;
                }
            }
            break;
        }
    }
    tape_menu_leave();                                      /* 323B */
    plat_ei();                                              /* 323E */
    return false;
}

/* ================================================================================ the game */

/* 20BE game_main (PC 1000:1F00-...): the game, from the loader's jump; it never returns.  DI; the start-up
 * once (sys_startup_init when [00FE] is not 0Dh).
 * 20C7, a new game (also after the end of one: game_check_end): DI, the game's screen (CRTC R1 20h, R2 2Bh,
 * R6 18h: 1E6E with its data at 20CB), silence, and while space is held the keyboard again (a wait point:
 * plat_pausa); game_init_new_game, the play area cleared, the sound tempo 6, the vectors (JP at 0038h,
 * 4AFCh, 0008h, 0010h: 2899h sys_tick, 391Eh ai_script_test, 38FCh ai_script_assign), the frame budget
 * [21DA] := [BF49], Guillermo at [BF50] (x, y) and [BF52] (height), Adso at x - 2, y + 2 on the same
 * height, the 2D5h bytes of graphics AB59h copied to AE2Eh and mirrored (5 bytes x 91h lines), the
 * mirror closed (obj_init_mirror), the clock (ai_clock_init), command 10h in the 5 command buffers,
 * ticks := 0.
 * 2151, also after a game is loaded: DI, the room shown forgotten ([28C6] := 0), Guillermo's fall state 0
 * and its step 2, [2913] := SP, the play area cleared, silence, the mirror closed (obj_close_mirror), the
 * objects of the score bar, the clock (ai_clock_redraw), the obsequium bar (5129 with the inline byte at
 * 2174h, 00h), the phrase line cleared; EI.
 * 2179, the main loop: a frame; [0600] := [2B87]; the keyboard and the mirror; the pause (Del); the tape
 * menu (CTRL+TAB; a loaded game goes back to 2151); key 7 calls 3557h, a RET; the timers; 4B43 (a RET);
 * the end of the game (to 20C7, or the ending); the bonus and the poison; the hour's name; the hour; the
 * camera; the room (drawn when it changed: [0A6D] := 80h, else 0); the inventory; the doors; Guillermo
 * (chr_update 2703h); the monks; [2909] := [28FA] := 0; the light; the doors' graphics; the mirror; the
 * wait for [289C] >= [21DA] (plat_espera at each pass); Guillermo's footstep when [2B87] is odd; ticks := 0;
 * the sprites; then ESC (42h) is read and 3D05 (always Z) loops: the debug exit 21F7-2225 is dead.  In: sp,
 * the SP it is started with. */
void game_main(uint16_t sp)
{
    uint8_t code, a, k;
    uint16_t hl, p;
    iso_vm vm;
    plat_di();                                              /* 20BE */
    if (rb(D64_SYS_STARTUP_DONE) != 0x0D) (void)sys_startup_init();   /* 20BF-20C4 */
    for (;;) {
        for (;;) {                                          /* 20C7: a new game */
            plat_di();
            (void)vid_set_crtc(0x20CB);                     /* 20C8 CALL 1E6E <01 20 02 2B 06 18 FF> */
            snd_silence_all();                              /* 20D2 */
            sys_read_keyboard();                            /* 20D5 */
            if (!sys_key_down(0x2F, &code)) break;          /* 20D8-20DD JR NZ,20C7 */
            plat_pausa(sp);                                 /* a pass of the wait (pausa 20C7 20DD) */
        }
        game_init_new_game();                               /* 20DF */
        vid_clear_play_area();                              /* 20E2 */
        wb(D64_SND_TEMPO_RELOAD, 6);                        /* 20E5-20E7 */
        wb(D64_VEC_INTERRUPT, 0xC3);                        /* 20EA-20F5: JP */
        wb(D64_VEC_4AFC, 0xC3);
        wb(D64_VEC_RST08, 0xC3);
        wb(D64_VEC_RST10, 0xC3);
        ww((uint16_t)(D64_VEC_INTERRUPT + 1), 0x2899);      /* 20F8-20FB sys_tick */
        ww((uint16_t)(D64_VEC_RST08 + 1), 0x391E);          /* 20FE-2101 ai_script_test */
        ww((uint16_t)(D64_VEC_RST10 + 1), 0x38FC);          /* 2104-2107 ai_script_assign */
        wb(D64_SYS_FRAME_TICKS, rb(D64_SYS_FRAME_TICKS_NORMAL));   /* 210A-210D */
        hl = rw(D64_GAME_START_POS);                        /* 2110 */
        ww(D64_CHR_GUILLERMO_XY, hl);                       /* 2113 */
        hl = (uint16_t)((uint8_t)((hl >> 8) + 2) << 8 | (uint8_t)((uint8_t)hl - 2));   /* 2116-2119 INC H x2, DEC L x2 */
        ww(D64_CHR_ADSO_XY, hl);                            /* 211A */
        a = rb(D64_GAME_START_Z);                           /* 211D */
        wb(D64_CHR_GUILLERMO_Z, a);
        wb(D64_CHR_ADSO_Z, a);
        copia(D64_SPR_GFX_COPY, D64_SPR_GFX_SOURCE, 0x02D5);   /* 2126-2130 LDIR */
        spr_flip_graphics_h(D64_SPR_GFX_COPY, 0x05, 0x91);  /* 2132-2136: HL = AE2E, BC = 9105h */
        obj_init_mirror();                                  /* 2139 */
        (void)ai_clock_init();                              /* 213C */
        p = D64_CHR_CMD_BUFFER_HEADS;                       /* 213F-214B */
        for (k = 5; k; --k) {
            wb(p, 0x10);
            p = (uint16_t)(p + 0x2D);
        }
        wb(D64_SYS_TICKS, 0);                               /* 214D-214E */
        for (;;) {                                          /* 2151 */
            plat_di();
            wb(D64_CHR_ROOM_X, 0);                          /* 2152-2153 */
            wb(D64_CHR_GUILLERMO_STATE, 0);                 /* 2156 */
            wb(D64_CHR_GUILLERMO_FALL_DY, 2);               /* 2159-215B */
            ww(D64_SYS_SAVED_SP, sp);                       /* 215E LD (2913),SP */
            vid_clear_play_area();                          /* 2162 */
            snd_silence_all();                              /* 2165 */
            obj_close_mirror();                             /* 2168 */
            hud_draw_guillermo_objects();                   /* 216B */
            ai_clock_redraw();                              /* 216E */
            hud_obsequium_sub(rb(0x2174));                  /* 2171 CALL 5129 <00> (its inline byte is the NOP at 2174) */
            hud_clear_phrase_area();                        /* 2175 */
            plat_ei();                                      /* 2178 */
            for (;;) {                                      /* 2179 */
                plat_frame();
                wb(D64_CHR_GUILLERMO_ANIM_COPY, rb(D64_CHR_GUILLERMO));   /* 217A-217D */
                game_input_and_mirror();                    /* 2180 */
                (void)sys_check_pause_save_load(&code);     /* 2183 */
                if (sys_tape_menu((uint16_t)(sp - 2))) break;   /* 2186: a game loaded, POP HL / JP 2151 */
                if (sys_key_down(0x07, &code)) {            /* 2189-218E CALL NZ,3557: a lone RET */
                }
                (void)ai_timers_tick();                     /* 2191 */
                util_ret_530a();                            /* 2194 */
                ww((uint16_t)(sp - 2), 0x219A);             /* 2197 CALL 3E29: the return address it pushes is */
                a = game_check_end((uint16_t)(sp - 2));     /* part of the frames of the end-of-game wait */
                if (a == 1) goto new_game;                  /* 3EC2 POP HL / JP 20C7 */
                if (a == 2) game_ending((uint16_t)(sp - 2));   /* 3E98 JR Z,3EC6: never returns */
                game_update_bonus_and_poison();             /* 219A */
                hud_scroll_hour_name();                     /* 219D */
                ai_hour_update();                           /* 21A0 */
                (void)game_camera_update(&hl, &a);          /* 21A3 */
                (void)iso_update_camera_room();             /* 21A6 */
                a = rb(D64_ISO_ROOM_CHANGED);               /* 21A9-21AD */
                if (a) {
                    vm.hl = hl;                             /* the registers iso_draw_room gets: it sets */
                    vm.de = 0;                              /* the ones it uses before reading them */
                    vm.bc = 0;
                    vm.ix = 0;
                    vm.sp = 0;
                    vm.ret = 0;
                    (void)iso_draw_room(&vm);               /* 21AF */
                    a = 0x80;                               /* 21B2 */
                }
                wb(D64_OBJ_ROOM_REDRAW, a);                 /* 21B4 */
                obj_update_inventory();                     /* 21B7 */
                obj_update_doors();                         /* 21BA */
                (void)chr_update(0x2703);                   /* 21BD-21C0: Guillermo */
                game_run_npc_behaviours((uint16_t)(sp - 2));   /* 21C3 */
                wb(D64_ISO_ROOM_CHANGED, 0);                /* 21C6-21CA */
                wb(D64_CHR_PATH_FOUND_NOW, 0);
                spr_place_light((uint16_t)(sp - 2));        /* 21CD */
                obj_door_flip_graphics();                   /* 21D0 */
                iso_mirror_update();                        /* 21D3 */
                while (rb(D64_SYS_TICKS) < rb(D64_SYS_FRAME_TICKS)) plat_espera();   /* 21D6-21DB */
                if (rb(D64_CHR_GUILLERMO) & 0x01) snd_play_footstep();   /* 21DD-21E2 */
                wb(D64_SYS_TICKS, 0);                       /* 21E5-21E6 */
                spr_draw_or_darken((uint16_t)(sp - 2));     /* 21E9 */
                (void)sys_key_down(0x42, &code);            /* 21EC-21EE */
                if (util_return_zero()) continue;           /* 21F1-21F4 CALL 3D05 / JP Z,2179: always */
                /* 21F7-2225, dead: the developers' exit (game_exit), unless keys 15h and 17h are down: then
                 * the 8 bytes of 221E go to 0000h (OUT 7F89h / JP 0591h) and 0000h is the return address */
                if (!sys_key_down(0x15, &code)) game_exit();   /* 21F7-21FC */
                if (!sys_key_down(0x17, &code)) game_exit();   /* 21FF-2204 */
                copia(0x0000, 0x221E, 8);                   /* 2207-2210 */
                game_exit();                                /* 2212-221B: SP := [2913], [SP] := 0, JP 1E4B */
            }
        }
new_game:
        ;
    }
}
