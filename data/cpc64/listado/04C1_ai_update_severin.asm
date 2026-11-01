; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; ai_update_severin at 04C1 (64K)   PC: 0C4B   CPC 6128: 0851   called 26960 times by 2232
; '*' = executed in the exploration sessions; the listing runs to the next known entry
04C1 * ld iy,02bd2h
04C5 * ld ix,0384fh
04C9 * xor a
04CA * ld (037e9h),a
04CD * call f_571C
04D0 * ld c,02fh
04D2 * call f_39F1
04D5 * ld hl,02735h
04D8 * call chr_update
04DB * ld ix,0384fh
04DF * jp 003ach
