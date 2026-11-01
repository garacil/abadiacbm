; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_flip_abbot at 2F10 (64K)   PC: 2FDE   CPC 6128: 350B   called 897 times by 25AD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F10 * ld a,(02bbah)
2F13 * xor 001h
2F15 * ld (02bbah),a
2F18 * ld hl,(02beah)
2F1B * ld bc,01405h
2F1E * jr $+57
