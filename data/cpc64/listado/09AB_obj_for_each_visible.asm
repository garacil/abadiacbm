; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_for_each_visible at 09AB (64K)   PC: 11E8   CPC 6128: 0D3B   called 8 times by 098B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
09AB * ld (009bah),hl
09AE * ld a,(iy+000h)
09B1 * cp 0ffh
09B3 * ret z
09B4 * call spr_project_entity
09B7 * push ix
09B9 * call nc,obj_door_sprite_update
09BC * pop ix
09BE * ld a,(ix+001h)
09C1 * ld (ix+003h),a
09C4 * ld a,(ix+002h)
09C7 * ld (ix+004h),a
09CA * ld bc,00005h
09CD * add iy,bc
09CF * ld bc,00014h
09D2 * add ix,bc
09D4 * nop
09D5 * jr $-39
