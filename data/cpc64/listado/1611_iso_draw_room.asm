; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_draw_room at 1611 (64K)   PC: 2945   CPC 6128: 19D8   called 102 times by 21AF
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1611 * ld a,(011dch)
1614 * and a
1615 * jr z,$+4
1617   ld a,0ffh
1619 * call iso_clear_tile_buffer
161C * ld ix,(011dah)
1620 * inc ix
1622 * ld hl,012c9h
1625 * ld (012c0h),hl
1628 * ld bc,07fc7h
162B * call iso_build_room
162E * ld bc,07fc0h
1631 * ld hl,012c2h
1634 * ld (012c0h),hl
1637 * ld a,(011dch)
163A * and a
163B * jp z,04a5fh
163E   ret
