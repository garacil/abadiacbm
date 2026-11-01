; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_door_adjust_grid_pos at 0AFC (64K)   PC: 1361   CPC 6128: 0E8C   called 9330 times by 0A7B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0AFC * inc hl
0AFD * ld a,(ix+012h)
0B00 * add a,(hl)
0B01 * ld (ix+012h),a
0B04 * inc hl
0B05 * ld a,(ix+013h)
0B08 * add a,(hl)
0B09 * ld (ix+013h),a
0B0C * ret
0B0D   ld (bc),a
0B0E   nop
0B0F   nop
0B10   rst 38h
0B11   nop
0B12   call m,0ffffh
0B15   cp 000h
0B17   rst 38h
0B18   nop
0B19   nop
0B1A   inc b
0B1B   nop
0B1C   nop
