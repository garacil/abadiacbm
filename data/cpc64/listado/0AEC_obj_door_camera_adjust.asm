; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_door_camera_adjust at 0AEC (64K)   PC: 134D   CPC 6128: 0E7C   called 9330 times by 0A47
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0AEC * ld hl,00b0dh
0AEF * ld a,003h
0AF1 * call iso_orient_relative
0AF4 * add a,a
0AF5 * add a,a
0AF6 * call util_add_bx_al
0AF9 * ld c,(hl)
0AFA * inc hl
0AFB * ld b,(hl)
