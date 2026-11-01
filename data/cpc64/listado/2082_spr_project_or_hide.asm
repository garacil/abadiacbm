; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_project_or_hide at 2082 (64K)   PC: 1E83   CPC 6128: 245E   called 612 times by 2090
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2082 * call chr_project
2085 * ld (ix+000h),0feh
2089 * pop hl
208A * pop hl
208B * ret
