; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_flip_adso at 2EE7 (64K)   PC: 2FB4   CPC 6128: 34E2   called 389 times by 25AD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2EE7 * ld a,(02b9ch)
2EEA * xor 001h
2EEC * ld (02b9ch),a
2EEF * ld hl,0a6eah
2EF2 * ld bc,05f05h
2EF5 * call spr_flip_graphics_h
2EF8 * ld hl,0a8c5h
2EFB * ld bc,05a04h
2EFE * jr $+89
