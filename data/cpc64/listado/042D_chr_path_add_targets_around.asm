; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_path_add_targets_around at 042D (64K)   PC: 0BAF   CPC 6128: 07BD   called 64419 times by 0416
; '*' = executed in the exploration sessions; the listing runs to the next known entry
042D * push hl
042E * pop ix
0430 * push de
0431 * pop iy
0433 * ld b,(ix+001h)
0436 * call chr_path_add_target_beside
0439 * inc b
043A * call chr_path_add_target_beside
043D * inc b
043E * call chr_path_add_target_beside
0441 * inc b
