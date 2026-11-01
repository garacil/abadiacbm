; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; parch_draw_hborder at 5271 (64K)   PC: 078B   CPC 6128: 661B   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5271   dec a
5272   add a,b
5273   ld h,b
5274   inc a
5275   ld h,020h
5277   dec b
5278   rst 10h
5279   cp a
527A   cp a
527B   ld bc,0cf26h
527E   add a,d
527F   ld d,03eh
5281 * jr nz,$+39
5283   rst 8
