; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; ai_update_berengar at 04A0 (64K)   PC: 0C2A   CPC 6128: 0830   called 26960 times by 222F
; '*' = executed in the exploration sessions; the listing runs to the next known entry
04A0 * ld iy,02bc3h
04A4 * ld ix,03837h
04A8 * xor a
04A9 * ld (037e9h),a
04AC * call f_5495
04AF * ld c,03fh
04B1 * call f_39F1
04B4 * ld hl,0272bh
04B7 * call chr_update
04BA * ld ix,03837h
04BE * jp 003ach
