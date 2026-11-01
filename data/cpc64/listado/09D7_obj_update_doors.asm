; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_update_doors at 09D7 (64K)   PC: 1217   CPC 6128: 0D67   called 26960 times by 21BA
; '*' = executed in the exploration sessions; the listing runs to the next known entry
09D7 * ld ix,029e0h
09DB * ld iy,02b35h
09DF * xor a
09E0 * ld (02900h),a
09E3 * ld a,(iy+000h)
09E6 * cp 0ffh
09E8 * ret z
09E9 * xor a
09EA * ld (00a6fh),a
09ED * push ix
09EF * call obj_door_check_open_close
09F2 * pop ix
09F4 * call spr_project_entity
09F7 * push ix
09F9 * call nc,obj_door_sprite_update
09FC * pop ix
09FE * ld a,(02909h)
0A01 * and a
0A02 * jr nz,$+29
0A04 * ld a,(ix+000h)
0A07 * cp 0feh
0A09 * jr z,$+22
0A0B * bit 7,a
0A0D * jr z,$+18
0A0F   push ix
0A11   bit 6,(iy+001h)
0A15   push af
0A16   call nz,snd_play_door_open
0A19   pop af
0A1A   call z,snd_stub_door_close
0A1D   pop ix
0A1F * ld bc,00005h
0A22 * add iy,bc
0A24 * ld bc,00014h
0A27 * add ix,bc
0A29 * jr $-70
