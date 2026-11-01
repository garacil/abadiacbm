; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_door_sprite_update at 0A42 (64K)   PC: 1288   CPC 6128: 0DD2   called 9330 times by 09B9 09F9
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0A42 * ex de,hl
0A43 * call spr_save_old_rect
0A46 * push bc
0A47 * call obj_door_camera_adjust
0A4A * ld hl,0021dh
0A4D * ld a,(iy+000h)
0A50 * and 003h
0A52 * call iso_orient_relative
0A55 * add a,a
0A56 * add a,a
0A57 * add a,a
0A58 * call util_add_bx_al
0A5B * ld a,(hl)
0A5C * add a,e
0A5D * add a,c
0A5E * ld (ix+001h),a
0A61 * inc hl
0A62 * ld a,(hl)
0A63 * add a,d
0A64 * add a,b
0A65 * ld (ix+002h),a
0A68 * inc hl
0A69 * ld a,(hl)
0A6A * pop bc
0A6B * add a,c
0A6C * or 080h
0A6E * or 000h
0A70 * ld (ix+000h),a
0A73 * inc hl
0A74 * ld a,(02900h)
0A77 * or (hl)
0A78 * ld (02900h),a
0A7B * call obj_door_adjust_grid_pos
0A7E * ld de,0aa49h
0A81 * ld (ix+007h),e
0A84 * ld (ix+008h),d
0A87 * ld a,00fh
