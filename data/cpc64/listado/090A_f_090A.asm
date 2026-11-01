; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_090A at 090A (64K)   PC: -   CPC 6128: -   called 2072 times by 076A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
090A * ld bc,0004ch
090D * ld de,00001h
0910 * ld hl,(028dbh)
0913 * add hl,bc
0914 * ld b,010h
0916 * set 6,(hl)
0918 * add hl,de
0919 * djnz $-3
091B * ret
