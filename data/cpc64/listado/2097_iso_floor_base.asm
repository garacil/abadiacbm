; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_floor_base at 2097 (64K)   PC: 1E97   CPC 6128: 2473   called 1192716 times by 0485 0615 061E 0816 0855 085C
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2097 * cp 00dh
2099 * ld b,000h
209B * ret c
209C * cp 018h
209E * ld b,016h
20A0 * ret nc
20A1 * ld b,00bh
20A3 * ret
