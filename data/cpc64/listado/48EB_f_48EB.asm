; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_48EB at 48EB (64K)   PC: -   CPC 6128: -   called 110024 times by 455D 4638 4671 468C 4809
; '*' = executed in the exploration sessions; the listing runs to the next known entry
48EB * ld b,008h
48ED * ld de,00000h
48F0 * srl a
48F2 * jr nc,$+6
48F4 * push hl
48F5 * add hl,de
48F6 * ex de,hl
48F7 * pop hl
48F8 * add hl,hl
48F9 * djnz $-9
48FB * ret
