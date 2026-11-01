; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_grid_cell_ptr at 0944 (64K)   PC: 116D   CPC 6128: 0CD4   called 1456787 times by 3F95 3FA1 400E 403C 4E04
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0944   ld a,l
0945   ld l,h
0946   ld h,000h
0948   add hl,hl
0949   add hl,hl
094A   add hl,hl
094B   ld d,h
094C   add a,l
094D   ld e,a
094E   add hl,hl
094F   add hl,de
0950   ld ix,(028dbh)
0954   ex de,hl
0955   add ix,de
0957   and a
0958   ret
