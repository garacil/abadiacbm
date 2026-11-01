; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_hbuf_skip_list at 35F8 (64K)   PC: 379D   CPC 6128: 3AC2   called 8 times by 35C6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
35F8 * ld a,(hl)
35F9 * cp 0ffh
35FB * ret z
35FC * bit 3,a
35FE * jr z,$+3
3600 * inc hl
3601 * inc hl
3602 * inc hl
3603 * inc hl
3604 * inc hl
3605 * jr $-13
