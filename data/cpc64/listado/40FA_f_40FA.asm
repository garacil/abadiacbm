; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_40FA at 40FA (64K)   PC: -   CPC 6128: -   called 648 times by 40EB 410D
; '*' = executed in the exploration sessions; the listing runs to the next known entry
40FA * ld c,000h
40FC * call chr_mark_hbuf
40FF * ld a,0c9h
4101 * ld (040c2h),a
4104 * ld a,(ix+000h)
4107 * and 00fh
4109 * ld (04085h),a
410C * ret
410D * call f_40FA
4110 * ld de,(02b89h)
4114 * ld c,000h
4116 * ld a,(02b98h)
4119 * sub e
411A * jr nc,$+6
411C * neg
411E * set 2,c
4120 * ld e,a
4121 * ld a,(02b99h)
4124 * sub d
4125 * jr nc,$+6
4127 * neg
4129 * set 1,c
412B * cp e
412C * jr nc,$+3
412E * inc c
412F * ld a,c
4130 * add a,a
4131 * add a,a
4132 * ld hl,04188h
4135 * call util_add_bx_al
4138 * ex de,hl
4139 * ld b,003h
413B * ld a,(de)
413C * ld c,a
413D * push bc
413E * push ix
4140 * push de
4141 * ld hl,04180h
4144 * add a,a
4145 * call util_add_bx_al
4148 * ld c,(hl)
4149 * inc hl
414A * ld b,(hl)
414B * add ix,bc
414D * res 7,(ix+000h)
4151 * ld c,(ix+000h)
4154 * call f_4080
4157 * bit 7,(ix+000h)
415B * jr nz,$+20
415D * pop de
415E * pop ix
4160 * pop bc
4161 * inc de
4162 * djnz $-39
