; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_to_hbuf_coords at 22F0 (64K)   PC: 21A9   CPC 6128: 279B   called 618858 times by 0596 059F 06F5 0773 0784 07CE
; '*' = executed in the exploration sessions; the listing runs to the next known entry
22F0 * ld a,h
22F1 * sub 000h
22F3 * ret c
22F4 * cp 002h
22F6 * ret c
22F7 * cp 016h
22F9 * ccf
22FA * ret c
22FB * ld h,a
22FC * ld a,l
22FD * sub 000h
22FF * ret c
2300 * cp 002h
2302 * ret c
2303 * cp 016h
2305 * ccf
2306 * ret c
2307 * ld l,a
2308 * ret
