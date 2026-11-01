; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_path_search_to_dest at 077E (64K)   PC: 0F83   CPC 6128: 0B0E   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
077E * ld h,(iy+003h)
0781 * ld l,(iy+002h)
0784 * call chr_to_hbuf_coords
0787 * ld (02903h),hl
078A * call f_3F9E
078D * ld (041d4h),hl
0790 * ld a,(02907h)
0793 * and a
0794 * jr nz,$+71
0796 * ld ix,(00213h)
079A * inc ix
079C * inc ix
079E * inc ix
07A0 * ld (00213h),ix
07A4 * ld a,(ix+000h)
07A7 * cp 0ffh
07A9 * jr z,$+45
07AB * call chr_path_clear_grid_marks
07AE * ld l,(ix+000h)
07B1 * ld h,(ix+001h)
07B4 * ld a,0fdh
07B6 * ld (02907h),a
07B9 * ld a,(iy+002h)
07BC * xor l
07BD * ld c,a
07BE * ld a,(iy+003h)
07C1 * xor h
07C2 * or c
07C3 * push af
07C4 * call z,chr_path_face_target
07C7 * pop af
07C8 * jr z,$+14
07CA * xor a
07CB * ld (02907h),a
07CE * call chr_to_hbuf_coords
07D1 * ld (02905h),hl
07D4 * jr $-86
07D6 * call chr_path_restore_screen_grid
07D9 * and a
07DA * ret
07DB * ld a,001h
07DD * ld (028fah),a
07E0 * call chr_path_clear_grid_marks
07E3 * call f_434F
