; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_51E7 at 51E7 (64K)   PC: -   CPC 6128: -   called 26960 times by 3CC5
; '*' = executed in the exploration sessions; the listing runs to the next known entry
51E7 * rst 8
51E8   sub b
51E9   ld b,b
51EA   defb 0fdh,03dh,09dh	;illegal sequence
51ED   ld d,b
51EE   inc a
51EF   ld h,0abh
51F1   ld h,090h
