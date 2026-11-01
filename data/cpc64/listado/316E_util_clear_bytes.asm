; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; util_clear_bytes at 316E (64K)   PC: 33A7   CPC 6128: 3816   called 42 times by 317C 3185
; '*' = executed in the exploration sessions; the listing runs to the next known entry
316E * ld (hl),000h
3170 * ld e,l
3171 * ld d,h
3172 * inc de
3173 * ldir
3175 * ret
