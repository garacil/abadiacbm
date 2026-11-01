; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_cmd_rewind at 06E3 (64K)   PC: 0EC6   CPC 6128: 0A73   called 188 times by 06D5
; '*' = executed in the exploration sessions; the listing runs to the next known entry
06E3 * ld (iy+009h),000h
06E7 * ld (iy+00bh),000h
06EB * ret
06EC * xor a
06ED * ld (02907h),a
06F0 * push hl
06F1 * call chr_path_build_grid
06F4 * pop hl
06F5 * call chr_to_hbuf_coords
06F8 * ld (02905h),hl
06FB * jp chr_path_search_to_dest
