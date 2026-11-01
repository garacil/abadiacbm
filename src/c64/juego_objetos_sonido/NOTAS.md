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

# Group objetos_sonido in 6502 (Z80 0983-128E): notes

Sources: `objetos_sonido.s` (the group, 1967 bytes of code, budget 2700; the Z80 listing is 2246), `prueba_chr_project.s` (for the checks
only, not part of the game: see 1), the lines of `resultados.tsv`.  C reference `src/juego/f_objetos_sonido.c`
(table `traducidas_objetos_sonido`, 46 entries: all translated).

## Design

* Every Z80 function has its routine with the Z80's registers (IX, IY, HL, BC, DE in `zix`... ; CF/ZF as the Z80's).
  The sound's internals have a second entry that takes the channel in X (0, 18h, 30h from `D64_SND_CHANNEL_A`,
  fields `CH+SND_xxx,x`): `s_tick_activo`, `s_salida_activo`, `s_tono_siguiente`, `s_paso_volumen_0`,
  `s_volumen_siguiente`, `s_empieza`/`s_pon`.  The exported entries convert IX to X (`s_ix_x`).
* Own zero page ($AA-$B5): the interrupt's `s_ch` $AA, `s_st` $AB, `s_nota` $AC, `s_ptr` $AD-$AE, `s_vec` $AF-$B0;
  the main code's `o_guarda` $B1-$B2 (the door bytes kept across the leaf marking, the Z80's EXX), `o_spr` $B3-$B4
  (the loops' sprite pointer, the Z80's PUSH IX / POP IX).  $B5 free.
* **The interrupt** (`snd_interrupt` and everything it calls, src/c64/CODIGO6502.md last section): sys_tick makes
  the test (a channel playing: `s_estado_a/b/c`) inline and calls `s_interrupcion`, the work, which keeps X and Y
  (the C64's handler does not) but not A and the flags (sys_tick's); the Z80 entry snd_interrupt (PHP/PHA, DI,
  the test, s_interrupcion, EI, PLA/PLP) is in the checked build only.  The register pairs BC, DE, HL, IX
  ($02-$09) are pushed and pulled around the sequence commands (`s_siguiente`: the handlers of
  `D64_SND_COMMANDS` take BC = argument, DE = sequence, IX = channel), the only place where the interrupt uses
  them; everything else works in $AA-$B0 and in X/Y.  No `zt*`, `zp*`, `za2`, `zf2` in the interrupt.  External
  calls: `plat_psg` only.  The idle channels are skipped by tests inline in s_interrupcion; when A and B are both
  idle only C's tick and output are tested (C's commands can start B, not A, and a starting channel sends
  nothing).
* The sequence commands are dispatched through `D64_SND_COMMANDS` (its code pointers relocated to the 6502
  routines) with `JMP (s_vec)`.
* The triggers (0C6D-0CA2) keep IX, IY and HL (the Z80 leaves IX = channel, HL = sequence: no caller reads them);
  the ones of one channel whose sequences share their high byte share one tail (LDY #low + BIT abs skips).
* `obj_door_check_open_close` reads the permission table indexed by X (`o_no_permitido`, `o_cerca`) instead of
  through HL and util_read_indirect_pair: the same tests, ~30 % faster; HL and B are not left as the Z80's (nobody
  reads them).  `obj_door_unpermitted_near` assumes HL is an entry of D64_OBJ_DOOR_PERMISSIONS (its only callers).
* `obj_door_cells` keeps the caller's A in `za2` (EX AF,AF'); the swap of A' at the end of obj_door_mark_cells
  is not reproduced, and DE is not kept across iso_grid_cell_of (the Z80 pushes it): no caller reads either.
* `obj_door_flip_graphics` switches the I/O off ($01 = $34) around spr_flip_graphics_h (the door leaf is at $DDA0).
* The door sprite's graphic pointer is `G_PUERTA` ($DDA0, the converted leaf); the callback vector
  `D64_OBJ_ENTITY_CALLBACK` holds the 6502 routines (JMP (abs)).

## Checks (all at 0 differences)

`hibrido --solo-6502` checks a routine only when the Z80 enters it at the top level, so the inner routines were
checked with builds that leave the outer ones unexported (the Z80 runs those): scripts in a scratch
directory (`variante.sh`, `corre.sh`): V0 the full build; V1 without obj_update_doors, obj_place_*,
obj_redraw_one_object, snd_interrupt, snd_silence_all and the triggers; V2 also without
obj_door_check_open_close, spr_project_entity, obj_for_each_visible, snd_channel_tick, snd_channel_output; V3
also without obj_door_sprite_update, obj_door_mark_cells, snd_vol_env_step, obj_door_unpermitted_near; V4 also
without obj_door_camera_adjust.  Sessions azar1-8 (4472 frames) on V0-V3 (V4 on 1, 2, 3, 8); the long scripts
largo101-116 on V0.

Never executed in the sessions (also not by the Z80: listing marks): snd_cmd_jump (F9), snd_cmd_start_c (FD),
snd_cmd_nothing (FC), the AY envelope (8xh) of snd_vol_env_next and of snd_channel_output, the noise of a note
and of the output, the triggers mirror_open, hour_bells, door_close, door_open, severino, snd_start_if_idle
with channel C idle.  Reviewed by hand against the Z80.

## Open points

1. **chr_project (2632, personajes) cannot be a stub**: it is in no table of the C translation (stubs64.py
   refuses it), and when visible it drops its return address and returns to its caller's caller, which a trap
   (llama_z80) cannot follow.  `prueba_chr_project.s` is a stand-in of its test mode only (2684 = C9h), for the
   checks of spr_project_entity and its callers; delete it when personajes delivers chr_project, which must keep
   the Z80 contract with the 6502 stack: not visible RTS; visible PLA PLA (POP DE at 267D) and in test mode RTS
   with A = depth, HL = line:byte (and [spr+12h,13h] written once the floor matches).
2. The traps convert IX C64 -> CPC by any block, so a CPC junk value in IX (obj_door_mark_cells from 08CC brings
   the path search's IX: room links, 0203h) that was not relocated at the entry came back changed; the IX lists
   of obj_door_mark_cells, obj_door_cells and the iso_grid_cell_of stub include D64_CHR_ROOM_LINKS and
   D64_CHR_PATH_SLOT for that.  With a 6502 iso_grid_cell_of the issue disappears.
3. The objects' x, y bytes hold the holder pointer while carried (`held` fields): obj_place_objects_in_room
   projects carried objects too (the Z80 projects the pointer bytes as coordinates); on the C64 the pointer
   differs, so [spr+12h,13h] and the FEh of a carried object's sprite could differ from the CPC's in a room
   where the CPC pointer happens to project.  Not seen in the sessions.
4. Code the game itself never calls (kept for the table and the checks): util_read_indirect_pair,
   obj_door_unpermitted_near's wrapper, snd_add_hl_a, snd_shift_right, snd_interrupt's Z80 entry, the IX entries
   of snd_start, snd_start_if_idle, snd_channel_tick/output, snd_tone_env_next, snd_vol_env_step/next: under
   `.ifdef PRUEBA` since the interrupt work (in the checked build only, left out of the C64 build).
   snd_psg_write stays (the pause and the tape menu call it).
5. `construye.sh` run in a group's workspace rewrites `src/c64/juego/punteros64.tsv` (punteros64.py writes there).

## Size and cycles (final build)

Bytes per exported routine (each with the internal helpers that follow it): obj_redraw_one_object 21,
obj_place_objects_in_room 3, obj_place_doors_in_room 14, obj_for_each_visible 78 (+ o_lugares), obj_update_doors
122 (+ o_siguiente, o_spr_ix), obj_object_sprite_update 30, obj_door_sprite_update 103, obj_door_mark_cells 26,
obj_door_cells 28, spr_project_entity 31, obj_door_flip_graphics 42, obj_door_camera_adjust 30,
obj_door_adjust_grid_pos 36, obj_door_check_open_close 206, obj_door_unpermitted_near 60 (+ o_no_permitido,
o_cerca), util_read_indirect_pair 44 (+ o_ix_mas_bc), chr_path_reset_alternatives 24, the 11 triggers 66,
snd_start_if_idle 13, snd_start 41 (+ s_empieza, s_pon, s_ix_x), snd_interrupt 136, snd_channel_output 146,
snd_channel_tick 348 (+ the commands and the note), snd_tone_env_next 74, snd_vol_env_step 47, snd_vol_env_next
114, snd_cmd_* 36, snd_add_hl_a 12, snd_psg_write 5, snd_shift_right 13, snd_silence_all 18.  Total 1967.

Cycles per call (SOMBRA6502_CICLOS, the check build's plat_* included, traps not): snd_interrupt 471 (all calls,
idle ones ~87; at 300 Hz ~141 000 cycles a second, ~14 % of the C64 before the real plat_psg),
snd_channel_tick 101, snd_channel_output 74, snd_tone_env_next 112, snd_vol_env_step 46, obj_update_doors 4527
(7 doors), obj_door_check_open_close 407 (was 562 through util_read_indirect_pair), util_read_indirect_pair
55, obj_door_unpermitted_near 76, obj_door_sprite_update 427, spr_project_entity 85 (+ chr_project),
obj_place_doors_in_room 1498, obj_place_objects_in_room 1733.

Long scripts largo101-116 (20000 frames each) on the full build: 0 differences in all 16 (the music, the
tercia bells, the objects taken and dropped, 490 room changes with obj_place_*, 81 obj_redraw_one_object).
