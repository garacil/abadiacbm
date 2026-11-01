; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_hbuf_fill_room at 3456 (64K)   PC: 34C3   CPC 6128: 3945   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3456 * push ix
3458 * ld ix,(03454h)
345C * ld a,(022feh)
345F * ld (0354ah),a
3462 * ld a,(022f2h)
3465 * ld (0354eh),a
3468 * call f_346E
346B * pop ix
346D * ret
