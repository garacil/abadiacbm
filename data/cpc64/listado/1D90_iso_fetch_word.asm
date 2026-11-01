; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_fetch_word at 1D90 (64K)   PC: 2BE5   CPC 6128: 2182   called 6919 times by 1DAF 1DEE
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1D90 * ld e,(ix+000h)
1D93 * inc ix
1D95 * ld d,(ix+000h)
1D98 * inc ix
1D9A * ret
