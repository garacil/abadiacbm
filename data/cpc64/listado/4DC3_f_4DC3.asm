; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4DC3 at 4DC3 (64K)   PC: -   CPC 6128: -   called 26960 times by 4C01
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4DC3 * ld a,02fh
4DC5 * call sys_key_down
4DC8 * ret z
4DC9 * ld ix,0293dh
4DCD * ld a,(ix+003h)
4DD0 * ld bc,00800h
4DD3 * inc c
4DD4 * add a,a
4DD5 * jr c,$+5
4DD7 * djnz $-4
4DD9 * ret
4DDA * ld a,c
4DDB * ld (04e4ah),a
4DDE * dec (ix+006h)
4DE1 * ld a,(ix+006h)
4DE4 * cp 0ffh
4DE6 * ret nz
4DE7 * inc (ix+006h)
4DEA * call f_4EA5
4DED * push bc
4DEE * call iso_floor_base
4DF1 * sub b
4DF2 * ld (04e17h),a
4DF5 * ld a,(0290bh)
4DF8 * cp b
4DF9 * pop hl
4DFA * push ix
4DFC * push hl
4DFD * jr nz,$+62
4DFF * call chr_to_hbuf_coords
4E02 * jr c,$+57
4E04 * call iso_grid_cell_ptr
4E07 * ld a,(ix+000h)
4E0A * ld c,a
4E0B * and 0f0h
4E0D * jr nz,$+43
4E0F * ld a,c
4E10 * and 00fh
4E12 * cp 00dh
4E14 * jr nc,$+36
4E16 * sub 000h
4E18 * cp 005h
4E1A * jr nc,$+30
4E1C * ld a,c
4E1D * and 00fh
4E1F * cp (ix-001h)
4E22 * jr nz,$+22
4E24 * cp (ix-018h)
4E27 * jr nz,$+17
4E29 * cp (ix-019h)
4E2C * jr nz,$+12
4E2E * ld c,a
4E2F * ld a,(0290bh)
4E32 * add a,c
4E33 * pop de
4E34 * pop ix
4E36 * jr $+19
4E38 * pop hl
4E39 * pop hl
4E3A * ret
4E3B   pop hl
4E3C   pop ix
4E3E   ld l,(ix+001h)
4E41   ld h,(ix+002h)
4E44   ld e,(hl)
4E45   inc hl
4E46   ld d,(hl)
4E47   inc hl
4E48   ld a,(hl)
4E49 * ld c,000h
4E4B * ld l,(ix+001h)
4E4E * ld h,(ix+002h)
4E51 * dec hl
4E52 * ld h,a
4E53 * ld a,(hl)
4E54 * xor 002h
4E56 * ld l,a
4E57 * push hl
4E58 * ld (ix+006h),010h
4E5C * ld a,c
4E5D * ld hl,08000h
4E60 * dec a
4E61 * jr z,$+8
4E63 * srl h
4E65 * rr l
4E67 * jr $-7
4E69 * ld a,l
4E6A * cpl
4E6B * and (ix+000h)
4E6E * ld (ix+000h),a
4E71 * ld a,h
4E72 * cpl
4E73 * and (ix+003h)
4E76 * ld (ix+003h),a
4E79 * ld ix,02a6ch
4E7D * ld iy,02b59h
4E81 * ld a,c
4E82 * dec a
4E83 * jr z,$+14
4E85 * ld bc,00014h
4E88 * add ix,bc
4E8A * ld bc,00005h
4E8D * add iy,bc
4E8F * jr $-13
4E91 * res 7,(iy+000h)
4E95 * pop hl
4E96 * ld (iy+004h),h
4E99 * ld (iy+001h),l
4E9C * ld (iy+002h),e
4E9F * ld (iy+003h),d
4EA2 * jp obj_redraw_one_object
