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

# abadia64ks, H4: the group personajes in 6502 (Z80 2226-2F57)

`personajes.s`: the 48 functions of `traducidas_personajes` (`src/juego/f_personajes.c`), one 6502 routine each
with the C name and the Z80 interface (`src/c64/CODIGO6502.md`), plus the Z80 entries the C keeps internal:
261E chr_project_or_hide, 2632 chr_project, 280D chr_read_command (`personajes_read_command`), 2556
chr_advance_anim, 2589 chr_show_frame, 223D (`personajes_dark`).  Their lines of `resultados.tsv` follow the
group's comment line there.  `comprueba.sh` runs every check (below); `sinteticas.sh` / `sinteticas.c` the
synthetic cases.

## Size

**2705 bytes** of code and tables (budget 3560; the Z80 listing 2967).  The first complete version was 2952
bytes; a size pass took 247 off: chr_load_params as a loop (69 -> 29), the frame copy
of chr_show_frame and spr_save_old_rect through small tables (-23), the assumed heights of
chr_ai_follow_commands from tables and its restore copy inline (-22), DE and HL kept by a loop in sys_key_down
(-8), the strides of chr_probe_cells copied by a loop straight into their operands and no separate copies
(-27), the room origins of chr_project by a loop and a shared store of HL (-26), the climb/descend of
chr_try_advance(_2x2) as height + ahead1 (-26), the mirror's entry pointer shared (personajes_mirror_entry),
the steps of game_check_qr_mirror from a table, and the dead outputs dropped (the Z80's BC = 7FC0h of
iso_select_room, BC = 10 of chr_backup_args, DE = [2EDE] + 5 of obj_close_mirror, HL + 10 of chr_load_params:
no caller reads them).  The cost: chr_update +190 cycles a call (1494 on average), sys_key_down / pressed +55;
the hot routines (chr_to_hbuf_coords, chr_mark_hbuf, sys_key_bit, sys_tick, chr_project's early exits) were
left alone.  The four monks' flips were already one parametrised routine (personajes_flip_monk: each entry is
6 bytes, it must exist because chr_table holds its address).

Per routine (bytes, from the ca65 listing):

| Routine | Bytes | Routine | Bytes |
|---|---|---|---|
| game_run_npc_behaviours | 15 | chr_project_or_hide | 7 |
| spr_draw_or_darken | 8 | spr_mark_leaving | 25 |
| personajes_dark (223D) | 58 | chr_project (2632) | 282 |
| spr_place_light | 116 | personajes_store_hl | 10 |
| vid_clear_play_area | 5 | chr_load_params | 29 |
| chr_step_table | 21 | chr_command_bit | 57 |
| util_add_bx_8al | 15 | personajes_read_command (280D) | 89 |
| chr_to_hbuf_coords | 38 | chr_ai_follow_commands | 144 |
| chr_probe_ahead_flat | 6 | personajes_copy10 | 10 |
| chr_probe_ahead | 31 | chr_backup_args | 22 |
| chr_probe_cells | 184 | iso_select_room | 47 |
| chr_mark_hbuf | 54 | chr_fill_height_buffer | 64 |
| chr_update | 57 | sys_tick | 23 |
| chr_think_or_step | 28 | sys_read_keyboard | 35 |
| chr_guillermo_behaviour (+2 data) | 127 | sys_key_bit | 38 |
| chr_try_advance | 96 | sys_test_key | 79 |
| personajes_step_kept | 18 | sys_key_pressed + sys_key_down | 57 |
| chr_orientation_parity | 11 | game_check_qr_mirror | 59 |
| chr_try_advance_2x2 | 39 | game_input_and_mirror | 104 |
| personajes_moved | 8 | obj_init_mirror | 10 |
| chr_apply_step | 29 | obj_close_mirror | 45 |
| chr_turn | 29 | personajes_mirror_entry | 18 |
| chr_step_level + chr_step_and_animate | 3 | spr_flip_adso, _guillermo | 22 |
| chr_advance_anim (2556) | 11 | personajes_flip1/2 + table | 50 |
| chr_animate | 23 | spr_flip_malachi .. _severin | 22 |
| chr_show_frame (2589) | 52 | personajes_flip_monk | 26 |
| chr_select_frame | 97 | spr_flip_graphics_h | 128 |
| spr_save_old_rect | 24 | | |

Zero page of the group ($C2-$CD): $C2-$C3 the key list sys_test_key walks, $C4 the test kind of
sys_key_pressed / sys_key_down; $C5-$CD free.  Scratch zt0-zt5 / zp0-zp1 inside routines, never across a call
to another group.

## Checks

`comprueba.sh [--largos] [OUTDIR]` (from any directory): `construye.sh`, then the 8 exploration sessions (or
`--largos`: the 16 long scripts, 20000 frames) on two builds, all runs in parallel, then `sinteticas.sh`:

* **normal**: this directory.
* **npc**: the same with `game_run_npc_behaviours` not exported.  When 2226 is translated, the NPC drivers
  (camino: ai_update_*) run inside its traps as Z80 code, so the calls they make into this group (chr_update
  of the four NPCs, chr_probe_ahead(_flat), chr_mark_hbuf, chr_to_hbuf_coords, chr_fill_height_buffer,
  chr_apply_step, chr_orientation_parity, sys_key_down) would never be checked; in the npc build the drivers
  run in the main loop and each of those calls is checked by itself.  It is built in a temporary tree of
  symbolic links to the project (the variant at the same depth as this directory), removed at the end.
* The coverage: `comprueba.sh` lists the group's Z80 code the npc runs never ran: in the 8 sessions 223D-2262
  and 226F-22D3 (a dark room), 23E4-241E (Guillermo's fall after the mirror trap), 254F-2552 (dead), 26EE-2701
  (the stairs frames of a turned 1-cell character), 27E3-27E7 (a 1-cell command 1), 283D-284C (a 1-cell '0000',
  the restart of a 2x2 stream), 2890 (the library's height buffer), 2DA8-2DE7 and 2E08-2E2B (Q+R at the mirror),
  2F00-2F0E and 2F20-2F2E (Malachi's and Berengar's flips).
* `sinteticas.sh [DIR]`: `sinteticas.c` is the hybrid host (src/juego/hibrido.c included, its main renamed):
  session 1 runs to frame 1200, and 100 cases start from that state, each changed as it needs (the dark room with and
  without Adso and the lamp, the light for four positions and both flips; the fall counter 14h, 13h, 5, 2, 1
  with the steps 2, 1, 3; twelve stairs flags x two counter halves; Adso's command streams '11', '0000' with
  and without the slope bit, and a 2x2 '0000' from byte 1 that restarts the stream on '1', '0001', '010', '0010'; Guillermo at heights 16h-18h; the mirror on its
  three steps and off them, numerals 1-4, Q alone and Q+R; the two flips) and checked as the host checks a
  session's call.  With the sessions they run every instruction of the group's Z80 code but the dead 254F-2552
  (and two listing artefacts: 23E4, an operand, and 2DCC, hud_say_now's inline byte).

Results (the final 2705-byte build): 0 differences in the 8 sessions on both builds (normal
1 892 357 calls, npc 6 463 750), in the 97 synthetic cases (98 calls), and in the 16 long scripts on both
builds (normal 18 412 724 calls, npc 96 888 020; the long scripts also reach 27E3-27E7).  The build before the
size pass gave 0 differences on the same runs.

Calls per routine (top-level checks, 8 sessions) and 6502 cycles per call (`SOMBRA6502_CICLOS`; traps not
counted):

| Routine | Calls (normal / npc) | Cycles per call |
|---|---|---|
| sys_tick | 893 376 | 90 (+ the two traps) |
| chr_to_hbuf_coords | 34 162 / 201 878 | 19 / 41 (56 on the in-range path) |
| chr_mark_hbuf | 612 / 123 605 | 118 (+ iso_grid_cell_of) |
| util_add_bx_8al | 161 717 | 26 |
| sys_key_down | 121 792 / 191 838 | 395 (one to three codes tested) |
| sys_key_pressed | 80 919 | 340 |
| chr_update | 26 960 / 163 900 | 3359 (Guillermo alone) / 1494 (all) |
| game_input_and_mirror | 26 973 | 677 |
| chr_probe_ahead, _flat | 24 231, 19 524 (npc) | 1163, 1102 |
| chr_apply_step | 25 084 (npc) | 58 |
| spr_save_old_rect | 9 330 | 103 |
| chr_fill_height_buffer | 102 / 6 279 | 6400 (the 576-byte clear) |
| sys_read_keyboard | 5 061 | 592 |
| chr_orientation_parity | 1 488 (npc) | 19 |
| chr_select_frame | 612 | 139 |
| iso_select_room | 102 | 655 |
| spr_flip_guillermo / _adso | 8 / 15 | 41 575 / 32 887 (207 / 185 lines) |
| spr_flip_abbot / _severin | 8 / 5 | 4313 |
| spr_flip_graphics_h | 29 | 24 329 (the robes' dead copy: 145 lines) |
| spr_draw_or_darken, spr_place_light | 26 960 | 9, 18 (lit rooms) |
| game_run_npc_behaviours | 26 960 | 27 |
| obj_init_mirror, obj_close_mirror | 21 | 209, 197 |
| spr_mark_leaving | 2 | 46 |
| vid_clear_play_area | 42 | 5 |

Routines only called by the group's own code (no top-level check; checked inside their callers):
chr_step_table, chr_probe_cells, chr_guillermo_behaviour, chr_think_or_step, chr_try_advance(_2x2),
chr_step_level, chr_step_and_animate, chr_turn, chr_animate, chr_load_params, chr_command_bit,
chr_ai_follow_commands, chr_backup_args, game_check_qr_mirror, sys_test_key, sys_key_bit, the character
flips.  Counted by hand: sys_key_bit 68 cycles with the JSR; chr_project about 30 when the character is off
the room and about 440 when it is visible (normal mode, the camera rotation not counted).

## Decisions and Z80 details kept

* **chr_project returns to its caller's caller** when the character is visible, as the Z80 (PLA PLA, RTS):
  callers `JSR chr_project` and put the not-visible code after it.  Normal mode: C = the depth, HL = the
  sprite's x:y; test mode (`D64_CHR_PROJECT_TEST` = C9h, set by 0ABC): A = the depth, HL = row:column, C =
  x+y.  chr_project_or_hide drops chr_animate's return address and the frame chr_animate pushed (4 PLA) and
  falls into spr_mark_leaving, exactly as the Z80's POP HL / POP HL.  chr_show_frame (2589) is exported for
  spr_update_char_sprite's JP 2589 (HL = frame, C = depth, IX, IY).
* **The end of a command stream** (280D POPs its return address and the step 278F pushed): on the 6502
  `personajes_read_command` (its only caller is 278F) returns with the C flag set and chr_ai_follow_commands
  returns at once; the step is on the 6502 stack (PLA does not change C).
* **The monks' animation tag**: [25D9] holds C000h + 2k for a monk (tagC0, never relocated).  The Z80 tests
  (high & C0h) = C0h; on the C64 the animation tables lie at $CF99 / $CFB9, whose high byte also has bits 7-6
  set, so the 6502 tests high = C0h exactly (equivalent for every value the game stores; an `.assert` that no
  table lies at $C0xx).
* **The second face**: + 1Eh on the C64 (10 lines of 3 bytes) for the CPC's + 32h (chr_select_frame).
* **Guillermo's probe fallback**: off the floor shown chr_probe_ahead leaves HL = the behaviour routine's
  address (23E2, from the JP (HL)) and chr_try_advance reads its dx, dy there: the Z80 code bytes 00h 3Eh.  The
  6502 passes `guillermo_self: .byte $00, $3E` so that the result is the same (never seen in the sessions).
* **chr_load_params** stores the five words straight into the operands (bytes 0-3 to $46-$49, 4-7 to
  $0208-$020B, 8-9 to $4A-$4B): the list 2741 (`D64_CHR_PARAM_TARGETS`, 10 bytes) is constant, so the 6502
  never reads it: it can leave the map.
* **chr_probe_cells** addresses the 4x4 window as (cell - 80h) + an 8-bit offset: every entry of the constant
  step tables (strides +-1, +-18h, starts -50..+49) keeps the 16 cells within 50 bytes of the character's cell.
  The strides still go to their operands [2378] / [237F] (the loop reads them there).
* **spr_flip_graphics_h** works on the C64 sprite format (`src/c64/NOTAS_GRAFICOS.md`): each line's bytes go
  through `espejo_nibble` onto the stack; even width: popped in reverse with the nibbles swapped (the 12-cycle
  ASL/ADC/ROL swap, so the optional `espejo_byte` is not needed); odd width: new byte k = high nibble of
  E(old byte n-1-k) | low nibble of E(old byte n-2-k), the last = high nibble of E(old byte 0) | the old
  padding.  The faces and the door lie under the I/O: $01 = $34 for the whole call, the caller's $01 back at
  the end.  The width goes to [2FA3] as on the Z80.  The Z80's registers at its exit (the banks exchanged by
  EXX) are not reproduced: no caller uses them.
* **The robes' dead copy**: the new game (2126, group principal) copies the robes to AE2E and calls 2F57 on the
  copy (B = 91h, C = 5).  The C64 game skips both (`src/c64/NOTAS_GRAFICOS.md`), but the host still checks that
  call: on the C64 the address AE2E (not relocated: no graphic there) is inside the library's heights
  (`D64_CHR_FLOOR2_HEIGHTS`), and the Z80 changes the height buffer.  spr_flip_graphics_h's line in
  `resultados.tsv` therefore leaves `D64_CHR_HEIGHT_BUFFER` and `D64_CHR_FLOOR2_HEIGHTS` out of its
  comparison (no legitimate call touches them).
* **The light** (spr_place_light): the operands keep the Z80 values (the words 00EFh / 009Fh, 00h / 29h).
* **Registers not reproduced** (no caller reads them; some are a CPC pointer's high byte that cannot match on
  the C64): A = H of chr_step_table, util_add_bx_8al, iso_select_room; iso_select_room's BC = 7FC0h; 2D50's
  constant A, B, DE, HL (port values); chr_load_params' HL + 10, IX, B, DE; chr_backup_args' BC = 10;
  obj_close_mirror's DE = [2EDE] + 5 (one past the heights block); chr_try_advance's E = [IY+4] (read only by
  the dead code at 254F).
* **sys_tick** (the body of the C64's 300 Hz interrupt; the platform's handler keeps A and $01 and JSRs it):
  it writes `D64_SYS_TICKS` and makes snd_interrupt's test (a channel playing: s_estado_a/b/c) and
  txt_phrase_tick's (its counter + 1 = 2Dh) inline, calling their work (s_interrupcion, t_frase) only when there
  is some; it uses no register pair, no scratch, none of this group's zero page, and not X or Y (the callees keep
  them).  In the checked build (-D PRUEBA) it keeps A and the flags on the stack (PHP / PHA ... PLA / PLP, the
  Z80's PUSH AF / POP AF) and ends with plat_ei (the IFF mirror: the host gives the tick with IFF = 0); on the
  C64 the handler and the RTI keep A and the flags and there is no DI / EI at all (the I flag is set from the
  IRQ's entry to its RTI).  Since the interrupt work (src/c64/optimizacion/interrupcion).
* **sys_key_bit** builds HL with ORA: the bit masks are 8-aligned ($EDB0, `.assert`).  The key bitmaps 2DE8
  / 2DF2 share a page, and so do the alias lists 2E2E-2E41 (`.assert`).

## Stubs and their declarations

The routines call these other groups' functions (traps until translated): ai_update_adso / _malachi /
_abbot / _berengar / _severin, spr_draw_all, vid_fill_play_area, iso_grid_cell_of, iso_grid_set_origin,
chr_hbuf_fill_room, snd_interrupt, txt_phrase_tick, hud_say_now (inline byte 22h), snd_play_mirror_open; and
through code pointers iso_rotate_cam0..3 ([2656]) and iso_mirror_draw_callback ([25AE]), imported only so
that the pointers relocate to their stubs.  Used already translated (the pilots): iso_floor_base,
iso_orient_relative.  `resultados.tsv` declares for the stubs: iso_grid_cell_of `>IY:var >IX:var IX:var
IY:var`, iso_grid_set_origin `>IY:var IY:var`, iso_mirror_draw_callback `>IX:var >IY:var IX:var IY:var`,
hud_say_now `INLINE` (a pointer a stub takes must also be declared at its exit, or the Z80's unchanged CPC
value comes back into the zero page).  Interfaces the callees must keep: iso_grid_cell_of keeps C (the mark);
iso_orient_relative keeps BC (chr_project keeps its frame count in B across it); iso_floor_base returns the
base in B keeping A; iso_grid_set_origin returns the floor base in A.

## Fix after the integration: the restart of a 2x2 command stream

The integrated build (src/c64/juego_final, `dias.sh` from the later-day states) found a difference in chr_update
(day 3, hour 0, largo115, frame 2868: Berengar).  Bisected call by call (a harness that replays the failing call
stepping the Z80 and checking each callee): chr_ai_follow_commands' own code, personajes_read_command.  After a
2x2 character's '0000' the stream restarts ([IY+0B] = [IY+9] = 0) and is read again from 280D; the 6502 wrote
the two zeros with `LDY #9 / STA` and then branched with `BEQ start`: LDY #9 had left Z clear, so it fell into
`last` and decoded the first bit of the restarted stream as the whole command (0 or 1).  Fixed with `BCC start`
(the last bit read was 0, nothing since changes C): same size.  The synthetic case of the restart used a byte 0
of 80h, for which both readings give command 1; the cases now also restart on 10h ('0001', the end), 40h ('010')
and 20h ('0010'), which the old code fails (3 differences) and the fixed one passes.
