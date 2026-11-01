; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_flip_berengar at 2F20 (64K)   PC: 2FEF   CPC 6128: 351B   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F20   ld a,(02bc9h)
2F23   xor 001h
2F25   ld (02bc9h),a
2F28   ld hl,(02bech)
2F2B   ld bc,01405h
2F2E   jr $+41
