; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_path_restore_screen_grid at 07E6 (64K)   PC: 0FF4   CPC 6128: 0B76   called 4033 times by 07D6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
07E6 * ld hl,0ae2eh
07E9 * ld (028dbh),hl
07EC * push iy
07EE * ld iy,028c4h
07F2 * call iso_grid_set_origin
07F5 * ld a,(iy+004h)
07F8 * ld (0290bh),a
07FB * pop iy
07FD * scf
07FE * ret
