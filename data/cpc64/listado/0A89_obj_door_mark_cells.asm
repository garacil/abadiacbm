; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_door_mark_cells at 0A89 (64K)   PC: 12DE   CPC 6128: 0E19   called 20896 times by 08CC 0B86 0BCA
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0A89 * call obj_door_cells
0A8C * ret c
0A8D * ex af,af'
0A8E * ld (ix+000h),a
0A91 * add ix,bc
0A93 * ld (ix+000h),a
0A96 * add ix,bc
0A98 * ld (ix+000h),a
0A9B * ret
