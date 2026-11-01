<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Indice-de-rutinas.md: se edita la plantilla, no esta página. -->
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

# Índice de rutinas

[Inicio](Inicio.md) · anterior: [Glosario](Glosario.md)

Todas las rutinas del juego y de la plataforma, fichero a fichero, tal como están en las fuentes: cada `.proc` y cada
etiqueta de principio de línea que lleva un comentario encima.  La columna *Original* da la dirección de la función del
Z80 que traduce la rutina en el programa de 64 KiB del CPC, cuando su comentario empieza con ella; un guion, cuando es
una rutina propia del 6502 (una ayuda, una parte de la plataforma).  Cada nombre enlaza con su línea.  Esta página la
genera `tools/wiki.py`, así que siempre está al día con el código.

## El juego (`src/c64/juego_final/`)

### `principal.s`: el arranque y el bucle principal

| Original | Rutina | Línea |
|---|---|---|
| — | [`principal_inicio`](../../../src/c64/juego_final/principal.s#L77) | 77 |
| 20BEh | [`game_main`](../../../src/c64/juego_final/principal.s#L89) | 89 |
| 3E29h | [`game_check_end`](../../../src/c64/juego_final/principal.s#L228) | 228 |
| 31DFh | [`menu_disco`](../../../src/c64/juego_final/principal.s#L333) | 333 |
| 3254h | [`suma`](../../../src/c64/juego_final/principal.s#L395) | 395 |
| 3276h | [`marca`](../../../src/c64/juego_final/principal.s#L418) | 418 |
| 31C1h | [`espera`](../../../src/c64/juego_final/principal.s#L443) | 443 |
| — | [`copia`](../../../src/c64/juego_final/principal.s#L547) | 547 |
| — | [`piezas_r`](../../../src/c64/juego_final/principal.s#L567) | 567 |
| — | [`piezas_v`](../../../src/c64/juego_final/principal.s#L576) | 576 |

### `motor_iso.s`: las salas y el motor isométrico

| Original | Rutina | Línea |
|---|---|---|
| 128Fh | [`util_add_bx_al`](../../../src/c64/juego_final/motor_iso.s#L77) | 77 |
| 1295h | [`iso_put_tile`](../../../src/c64/juego_final/motor_iso.s#L91) | 91 |
| 1D26h | [`iso_put_tile_step`](../../../src/c64/juego_final/motor_iso.s#L184) | 184 |
| — | [`mi_step`](../../../src/c64/juego_final/motor_iso.s#L187) | 187 |
| — | [`mi_step_x`](../../../src/c64/juego_final/motor_iso.s#L190) | 190 |
| 1D48h | [`iso_put_tile_times`](../../../src/c64/juego_final/motor_iso.s#L209) | 209 |
| 16A1h | [`vid_fill_play_area_ff`](../../../src/c64/juego_final/motor_iso.s#L221) | 221 |
| 16A5h | [`iso_clear_tile_buffer`](../../../src/c64/juego_final/motor_iso.s#L226) | 226 |
| 16B2h | [`vid_fill_play_area`](../../../src/c64/juego_final/motor_iso.s#L239) | 239 |
| — | [`mi_nibble`](../../../src/c64/juego_final/motor_iso.s#L255) | 255 |
| 1611h | [`iso_draw_room`](../../../src/c64/juego_final/motor_iso.s#L274) | 274 |
| 163Fh | [`iso_build_room`](../../../src/c64/juego_final/motor_iso.s#L311) | 311 |
| 17F1h | [`mi_enter_block`](../../../src/c64/juego_final/motor_iso.s#L378) | 378 |
| 17EEh | [`mi_enter_keep`](../../../src/c64/juego_final/motor_iso.s#L388) | 388 |
| 1C2Ch | [`mi_dispatch`](../../../src/c64/juego_final/motor_iso.s#L404) | 404 |
| 1DFEh | [`mi_call_return`](../../../src/c64/juego_final/motor_iso.s#L421) | 421 |
| — | [`mi_op_end`](../../../src/c64/juego_final/motor_iso.s#L444) | 444 |
| — | [`mi_op_mirror`](../../../src/c64/juego_final/motor_iso.s#L458) | 458 |
| — | [`mi_mirror_a`](../../../src/c64/juego_final/motor_iso.s#L464) | 464 |
| — | [`mi_op_y_inc`](../../../src/c64/juego_final/motor_iso.s#L475) | 475 |
| — | [`mi_op_x_dec`](../../../src/c64/juego_final/motor_iso.s#L483) | 483 |
| — | [`mi_op_y_add`](../../../src/c64/juego_final/motor_iso.s#L492) | 492 |
| — | [`mi_op_p1_inc`](../../../src/c64/juego_final/motor_iso.s#L510) | 510 |
| — | [`mi_op_loop_p2`](../../../src/c64/juego_final/motor_iso.s#L532) | 532 |
| 1CB3h | [`mi_loop_skip`](../../../src/c64/juego_final/motor_iso.s#L551) | 551 |
| — | [`mi_op_push_pos`](../../../src/c64/juego_final/motor_iso.s#L582) | 582 |
| — | [`mi_op_next`](../../../src/c64/juego_final/motor_iso.s#L598) | 598 |
| — | [`mi_op_up`](../../../src/c64/juego_final/motor_iso.s#L617) | 617 |
| — | [`mi_op_set`](../../../src/c64/juego_final/motor_iso.s#L632) | 632 |
| — | [`mi_op_jump`](../../../src/c64/juego_final/motor_iso.s#L656) | 656 |
| — | [`mi_op_call_keep`](../../../src/c64/juego_final/motor_iso.s#L670) | 670 |
| — | [`mi_ops_lo`](../../../src/c64/juego_final/motor_iso.s#L728) | 728 |
| 1D0Ah | [`iso_tile_run`](../../../src/c64/juego_final/motor_iso.s#L743) | 743 |
| — | [`mi_tile_run`](../../../src/c64/juego_final/motor_iso.s#L759) | 759 |
| 1D74h | [`iso_expression`](../../../src/c64/juego_final/motor_iso.s#L815) | 815 |
| 1D90h | [`iso_fetch_word`](../../../src/c64/juego_final/motor_iso.s#L840) | 840 |
| 1E22h | [`iso_fetch_operand`](../../../src/c64/juego_final/motor_iso.s#L856) | 856 |
| 1E27h | [`iso_operand_value`](../../../src/c64/juego_final/motor_iso.s#L866) | 866 |
| — | [`mi_fetch`](../../../src/c64/juego_final/motor_iso.s#L879) | 879 |
| — | [`mi_operand`](../../../src/c64/juego_final/motor_iso.s#L887) | 887 |
| 1BC6h | [`iso_block_depth`](../../../src/c64/juego_final/motor_iso.s#L914) | 914 |
| 1F79h | [`iso_update_camera_room`](../../../src/c64/juego_final/motor_iso.s#L947) | 947 |
| — | [`mi_setup_regs`](../../../src/c64/juego_final/motor_iso.s#L1086) | 1086 |
| 2097h | [`iso_floor_base`](../../../src/c64/juego_final/motor_iso.s#L1100) | 1100 |
| 20A4h | [`iso_orient_relative`](../../../src/c64/juego_final/motor_iso.s#L1116) | 1116 |
| — | [`iso_rotate_cam1`](../../../src/c64/juego_final/motor_iso.s#L1125) | 1125 |
| 1E6Eh | [`vid_set_crtc`](../../../src/c64/juego_final/motor_iso.s#L1148) | 1148 |

### `personajes.s`: los personajes, el teclado y el tick

| Original | Rutina | Línea |
|---|---|---|
| 2226h | [`game_run_npc_behaviours`](../../../src/c64/juego_final/personajes.s#L93) | 93 |
| 2236h | [`spr_draw_or_darken`](../../../src/c64/juego_final/personajes.s#L102) | 102 |
| 223Dh | [`personajes_dark`](../../../src/c64/juego_final/personajes.s#L111) | 111 |
| 2265h | [`spr_place_light`](../../../src/c64/juego_final/personajes.s#L146) | 146 |
| 22D4h | [`vid_clear_play_area`](../../../src/c64/juego_final/personajes.s#L204) | 204 |
| 22D8h | [`chr_step_table`](../../../src/c64/juego_final/personajes.s#L213) | 213 |
| 22E7h | [`util_add_bx_8al`](../../../src/c64/juego_final/personajes.s#L229) | 229 |
| 22F0h | [`chr_to_hbuf_coords`](../../../src/c64/juego_final/personajes.s#L245) | 245 |
| 2309h | [`chr_probe_ahead_flat`](../../../src/c64/juego_final/personajes.s#L271) | 271 |
| 230Dh | [`chr_probe_ahead`](../../../src/c64/juego_final/personajes.s#L280) | 280 |
| 2472h | [`chr_update`](../../../src/c64/juego_final/personajes.s#L581) | 581 |
| 249Ah | [`chr_think_or_step`](../../../src/c64/juego_final/personajes.s#L611) | 611 |
| 23E2h | [`chr_guillermo_behaviour`](../../../src/c64/juego_final/personajes.s#L633) | 633 |
| 24A9h | [`chr_try_advance`](../../../src/c64/juego_final/personajes.s#L704) | 704 |
| — | [`personajes_step_kept`](../../../src/c64/juego_final/personajes.s#L756) | 756 |
| 2503h | [`chr_orientation_parity`](../../../src/c64/juego_final/personajes.s#L770) | 770 |
| 250Ch | [`chr_try_advance_2x2`](../../../src/c64/juego_final/personajes.s#L782) | 782 |
| — | [`personajes_moved`](../../../src/c64/juego_final/personajes.s#L808) | 808 |
| 2539h | [`chr_apply_step`](../../../src/c64/juego_final/personajes.s#L815) | 815 |
| 2561h | [`chr_turn`](../../../src/c64/juego_final/personajes.s#L836) | 836 |
| 2549h | [`chr_step_level`](../../../src/c64/juego_final/personajes.s#L856) | 856 |
| 2553h | [`chr_step_and_animate`](../../../src/c64/juego_final/personajes.s#L859) | 859 |
| 2556h | [`chr_advance_anim`](../../../src/c64/juego_final/personajes.s#L865) | 865 |
| 257Ch | [`chr_animate`](../../../src/c64/juego_final/personajes.s#L877) | 877 |
| 2589h | [`chr_show_frame`](../../../src/c64/juego_final/personajes.s#L897) | 897 |
| 25B6h | [`chr_select_frame`](../../../src/c64/juego_final/personajes.s#L930) | 930 |
| 261Eh | [`chr_project_or_hide`](../../../src/c64/juego_final/personajes.s#L1028) | 1028 |
| 2623h | [`spr_mark_leaving`](../../../src/c64/juego_final/personajes.s#L1039) | 1039 |
| — | [`personajes_store_hl`](../../../src/c64/juego_final/personajes.s#L1230) | 1230 |
| 2765h | [`chr_command_bit`](../../../src/c64/juego_final/personajes.s#L1304) | 1304 |
| 280Dh | [`personajes_read_command`](../../../src/c64/juego_final/personajes.s#L1345) | 1345 |
| 278Fh | [`chr_ai_follow_commands`](../../../src/c64/juego_final/personajes.s#L1399) | 1399 |
| — | [`personajes_copy10`](../../../src/c64/juego_final/personajes.s#L1468) | 1468 |
| 28ADh | [`chr_backup_args`](../../../src/c64/juego_final/personajes.s#L1479) | 1479 |
| 2855h | [`iso_select_room`](../../../src/c64/juego_final/personajes.s#L1499) | 1499 |
| 2D50h | [`sys_read_keyboard`](../../../src/c64/juego_final/personajes.s#L1659) | 1659 |
| 2E98h | [`sys_key_bit`](../../../src/c64/juego_final/personajes.s#L1684) | 1684 |
| 2E42h | [`sys_test_key`](../../../src/c64/juego_final/personajes.s#L1713) | 1713 |
| — | [`kb_mira`](../../../src/c64/juego_final/personajes.s#L1898) | 1898 |
| — | [`kb_mira`](../../../src/c64/juego_final/personajes.s#L1958) | 1958 |
| 2DFCh | [`game_check_qr_mirror`](../../../src/c64/juego_final/personajes.s#L2015) | 2015 |
| 2D99h | [`game_input_and_mirror`](../../../src/c64/juego_final/personajes.s#L2050) | 2050 |
| 2EBBh | [`obj_init_mirror`](../../../src/c64/juego_final/personajes.s#L2104) | 2104 |
| 2EC4h | [`obj_close_mirror`](../../../src/c64/juego_final/personajes.s#L2115) | 2115 |
| — | [`personajes_mirror_entry`](../../../src/c64/juego_final/personajes.s#L2139) | 2139 |
| 2EE7h | [`spr_flip_adso`](../../../src/c64/juego_final/personajes.s#L2155) | 2155 |
| — | [`personajes_flip2`](../../../src/c64/juego_final/personajes.s#L2172) | 2172 |
| 2F00h | [`spr_flip_malachi`](../../../src/c64/juego_final/personajes.s#L2210) | 2210 |
| 2F57h | [`spr_flip_graphics_h`](../../../src/c64/juego_final/personajes.s#L2255) | 2255 |

### `camino.s`: los conductores y la búsqueda de caminos

| Original | Rutina | Línea |
|---|---|---|
| 036Dh | [`ai_update_malachi`](../../../src/c64/juego_final/camino.s#L72) | 72 |
| — | [`camino_drive`](../../../src/c64/juego_final/camino.s#L90) | 90 |
| 03ACh | [`camino_plan_route`](../../../src/c64/juego_final/camino.s#L151) | 151 |
| 042Dh | [`chr_path_add_targets_around`](../../../src/c64/juego_final/camino.s#L244) | 244 |
| 0442h | [`chr_path_add_target_beside`](../../../src/c64/juego_final/camino.s#L271) | 271 |
| 04E2h | [`ai_check_planned_move`](../../../src/c64/juego_final/camino.s#L629) | 629 |
| 052Eh | [`chr_cmd_discard`](../../../src/c64/juego_final/camino.s#L638) | 638 |
| 05FAh | [`chr_path_find`](../../../src/c64/juego_final/camino.s#L671) | 671 |
| 06C8h | [`chr_path_face_target`](../../../src/c64/juego_final/camino.s#L833) | 833 |
| 06E3h | [`chr_cmd_rewind`](../../../src/c64/juego_final/camino.s#L860) | 860 |
| 06FEh | [`chr_room_coords`](../../../src/c64/juego_final/camino.s#L872) | 872 |
| 0724h | [`chr_path_via_rooms`](../../../src/c64/juego_final/camino.s#L944) | 944 |
| 076Dh | [`camino_search_to_marks`](../../../src/c64/juego_final/camino.s#L1035) | 1035 |
| — | [`camino_origin`](../../../src/c64/juego_final/camino.s#L1044) | 1044 |
| 077Eh | [`chr_path_search_to_dest`](../../../src/c64/juego_final/camino.s#L1079) | 1079 |
| 07E6h | [`chr_path_restore_screen_grid`](../../../src/c64/juego_final/camino.s#L1142) | 1142 |
| 07FFh | [`iso_grid_set_origin`](../../../src/c64/juego_final/camino.s#L1163) | 1163 |
| 082Fh | [`chr_path_build_grid`](../../../src/c64/juego_final/camino.s#L1334) | 1334 |
| 08E5h | [`chr_room_distance_near`](../../../src/c64/juego_final/camino.s#L1464) | 1464 |
| 090Ah | [`chr_path_mark_exit_up`](../../../src/c64/juego_final/camino.s#L1488) | 1488 |
| 092Eh | [`iso_grid_cell_of`](../../../src/c64/juego_final/camino.s#L1533) | 1533 |
| — | [`iso_mul24_lo`](../../../src/c64/juego_final/camino.s#L1600) | 1600 |
| 0944h | [`iso_grid_cell_ptr`](../../../src/c64/juego_final/camino.s#L1612) | 1612 |
| 0959h | [`chr_cmd_write_bits`](../../../src/c64/juego_final/camino.s#L1656) | 1656 |

### `logica_a.s`: la cámara, el texto, el porcentaje

| Original | Rutina | Línea |
|---|---|---|
| 3AAFh | [`vid_spiral_wipe`](../../../src/c64/juego_final/logica_a.s#L66) | 66 |
| 3AC3h | [`vid_spiral_pass`](../../../src/c64/juego_final/logica_a.s#L96) | 96 |
| — | [`la_espiral_dir`](../../../src/c64/juego_final/logica_a.s#L209) | 209 |
| — | [`la_espiral_pon`](../../../src/c64/juego_final/logica_a.s#L240) | 240 |
| 3B2Ah | [`vid_spiral_put`](../../../src/c64/juego_final/logica_a.s#L260) | 260 |
| 3C84h | [`la_copy5`](../../../src/c64/juego_final/logica_a.s#L297) | 297 |
| 3B3Bh | [`obj_lamp_reset`](../../../src/c64/juego_final/logica_a.s#L327) | 327 |
| 3B66h | [`obj_malachi_leaves_key3`](../../../src/c64/juego_final/logica_a.s#L351) | 351 |
| 3B7Bh | [`obj_remove_glasses`](../../../src/c64/juego_final/logica_a.s#L366) | 366 |
| 3BE6h | [`la_cara_y_lugar`](../../../src/c64/juego_final/logica_a.s#L389) | 389 |
| 3B9Ch | [`chr_bernardo_arrives`](../../../src/c64/juego_final/logica_a.s#L412) | 412 |
| — | [`la_cara`](../../../src/c64/juego_final/logica_a.s#L422) | 422 |
| 3BACh | [`chr_jorge_appears`](../../../src/c64/juego_final/logica_a.s#L439) | 439 |
| 3BBCh | [`chr_berengar_vanishes`](../../../src/c64/juego_final/logica_a.s#L449) | 449 |
| 3BD8h | [`chr_berengar_hooded`](../../../src/c64/juego_final/logica_a.s#L470) | 470 |
| 3BE1h | [`util_store_dx_at_bx`](../../../src/c64/juego_final/logica_a.s#L479) | 479 |
| 3BF3h | [`obj_jorge_drops_book`](../../../src/c64/juego_final/logica_a.s#L497) | 497 |
| 3BFDh | [`obj_abbot_drops_parchment`](../../../src/c64/juego_final/logica_a.s#L505) | 505 |
| 3C0Fh | [`la_suelta`](../../../src/c64/juego_final/logica_a.s#L519) | 519 |
| — | [`obj_place_parchment`](../../../src/c64/juego_final/logica_a.s#L549) | 549 |
| 3D87h | [`obj_jorge_takes_book`](../../../src/c64/juego_final/logica_a.s#L610) | 610 |
| 3CAEh | [`ai_jorge_book_talk_with_gloves`](../../../src/c64/juego_final/logica_a.s#L628) | 628 |
| 3C8Fh | [`game_idle_camera_check`](../../../src/c64/juego_final/logica_a.s#L645) | 645 |
| 3CC5h | [`game_camera_select`](../../../src/c64/juego_final/logica_a.s#L667) | 667 |
| 3CFEh | [`game_speed_default`](../../../src/c64/juego_final/logica_a.s#L698) | 698 |
| 3D01h | [`game_speed_set`](../../../src/c64/juego_final/logica_a.s#L707) | 707 |
| 3D05h | [`util_return_zero`](../../../src/c64/juego_final/logica_a.s#L713) | 713 |
| 3D07h | [`game_set_c004_inline`](../../../src/c64/juego_final/logica_a.s#L721) | 721 |
| 3D15h | [`game_camera_update`](../../../src/c64/juego_final/logica_a.s#L754) | 754 |
| 3D3Ch | [`ai_lamp_tick`](../../../src/c64/juego_final/logica_a.s#L781) | 781 |
| 3D6Ah | [`ai_night_end_tick`](../../../src/c64/juego_final/logica_a.s#L809) | 809 |
| 3DA8h | [`game_compute_percentage`](../../../src/c64/juego_final/logica_a.s#L834) | 834 |
| 3DEEh | [`game_update_bonus_and_poison`](../../../src/c64/juego_final/logica_a.s#L899) | 899 |
| 3EE6h | [`ai_stop_hour_countdown`](../../../src/c64/juego_final/logica_a.s#L928) | 928 |
| 3EEFh | [`ai_malaquias_rise`](../../../src/c64/juego_final/logica_a.s#L940) | 940 |
| 3F15h | [`ai_check_guillermo_at_mass`](../../../src/c64/juego_final/logica_a.s#L960) | 960 |
| 3F22h | [`ai_check_guillermo_at_refectory`](../../../src/c64/juego_final/logica_a.s#L972) | 972 |
| 3F2Dh | [`ai_check_guillermo_at`](../../../src/c64/juego_final/logica_a.s#L989) | 989 |
| 3F56h | [`ai_parchment_check`](../../../src/c64/juego_final/logica_a.s#L1018) | 1018 |
| 4B44h | [`txt_print_inline`](../../../src/c64/juego_final/logica_a.s#L1057) | 1057 |
| 4BB2h | [`txt_skip_strings`](../../../src/c64/juego_final/logica_a.s#L1082) | 1082 |
| 4B57h | [`hud_clear_phrase_area`](../../../src/c64/juego_final/logica_a.s#L1100) | 1100 |
| 4B71h | [`hud_say_now`](../../../src/c64/juego_final/logica_a.s#L1123) | 1123 |
| 4B7Ch | [`hud_say`](../../../src/c64/juego_final/logica_a.s#L1137) | 1137 |
| 4BBBh | [`hud_blink_yes_no`](../../../src/c64/juego_final/logica_a.s#L1190) | 1190 |
| 4BDEh | [`obj_play_inventory_sound`](../../../src/c64/juego_final/logica_a.s#L1222) | 1222 |
| 4BECh | [`obj_update_inventory`](../../../src/c64/juego_final/logica_a.s#L1247) | 1247 |

### `logica_a_cam.s`: las búsquedas y el escritor de órdenes

| Original | Rutina | Línea |
|---|---|---|
| 40DEh | [`la_fin_busqueda`](../../../src/c64/juego_final/logica_a_cam.s#L49) | 49 |
| 3F92h | [`chr_path_room_to_marked`](../../../src/c64/juego_final/logica_a_cam.s#L61) | 61 |
| — | [`la_destino`](../../../src/c64/juego_final/logica_a_cam.s#L72) | 72 |
| 3F9Eh | [`chr_path_room_search`](../../../src/c64/juego_final/logica_a_cam.s#L83) | 83 |
| — | [`la_c_ix`](../../../src/c64/juego_final/logica_a_cam.s#L114) | 114 |
| 3FD3h | [`la_sala`](../../../src/c64/juego_final/logica_a_cam.s#L129) | 129 |
| 441Eh | [`chr_path_floor_cell_ptr`](../../../src/c64/juego_final/logica_a_cam.s#L173) | 173 |
| 438Fh | [`chr_path_floor_to_screen`](../../../src/c64/juego_final/logica_a_cam.s#L194) | 194 |
| 4399h | [`chr_path_floor_search`](../../../src/c64/juego_final/logica_a_cam.s#L208) | 208 |
| 4080h | [`cuadro`](../../../src/c64/juego_final/logica_a_cam.s#L593) | 593 |
| — | [`pend_y`](../../../src/c64/juego_final/logica_a_cam.s#L657) | 657 |
| — | [`ret_exp`](../../../src/c64/juego_final/logica_a_cam.s#L733) | 733 |
| 4080h | [`cuadro`](../../../src/c64/juego_final/logica_a_cam.s#L997) | 997 |
| — | [`ret_exp`](../../../src/c64/juego_final/logica_a_cam.s#L1118) | 1118 |
| 4164h | [`chr_adso_step_restore`](../../../src/c64/juego_final/logica_a_cam.s#L1167) | 1167 |
| 40EBh | [`chr_adso_step_guillermo_dir`](../../../src/c64/juego_final/logica_a_cam.s#L1178) | 1178 |
| 410Dh | [`chr_adso_step_aside`](../../../src/c64/juego_final/logica_a_cam.s#L1191) | 1191 |
| 4130h | [`la_adso_prueba`](../../../src/c64/juego_final/logica_a_cam.s#L1220) | 1220 |
| 41A8h | [`chr_cmd_write_one_step`](../../../src/c64/juego_final/logica_a_cam.s#L1263) | 1263 |
| 434Fh | [`chr_cmd_generate`](../../../src/c64/juego_final/logica_a_cam.s#L1283) | 1283 |
| 41B8h | [`chr_cmd_turn_and_step`](../../../src/c64/juego_final/logica_a_cam.s#L1333) | 1333 |
| 432Ch | [`chr_cmd_write_turn`](../../../src/c64/juego_final/logica_a_cam.s#L1351) | 1351 |
| 4292h | [`chr_cmd_write_step`](../../../src/c64/juego_final/logica_a_cam.s#L1389) | 1389 |
| 41C9h | [`chr_cmd_write_path`](../../../src/c64/juego_final/logica_a_cam.s#L1516) | 1516 |

### `logica_a_spr.s`: los sprites

| Original | Rutina | Línea |
|---|---|---|
| — | [`la_sw`](../../../src/c64/juego_final/logica_a_spr.s#L68) | 68 |
| — | [`la_mascara`](../../../src/c64/juego_final/logica_a_spr.s#L78) | 78 |
| — | [`la_fila_lo`](../../../src/c64/juego_final/logica_a_spr.s#L83) | 83 |
| — | [`la_mul`](../../../src/c64/juego_final/logica_a_spr.s#L93) | 93 |
| 48EBh | [`util_mul_al_bx`](../../../src/c64/juego_final/logica_a_spr.s#L116) | 116 |
| 48FCh | [`spr_rect_tile_align`](../../../src/c64/juego_final/logica_a_spr.s#L143) | 143 |
| 4886h | [`spr_rect_union_old`](../../../src/c64/juego_final/logica_a_spr.s#L176) | 176 |
| — | [`la_baldosa_io`](../../../src/c64/juego_final/logica_a_spr.s#L313) | 313 |
| 4A5Fh | [`iso_draw_room_spiral`](../../../src/c64/juego_final/logica_a_spr.s#L340) | 340 |
| — | [`la_capas`](../../../src/c64/juego_final/logica_a_spr.s#L489) | 489 |
| — | [`capa`](../../../src/c64/juego_final/logica_a_spr.s#L587) | 587 |
| 47E7h | [`spr_blit_to_screen`](../../../src/c64/juego_final/logica_a_spr.s#L639) | 639 |
| — | [`la_haz`](../../../src/c64/juego_final/logica_a_spr.s#L840) | 840 |
| — | [`haz_espera`](../../../src/c64/juego_final/logica_a_spr.s#L890) | 890 |
| 447Dh | [`spr_draw_all`](../../../src/c64/juego_final/logica_a_spr.s#L956) | 956 |
| — | [`la_mezcla`](../../../src/c64/juego_final/logica_a_spr.s#L1346) | 1346 |
| — | [`la_habito_l`](../../../src/c64/juego_final/logica_a_spr.s#L1509) | 1509 |
| — | [`la_fuente`](../../../src/c64/juego_final/logica_a_spr.s#L1547) | 1547 |
| — | [`la_tramo`](../../../src/c64/juego_final/logica_a_spr.s#L1577) | 1577 |
| — | [`la_luz`](../../../src/c64/juego_final/logica_a_spr.s#L1739) | 1739 |
| — | [`banda`](../../../src/c64/juego_final/logica_a_spr.s#L1851) | 1851 |
| — | [`aplica`](../../../src/c64/juego_final/logica_a_spr.s#L1861) | 1861 |

### `logica_b.s`: objetos, reloj, marcador y la máquina virtual de los guiones

| Original | Rutina | Línea |
|---|---|---|
| 4C46h | [`lb_pu_next`](../../../src/c64/juego_final/logica_b.s#L616) | 616 |
| — | [`lb_contador`](../../../src/c64/juego_final/logica_b.s#L764) | 764 |
| 4EA5h | [`obj_front_position`](../../../src/c64/juego_final/logica_b.s#L779) | 779 |
| 4D2Ah | [`hud_draw_guillermo_objects`](../../../src/c64/juego_final/logica_b.s#L830) | 830 |
| 4D30h | [`hud_draw_objects`](../../../src/c64/juego_final/logica_b.s#L838) | 838 |
| 4D97h | [`obj_update_key_permissions`](../../../src/c64/juego_final/logica_b.s#L911) | 911 |
| — | [`lb_espejado`](../../../src/c64/juego_final/logica_b.s#L942) | 942 |
| 4DC3h | [`obj_drop_on_space`](../../../src/c64/juego_final/logica_b.s#L978) | 978 |
| 4DCDh | [`obj_drop_object`](../../../src/c64/juego_final/logica_b.s#L992) | 992 |
| 4ECAh | [`iso_mirror_update`](../../../src/c64/juego_final/logica_b.s#L1181) | 1181 |
| 4EF4h | [`iso_mirror_character`](../../../src/c64/juego_final/logica_b.s#L1199) | 1199 |
| 4F03h | [`iso_mirror_reflect`](../../../src/c64/juego_final/logica_b.s#L1227) | 1227 |
| 4FC9h | [`iso_mirror_draw_callback`](../../../src/c64/juego_final/logica_b.s#L1365) | 1365 |
| 4FEFh | [`hud_scroll_hour_name`](../../../src/c64/juego_final/logica_b.s#L1421) | 1421 |
| 5028h | [`ai_clock_init`](../../../src/c64/juego_final/logica_b.s#L1480) | 1480 |
| 5035h | [`ai_clock_redraw`](../../../src/c64/juego_final/logica_b.s#L1489) | 1489 |
| 5060h | [`ai_clock_load_duration`](../../../src/c64/juego_final/logica_b.s#L1520) | 1520 |
| 507Dh | [`ai_clock_tick`](../../../src/c64/juego_final/logica_b.s#L1547) | 1547 |
| 5094h | [`ai_clock_advance_hour`](../../../src/c64/juego_final/logica_b.s#L1567) | 1567 |
| 50AFh | [`hud_set_and_draw_day`](../../../src/c64/juego_final/logica_b.s#L1586) | 1586 |
| 50D9h | [`hud_draw_day_numeral`](../../../src/c64/juego_final/logica_b.s#L1624) | 1624 |
| 510Ch | [`ai_timers_tick`](../../../src/c64/juego_final/logica_b.s#L1668) | 1668 |
| 5124h | [`hud_obsequium_minus_2`](../../../src/c64/juego_final/logica_b.s#L1692) | 1692 |
| 5129h | [`hud_obsequium_sub`](../../../src/c64/juego_final/logica_b.s#L1700) | 1700 |
| 5164h | [`hud_fill_bar`](../../../src/c64/juego_final/logica_b.s#L1752) | 1752 |
| 5184h | [`obj_read_manuscript`](../../../src/c64/juego_final/logica_b.s#L1774) | 1774 |
| 5199h | [`obj_set_mirror_numeral`](../../../src/c64/juego_final/logica_b.s#L1788) | 1788 |
| — | [`lb_blit`](../../../src/c64/juego_final/logica_b.s#L1815) | 1815 |
| — | [`lb_scr`](../../../src/c64/juego_final/logica_b.s#L1890) | 1890 |
| — | [`lb_nextline`](../../../src/c64/juego_final/logica_b.s#L1939) | 1939 |
| — | [`lb_der`](../../../src/c64/juego_final/logica_b.s#L1957) | 1957 |
| — | [`lb_espejos`](../../../src/c64/juego_final/logica_b.s#L1990) | 1990 |
| — | [`lb_esp_nue`](../../../src/c64/juego_final/logica_b.s#L1995) | 1995 |
| — | [`lb_masc`](../../../src/c64/juego_final/logica_b.s#L2000) | 2000 |
| — | [`lb_alu`](../../../src/c64/juego_final/logica_b.s#L2003) | 2003 |
| — | [`lb_brx`](../../../src/c64/juego_final/logica_b.s#L2005) | 2005 |
| — | [`lb_tabla`](../../../src/c64/juego_final/logica_b.s#L2007) | 2007 |
| — | [`lb_tramp`](../../../src/c64/juego_final/logica_b.s#L2013) | 2013 |

### `logica_b_guiones.s`: los guiones

| Original | Rutina | Línea |
|---|---|---|
| 51E7h | [`game_update_camera_and_bonus`](../../../src/c64/juego_final/logica_b_guiones.s#L59) | 59 |
| 52B4h | [`ai_malachi_think`](../../../src/c64/juego_final/logica_b_guiones.s#L153) | 153 |
| 5495h | [`ai_berengar_think`](../../../src/c64/juego_final/logica_b_guiones.s#L401) | 401 |
| 571Ch | [`ai_severin_think`](../../../src/c64/juego_final/logica_b_guiones.s#L716) | 716 |
| 58F7h | [`ai_adso_think`](../../../src/c64/juego_final/logica_b_guiones.s#L951) | 951 |
| 5A4Fh | [`ai_hour_change_events`](../../../src/c64/juego_final/logica_b_guiones.s#L1119) | 1119 |
| 5B21h | [`ai_abbot_think`](../../../src/c64/juego_final/logica_b_guiones.s#L1245) | 1245 |
| 5FDDh | [`ai_abbot_count_vespers`](../../../src/c64/juego_final/logica_b_guiones.s#L1852) | 1852 |
| 5FEEh | [`ai_ready_ber_adso_sev_mal`](../../../src/c64/juego_final/logica_b_guiones.s#L1860) | 1860 |
| 5FF8h | [`ai_ready_adso_sev_mal`](../../../src/c64/juego_final/logica_b_guiones.s#L1867) | 1867 |
| 6000h | [`ai_ready_vespers_day5`](../../../src/c64/juego_final/logica_b_guiones.s#L1874) | 1874 |
| 6012h | [`ai_ready_adso`](../../../src/c64/juego_final/logica_b_guiones.s#L1886) | 1886 |
| 6016h | [`ai_abbot_count_prima`](../../../src/c64/juego_final/logica_b_guiones.s#L1893) | 1893 |
| 6040h | [`ai_abbot_count_sexta`](../../../src/c64/juego_final/logica_b_guiones.s#L1912) | 1912 |
| 6076h | [`ai_abbot_wait_ceremony`](../../../src/c64/juego_final/logica_b_guiones.s#L1943) | 1943 |

### `estado_texto.s`: el estado de la partida, las alturas y el texto

| Original | Rutina | Línea |
|---|---|---|
| 39A8h | [`ai_stay`](../../../src/c64/juego_final/estado_texto.s#L204) | 204 |
| 39AEh | [`ai_guillermo_is_close`](../../../src/c64/juego_final/estado_texto.s#L211) | 211 |
| 39E5h | [`ai_next_state_on_arrival`](../../../src/c64/juego_final/estado_texto.s#L250) | 250 |
| 39F1h | [`obj_set_door_permissions`](../../../src/c64/juego_final/estado_texto.s#L275) | 275 |
| 3A37h | [`ai_hour_update`](../../../src/c64/juego_final/estado_texto.s#L376) | 376 |
| 3A58h | [`ai_say_phrase_param`](../../../src/c64/juego_final/estado_texto.s#L398) | 398 |
| 2FADh | [`obj_open_left_wing_doors`](../../../src/c64/juego_final/estado_texto.s#L410) | 410 |
| 30FDh | [`spr_tile_ptr_check`](../../../src/c64/juego_final/estado_texto.s#L424) | 424 |
| 310Eh | [`game_snapshot_initial_state`](../../../src/c64/juego_final/estado_texto.s#L444) | 444 |
| 3111h | [`game_for_each_state_block`](../../../src/c64/juego_final/estado_texto.s#L451) | 451 |
| 3166h | [`game_state_block_save`](../../../src/c64/juego_final/estado_texto.s#L483) | 483 |
| 3176h | [`game_init_new_game`](../../../src/c64/juego_final/estado_texto.s#L513) | 513 |
| 304Fh | [`spr_unflip_monk_faces`](../../../src/c64/juego_final/estado_texto.s#L565) | 565 |
| 3087h | [`obj_fix_owner_pointers`](../../../src/c64/juego_final/estado_texto.s#L602) | 602 |
| 2FB9h | [`sys_check_pause_save_load`](../../../src/c64/juego_final/estado_texto.s#L671) | 671 |
| 3456h | [`chr_hbuf_fill_room`](../../../src/c64/juego_final/estado_texto.s#L755) | 755 |
| — | [`hb_list`](../../../src/c64/juego_final/estado_texto.s#L768) | 768 |
| — | [`hb_draw`](../../../src/c64/juego_final/estado_texto.s#L945) | 945 |
| 3786h | [`util_clip_span`](../../../src/c64/juego_final/estado_texto.s#L1122) | 1122 |
| 35F8h | [`chr_hbuf_skip_list`](../../../src/c64/juego_final/estado_texto.s#L1169) | 1169 |
| 3568h | [`sys_startup_init`](../../../src/c64/juego_final/estado_texto.s#L1189) | 1189 |
| 35C3h | [`game_init_mirror`](../../../src/c64/juego_final/estado_texto.s#L1201) | 1201 |
| 3607h | [`vid_init_stub`](../../../src/c64/juego_final/estado_texto.s#L1250) | 1250 |
| 3A83h | [`vid_palette_black`](../../../src/c64/juego_final/estado_texto.s#L1331) | 1331 |

### `objetos_sonido.s`: puertas, objetos y sonido

| Original | Rutina | Línea |
|---|---|---|
| 0983h | [`obj_redraw_one_object`](../../../src/c64/juego_final/objetos_sonido.s#L77) | 77 |
| 0993h | [`obj_place_objects_in_room`](../../../src/c64/juego_final/objetos_sonido.s#L93) | 93 |
| 09ABh | [`obj_for_each_visible`](../../../src/c64/juego_final/objetos_sonido.s#L111) | 111 |
| 09D7h | [`obj_update_doors`](../../../src/c64/juego_final/objetos_sonido.s#L152) | 152 |
| — | [`o_siguiente`](../../../src/c64/juego_final/objetos_sonido.s#L196) | 196 |
| — | [`o_spr_ix`](../../../src/c64/juego_final/objetos_sonido.s#L211) | 211 |
| 0A2Bh | [`obj_object_sprite_update`](../../../src/c64/juego_final/objetos_sonido.s#L222) | 222 |
| 0A89h | [`obj_door_mark_cells`](../../../src/c64/juego_final/objetos_sonido.s#L310) | 310 |
| 0A9Ch | [`obj_door_cells`](../../../src/c64/juego_final/objetos_sonido.s#L329) | 329 |
| 0ABCh | [`spr_project_entity`](../../../src/c64/juego_final/objetos_sonido.s#L352) | 352 |
| 0AD6h | [`obj_door_flip_graphics`](../../../src/c64/juego_final/objetos_sonido.s#L376) | 376 |
| 0AFCh | [`obj_door_adjust_grid_pos`](../../../src/c64/juego_final/objetos_sonido.s#L424) | 424 |
| 0B1Dh | [`obj_door_check_open_close`](../../../src/c64/juego_final/objetos_sonido.s#L460) | 460 |
| — | [`antigua`](../../../src/c64/juego_final/objetos_sonido.s#L553) | 553 |
| — | [`o_no_permitido`](../../../src/c64/juego_final/objetos_sonido.s#L591) | 591 |
| — | [`o_cerca`](../../../src/c64/juego_final/objetos_sonido.s#L598) | 598 |
| — | [`o_ix_mas_bc`](../../../src/c64/juego_final/objetos_sonido.s#L646) | 646 |
| 0BF8h | [`chr_path_reset_alternatives`](../../../src/c64/juego_final/objetos_sonido.s#L659) | 659 |
| — | [`s_pon`](../../../src/c64/juego_final/objetos_sonido.s#L782) | 782 |
| — | [`s_interrupcion`](../../../src/c64/juego_final/objetos_sonido.s#L837) | 837 |
| — | [`s_siguiente`](../../../src/c64/juego_final/objetos_sonido.s#L1028) | 1028 |
| 0F88h | [`snd_cmd_jump`](../../../src/c64/juego_final/objetos_sonido.s#L1308) | 1308 |
| 0F8Bh | [`snd_cmd_start_b`](../../../src/c64/juego_final/objetos_sonido.s#L1318) | 1318 |
| 0FA9h | [`snd_cmd_tone_env`](../../../src/c64/juego_final/objetos_sonido.s#L1331) | 1331 |
| 0FBEh | [`snd_psg_write`](../../../src/c64/juego_final/objetos_sonido.s#L1362) | 1362 |
| 0FE6h | [`snd_silence_all`](../../../src/c64/juego_final/objetos_sonido.s#L1383) | 1383 |
| — | [`s_paso`](../../../src/c64/juego_final/objetos_sonido.s#L1425) | 1425 |
| — | [`s_canal_c`](../../../src/c64/juego_final/objetos_sonido.s#L1440) | 1440 |

### `cabezas128.s`: las cabezas en alta resolución (C128 y P500)

| Original | Rutina | Línea |
|---|---|---|
| — | [`cab_inicio`](../../../src/c64/juego_final/cabezas128.s#L156) | 156 |
| — | [`cab_apaga`](../../../src/c64/juego_final/cabezas128.s#L209) | 209 |
| — | [`cab_gira_pers`](../../../src/c64/juego_final/cabezas128.s#L233) | 233 |
| — | [`cab_espejo`](../../../src/c64/juego_final/cabezas128.s#L328) | 328 |
| — | [`registro`](../../../src/c64/juego_final/cabezas128.s#L361) | 361 |
| — | [`registro_y`](../../../src/c64/juego_final/cabezas128.s#L378) | 378 |
| — | [`es_luz`](../../../src/c64/juego_final/cabezas128.s#L395) | 395 |
| — | [`marco`](../../../src/c64/juego_final/cabezas128.s#L408) | 408 |
| — | [`paridad_marco`](../../../src/c64/juego_final/cabezas128.s#L425) | 425 |
| — | [`cab_q`](../../../src/c64/juego_final/cabezas128.s#L435) | 435 |
| — | [`cab_despues`](../../../src/c64/juego_final/cabezas128.s#L458) | 458 |
| — | [`luz_guarda`](../../../src/c64/juego_final/cabezas128.s#L586) | 586 |
| — | [`construye`](../../../src/c64/juego_final/cabezas128.s#L628) | 628 |
| — | [`lee3`](../../../src/c64/juego_final/cabezas128.s#L708) | 708 |
| — | [`marca_ini`](../../../src/c64/juego_final/cabezas128.s#L741) | 741 |
| — | [`recorre`](../../../src/c64/juego_final/cabezas128.s#L783) | 783 |
| — | [`cab_fin_rect`](../../../src/c64/juego_final/cabezas128.s#L903) | 903 |
| — | [`luz_fin`](../../../src/c64/juego_final/cabezas128.s#L922) | 922 |
| — | [`cab_marca`](../../../src/c64/juego_final/cabezas128.s#L992) | 992 |
| — | [`fila`](../../../src/c64/juego_final/cabezas128.s#L1032) | 1032 |
| — | [`snap`](../../../src/c64/juego_final/cabezas128.s#L1053) | 1053 |
| — | [`mide`](../../../src/c64/juego_final/cabezas128.s#L1145) | 1145 |
| — | [`ventana`](../../../src/c64/juego_final/cabezas128.s#L1191) | 1191 |
| — | [`todas`](../../../src/c64/juego_final/cabezas128.s#L1216) | 1216 |
| — | [`filas`](../../../src/c64/juego_final/cabezas128.s#L1324) | 1324 |
| — | [`luz_filas`](../../../src/c64/juego_final/cabezas128.s#L1347) | 1347 |

## La plataforma (`src/c64/plataforma/`)

### `interrupcion.s`: la preparación del C64 y la interrupción

| Original | Rutina | Línea |
|---|---|---|
| — | [`plat_irq`](../../../src/c64/plataforma/interrupcion.s#L139) | 139 |
| — | [`plat_nmi`](../../../src/c64/plataforma/interrupcion.s#L188) | 188 |

### `teclado.s`: el teclado y el joystick del C64

| Original | Rutina | Línea |
|---|---|---|
| — | [`tecla_cpc`](../../../src/c64/plataforma/teclado.s#L56) | 56 |
| — | [`aplica`](../../../src/c64/plataforma/teclado.s#L168) | 168 |

### `psg.s`: el AY en el SID

| Original | Rutina | Línea |
|---|---|---|
| — | [`per_lo`](../../../src/c64/plataforma/psg.s#L80) | 80 |
| — | [`sostenido`](../../../src/c64/plataforma/psg.s#L113) | 113 |
| — | [`sid_inicial`](../../../src/c64/plataforma/psg.s#L117) | 117 |
| — | [`t_lo`](../../../src/c64/plataforma/psg.s#L123) | 123 |
| — | [`otros`](../../../src/c64/plataforma/psg.s#L133) | 133 |
| — | [`plat_psg_tono`](../../../src/c64/plataforma/psg.s#L216) | 216 |
| — | [`tono`](../../../src/c64/plataforma/psg.s#L227) | 227 |
| — | [`actualiza`](../../../src/c64/plataforma/psg.s#L282) | 282 |
| — | [`pon_volumen`](../../../src/c64/plataforma/psg.s#L316) | 316 |
| — | [`suelta`](../../../src/c64/plataforma/psg.s#L350) | 350 |
| — | [`pon_frecuencia`](../../../src/c64/plataforma/psg.s#L364) | 364 |
| — | [`convierte_bajo`](../../../src/c64/plataforma/psg.s#L382) | 382 |
| — | [`tabla`](../../../src/c64/plataforma/psg.s#L426) | 426 |
| — | [`paso_c`](../../../src/c64/plataforma/psg.s#L492) | 492 |

### `disco.s`: grabar, cargar y el final

| Original | Rutina | Línea |
|---|---|---|
| — | [`fin_bloque`](../../../src/c64/plataforma/disco.s#L133) | 133 |
| — | [`pon_nombre`](../../../src/c64/plataforma/disco.s#L145) | 145 |
| — | [`irq_kernal`](../../../src/c64/plataforma/disco.s#L217) | 217 |
| — | [`kernal_sale`](../../../src/c64/plataforma/disco.s#L223) | 223 |

### `c128.s`: el Commodore 128

| Original | Rutina | Línea |
|---|---|---|
| — | [`c128_rapido`](../../../src/c64/plataforma/c128.s#L101) | 101 |
| — | [`intercambia`](../../../src/c64/plataforma/c128.s#L282) | 282 |
| — | [`bloque`](../../../src/c64/plataforma/c128.s#L319) | 319 |
| — | [`entra`](../../../src/c64/plataforma/c128.s#L333) | 333 |
| — | [`sale`](../../../src/c64/plataforma/c128.s#L360) | 360 |
| — | [`c128_ave`](../../../src/c64/plataforma/c128.s#L531) | 531 |
| — | [`espera`](../../../src/c64/plataforma/c128.s#L605) | 605 |
| — | [`c128_carga_ave`](../../../src/c64/plataforma/c128.s#L618) | 618 |
| — | [`nombre_ave`](../../../src/c64/plataforma/c128.s#L662) | 662 |

### `p500.s`, `interrupcion500.s`, `teclado500.s`: el Commodore P500

| Original | Rutina | Línea |
|---|---|---|
| — | [`p5_sid_x`](../../../src/c64/plataforma/p500.s#L215) | 215 |
| — | [`p5_vic_lee`](../../../src/c64/plataforma/p500.s#L263) | 263 |
| — | [`c128_ave`](../../../src/c64/plataforma/p500.s#L277) | 277 |
| — | [`volumen`](../../../src/c64/plataforma/p500.s#L358) | 358 |
| — | [`k15`](../../../src/c64/plataforma/p500.s#L375) | 375 |
| — | [`destino`](../../../src/c64/plataforma/p500.s#L438) | 438 |
| — | [`fondo_vuelve`](../../../src/c64/plataforma/p500.s#L449) | 449 |
| — | [`pon_kzp`](../../../src/c64/plataforma/p500.s#L460) | 460 |
| — | [`nombre_lfs`](../../../src/c64/plataforma/p500.s#L477) | 477 |
| — | [`bloque`](../../../src/c64/plataforma/p500.s#L505) | 505 |
| — | [`entra`](../../../src/c64/plataforma/p500.s#L521) | 521 |
| — | [`sale`](../../../src/c64/plataforma/p500.s#L542) | 542 |
| — | [`orden`](../../../src/c64/plataforma/p500.s#L715) | 715 |

| Original | Rutina | Línea |
|---|---|---|
| — | [`escribe`](../../../src/c64/plataforma/interrupcion500.s#L123) | 123 |
| — | [`plat_irq`](../../../src/c64/plataforma/interrupcion500.s#L179) | 179 |

| Original | Rutina | Línea |
|---|---|---|
| — | [`tecla_cpc`](../../../src/c64/plataforma/teclado500.s#L62) | 62 |
| — | [`escanea`](../../../src/c64/plataforma/teclado500.s#L115) | 115 |
| — | [`aplica`](../../../src/c64/plataforma/teclado500.s#L195) | 195 |
