; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; txt_skip_words at 3770 (64K)   PC: 3953   CPC 6128: 3C3A   called 3409 times by 3750
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3770 * bit 7,(hl)
3772 * inc hl
3773 * jr z,$-3
3775 * djnz $-5
3777 * ret
