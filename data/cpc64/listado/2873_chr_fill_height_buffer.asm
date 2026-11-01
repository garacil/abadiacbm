; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_fill_height_buffer at 2873 (64K)   PC: 27E9   CPC 6128: 2D22   called 6279 times by 0836 201A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2873 * ld hl,(028dbh)
2876 * ld d,h
2877 * ld e,l
2878 * inc de
2879 * ld bc,0023fh
287C * ld (hl),000h
287E * ldir
2880 * call iso_grid_set_origin
2883 * and a
2884 * ld hl,07b98h
2887 * jr z,$+12
2889 * ld hl,09e40h
288C * cp 00bh
288E * jr z,$+5
2890   ld hl,09f60h
2893 * ld (03454h),hl
2896 * jp chr_hbuf_fill_room
