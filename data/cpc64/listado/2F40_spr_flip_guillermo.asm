; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_flip_guillermo at 2F40 (64K)   PC: 3011   CPC 6128: 353B   called 130 times by 25AD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F40 * ld a,(02b8dh)
2F43 * xor 001h
2F45 * ld (02b8dh),a
2F48 * ld hl,0a300h
2F4B * ld bc,0ae05h
2F4E * call spr_flip_graphics_h
2F51 * ld hl,0a666h
2F54 * ld bc,02104h
