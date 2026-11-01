; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_tile_ptr_check at 30FD (64K)   PC: 3351   CPC 6128: 37A5   called 991838 times by 491C 49A0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
30FD * push ix
30FF * pop hl
3100 * ld de,08780h
3103 * and a
3104 * sbc hl,de
3106 * ret c
3107 * ld de,00780h
310A * sbc hl,de
310C * ccf
310D * ret
