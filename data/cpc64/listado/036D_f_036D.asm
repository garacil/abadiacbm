; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_036D at 036D (64K)   PC: -   CPC 6128: -   called 26960 times by 2229
; '*' = executed in the exploration sessions; the listing runs to the next known entry
036D * ld iy,02ba5h
0371 * ld ix,037f8h
0375 * xor a
0376 * ld (037e9h),a
0379 * call f_52B4
037C * ld c,03fh
037E * call f_39F1
0381 * ld hl,02717h
0384 * call chr_update
0387 * ld ix,037f8h
038B * jp 003ach
