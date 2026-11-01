; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; snd_start at 0CBF (64K)   PC: 0553   CPC 6128: 104F   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0CBF * di
0CC0 * ld (ix+00eh),005h
0CC4 * ld (ix+000h),l
0CC7 * ld (ix+001h),h
0CCA * ld (ix+002h),001h
0CCE * ei
0CCF * ret
