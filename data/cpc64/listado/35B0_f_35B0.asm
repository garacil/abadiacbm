; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_35B0 at 35B0 (64K)   PC: -   CPC 6128: -   called 24 times by 359E 35A4 35AA
; '*' = executed in the exploration sessions; the listing runs to the next known entry
35B0 * ld b,008h
35B2 * push bc
35B3 * push hl
35B4 * ld bc,00040h
35B7 * ex de,hl
35B8 * ldir
35BA * ex de,hl
35BB * pop hl
35BC * call f_3558
35BF * pop bc
35C0 * djnz $-14
35C2 * ret
