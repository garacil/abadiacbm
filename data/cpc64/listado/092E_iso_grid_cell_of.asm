; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_grid_cell_of at 092E (64K)   PC: 1152   CPC 6128: 0CBE   called 779347 times by 0470 0550 0AAE 2444
; '*' = executed in the exploration sessions; the listing runs to the next known entry
092E * ld a,(iy+004h)
0931 * call iso_floor_base
0934 * ld a,(0290bh)
0937 * cp b
0938 * scf
0939 * ret nz
093A * ld l,(iy+002h)
093D * ld h,(iy+003h)
0940 * call chr_to_hbuf_coords
0943 * ret c
