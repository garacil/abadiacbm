; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_path_face_target at 06C8 (64K)   PC: 0EA5   CPC 6128: 0A58   called 1040 times by 07C4
; '*' = executed in the exploration sessions; the listing runs to the next known entry
06C8 * ld a,(ix+002h)
06CB * rlca
06CC * rlca
06CD * and 003h
06CF * ld c,a
06D0 * ld a,(iy+001h)
06D3 * cp c
06D4 * ret z
06D5 * call chr_cmd_rewind
06D8 * call f_432C
06DB * ld hl,01000h
06DE * ld b,00ch
06E0 * call chr_cmd_write_bits
