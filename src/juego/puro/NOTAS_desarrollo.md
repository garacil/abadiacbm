<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# The game in pure C: development log

Built in a separate working copy of `src/juego/` (based on the master files of that time: the first snapshot plus
logica_b and the master's hibrido.c/Makefile/grupos.c/juego.h; since merged and removed).  Tools, now in
`src/juego/puro/pruebas/`:
* `herr/sombra.sh` — prueba.sh's shadow check, the 8 sessions in parallel (0 differences).
* `herr/solo_c.sh` — `--solo-c` per-frame hashes (`--hash-pila 0xAD`) against the pure Z80 run
  (`ref/z80_N.tsv`, made with `--solo nada`; regenerated after the tape image replaced the disk one).
* `herr/puro.sh` — the pure C program against the pure Z80 run, 8 sessions, frame by frame.
* `herr/largo.sh` — the same on 16 long scripts (`guiones/largoNNN.txt`, `herr/guion_largo.py`, 20000
  frames, with Q+R, S, N, key 7 too).
* `herr/guarda_hibrido.py` — wraps the hybrid host's part of a game file in `#ifndef JUEGO_PURO`.
* `herr/prototipos64.py` — tools/prototipos64.py with one change: functions with z80
  parameters (the hybrid's result checks of funciones.c) are left out of juego64.h (juego.h declares
  them, inside its hybrid part).  The master's tool needs the same line.
* `src/juego/pruebas_extra.sh` (`ABADIA64_TRABAJO`: the project's `data/` by default).

## Step 1: the C functions call each other (done)

Every llama_z80 / llama_z80_salta / llama_z80_linea / salta_z80 / z_* stand-in of the game code is
now a C call; no game function touches `cpu`.  Per file:
* f_camino.c: stand-ins gone; drivers call the think scripts, obj_set_door_permissions, chr_update in C
  and give ai_plan_route the record chr_update worked on ([247E], IY: chr_update returns IX).
  ai_update_adso: every JP 04EB is the `continue` of its loop (410D/40EB now return "run again" and take
  IX); chr_path_find enters the floor search at 4399: new chr_path_floor_search (f_logica_a.c), whose
  target test reads the self-modified BIT n at 440D (the C 438F had bit 6 fixed: chr_path_find uses
  bits 4/5 to look for stairs).  07E3 chr_cmd_generate gets C = 0, HL = the grid's end (what 081E leaves).
* f_personajes.c: game_run_npc_behaviours(sp), spr_draw_or_darken(sp), spr_place_light(sp) (they reach
  the path searches / spr_draw_all, which store SP); chr_animate's tail is chr_show_frame (2589, also
  called by spr_update_char_sprite); the camera rotation through [2656] is a switch; 4FC9 (the mirror's
  flip routine) in chr_flip; sys_tick calls snd_interrupt and txt_phrase_tick.
* f_objetos_sonido.c: chr_project in test mode for 0ACA; one-line snd_play_* expanded (so the
  prototype tool sees them).
* f_estado_texto.c: sys_check_pause_save_load returns the A of the last sys_key_pressed (its wrapper
  needs it); new 3A58 ai_say_phrase_param.
* f_motor_iso.c: vid_next_line, iso_draw_room_spiral, chr_select_frame, chr_show_frame, iso_select_room,
  chr_fill_height_buffer, the doors/objects, chr_mark_hbuf in C.
* f_logica_a.c: the command writers (432C, 4292, 41B8, 41C9) carry the A / HL that chr_cmd_write_bits
  leaves into chr_probe_ahead (its fallbacks off the floor shown) through static helpers write_turn,
  write_step, turn_and_step; spr_draw_all's IX/IY results through spr_draw (static) for its wrapper;
  COLOCA macro expanded into 7 functions; new 3EE6 ai_stop_hour_countdown (LD HL,0 / LD (28D7),HL: the
  tape original; the disk repack had a restart there) and 3EC6 game_ending (+ 31CF).
* f_logica_b.c (merged from the master): all *_z80 helpers replaced; the inline phrase bytes
  are constants; new 6000-60F2 (they were Z80, not in logica_b's range): ai_ready_vespers_day5 (6000),
  ai_ready_adso (6012), ai_abbot_count_prima (6016), ai_abbot_count_sexta (6040),
  ai_abbot_wait_ceremony (6076), decoded from the script bytes.
* Wrapper register checks that came for free from the Z80 runs and are now computed: w_092E (B, A, HL),
  w_16B2/16A1/16A5 (A, F of the last 3558), w_1F79 (IX, IY), w_432C/4292/41B8 (A, DE, HL of 0959).
  Relaxed, with the reason in a comment (no caller reads them): r_1611 (lit room: what 4A5F leaves),
  r_0A89 (A' / A when not marked), the scripts' IX/IY (52B4, 5495, 571C, 58F7, 5B21).
* hibrido.c: plat_teclado_fila / plat_psg read the ports through cpu.port_in (the estado_texto
  synthetic test hooks port_in: the C pause loop hung there).

## Step 2: the rest of the Z80 in C (done)

`--solo-c --cobertura` showed only the main loop, 0038, 31DF-31E4 and 3E29 still in Z80.  New file
f_principal.c (+ datos_principal.h):
* 20BE game_main(sp): the start, a new game (20C7), 2151, the main loop 2179-21F4 and the dead debug
  exit 21F7-2225; 1E4B game_exit; 0038 sys_interrupt (the vector: JP 2899 or RET).
* the CTRL+TAB menu 31DF sys_tape_menu (ESC, S save, L load; a loaded game restarts at 2151), 2FD7
  game_state_gather, 2FEF game_state_restore, 3254 game_state_checksum (5DAh bytes: its DJNZ stops at
  B = 0), 3262, 3276, 3293/329A, 31C1, and the tape blocks 32AB/3371 (the turbo code is the platform's).
* Platform calls added to juego.h: plat_frame, plat_espera, plat_pausa(sp), plat_cinta_motor,
  plat_cinta_carga, plat_cinta_guarda, plat_final, plat_salir; sys_interrupt is the game's entry for the
  platform's ticks.  hibrido.c implements them (the waits as its wait points; no tape; the ending and
  the exit leave the program) and gets `--registra-r F` (the LD A,R values at 518A).
* Not in the hybrid's table (they do not return to their caller; the hybrid keeps the main loop in Z80):
  game_main, game_exit, sys_tape_menu, game_check_end, game_ending.

## Step 3: the pure C program (done)

`src/juego/puro/puro.c` + `src/juego/puro/Makefile`: the game files built with -DJUEGO_PURO (every hybrid part
of f_*.c, funciones.c and juego.h is under `#ifndef JUEGO_PURO`), no Z80 core, C89 declarations checked
(-Wdeclaration-after-statement).  The synchronous mode as hibrido.c: 3328 us per wait pass, due ticks
delivered one per pass with IFF1, the pausa frames hashed before their interrupt runs.  The hash leaves
out the 0xAD bytes below the Z80's SP at the frame point: BF53-BFFF at the main loop and the new-game
wait; BF51-BFFD at the end-of-game wait (inside 3E29, SP = BFFE): there the CALL's return address 219A
is part of the frame in the Z80 run, so game_main writes it before calling game_check_end, and
plat_pausa gets the SP.  LD A,R at 518A: replayed from the Z80 run (`--r`); the 8 sessions never read it.

Results (tape image): pure C == pure Z80, 8 sessions x 4001 frames, identical; 0.3 s a session.

## The pure host for front-ends

`src/juego/puro/puro_host.c` + `puro_host.h`: the platform of the synchronous mode and the game run frame by
frame with the hybrid's interface (carga_estado, carga_puntos, carga_guion, corre_frame(fh) -> 1 a frame,
2 the ending at 31CF (the tape loading of block 2Ah), 0 the debug exit; teclas_vivas, al_psg, en_frame,
paleta / modo / crtc, frame, ticks; puro_salta_final() for --salta-final).  game_main never returns, so
the host runs it as a coroutine (ucontext, a 4 MB stack) that gives the control back at every frame point:
host machinery only, the game code knows nothing of it.  puro.c (the test program) uses it.
`src/juego/gnu`: `make abadia64ks-puro` builds the master's front-end (abadia64ks.c, with #ifdef PURO at its
three hybrid-specific places) on it, with pergamino.c / musica.c, no Z80 core.  `herr/frontal.sh`: both
builds on Xvfb :99, emulated time: session 1 x 3000 frames and the forced 100 % ending: window capture,
AY write log and WAV identical.

## More checks (all identical / 0 differences)

* `herr/largo.sh`: 16 random scripts of 20000 frames (Q+R, S, N, key 7 too), pure C == Z80.
* `herr/dias.sh`: the start state with every day 1-7 x hour 0-6 ([BF4F], [BF4E], read by
  ai_clock_init), 6000 frames each: 49 runs, pure C == Z80.  They run the abbot's ceremonies 6000-60F2.
* `herr/final.sh`: the 100 % ending (day 7 tercia, [37F4] := 0): both reach the ending's tape load with
  the same frames and RAM (the stack apart).
* `src/juego/pruebas_principal/sintetica.sh` (in pruebas_extra.sh): the tape menu (ESC, S save), the
  save/restore of a game (2FD7, 2FEF up to 2151), the checksum, the mark, the delays, the motor, 3262,
  0038: 15 cases, C == Z80.
* Instruction starts executed by the Z80 over all these runs: 7005 (the 8 sessions alone: 6223).

## Not exercised by any check

The tape load path of the menu (L) and the tape blocks' own code (platform), the ending program
(plat_final), the debug exit (dead code), LD A,R at 518A (obj_read_manuscript: never read in any run;
replayed from the Z80 when it is), and the entries listed by the coverage: 0C6D 0C86 0C8B 0C9A 0F9A 0FB7
1D48 3087 3BAC 3BF3 3BFD 3C1B 3C26 3C52 3C66 3C70 3C7A 3D0F 3D87 4477 4BBB 4FC9 5184 5199 (several are
covered by the groups' synthetic checks).

## Notes for the merge

* `puro_merge.patch` (`patch -p1` in abadia64ks/): the changes against the master of that time (with
  musica.c / pergamino.c, the new gnu/, hibrido.c's `parada`); checked on a copy of it: hibrido, puro,
  gnu/abadia64ks and gnu/abadia64ks-puro build, puro.sh 8/8 identical.
* Regenerate juego64.h with the prototype tool that leaves out z80 parameters (herr/prototipos64.py).
* plat_pausa takes the SP (the hash window of the end-of-game wait); a front-end ignores it.
* plat_final is where a front-end runs the ending (pergamino() of the master's pergamino.c, after
  plat_cinta_carga put block 2Ah in ds); puro.c --final loads it from cinta/final.bin.
