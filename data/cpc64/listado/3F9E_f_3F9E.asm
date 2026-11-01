; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3F9E at 3F9E (64K)   PC: -   CPC 6128: -   called 5512 times by 078A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3F9E * ld hl,(02905h)
3FA1 * call iso_grid_cell_ptr
3FA4 * ld (02901h),sp
3FA8 * ld a,(ix+000h)
3FAB * and 00fh
3FAD * ld (04085h),a
3FB0 * ld c,a
3FB1 * cp 00eh
3FB3 * ld a,000h
3FB5 * jp nc,040deh
3FB8 * ld a,0c9h
3FBA * ld (040c2h),a
3FBD * call f_4080
3FC0 * xor a
3FC1 * ld (040c2h),a
3FC4 * bit 7,(ix+000h)
3FC8 * jp z,040deh
3FCB * res 7,(ix+000h)
3FCF * set 6,(ix+000h)
3FD3 * ld hl,(028dbh)
3FD6 * ld bc,00228h
3FD9 * ld e,l
3FDA * ld d,h
3FDB * add hl,bc
3FDC * ex de,hl
3FDD * ld ix,(028dbh)
3FE1 * ld b,018h
3FE3 * set 7,(hl)
3FE5 * set 7,(ix+000h)
3FE9 * set 7,(ix+017h)
3FED * ld a,(de)
3FEE * or 080h
3FF0 * ld (de),a
3FF1 * ld a,b
3FF2 * ld bc,00018h
3FF5 * add ix,bc
3FF7 * ld b,a
3FF8 * inc de
3FF9 * inc hl
3FFA * djnz $-23
3FFC * ld (02901h),sp
4000 * ld sp,0877eh
4003 * ld a,001h
4005 * ld (03f82h),a
4008 * ld de,(02903h)
400C * push de
400D * ex de,hl
400E * call iso_grid_cell_ptr
4011 * set 7,(ix+000h)
4015 * ld hl,0ffffh
4018 * push hl
4019 * ld hl,0877eh
401C * dec hl
401D * ld d,(hl)
401E * dec hl
401F * ld e,(hl)
4020 * ld a,e
4021 * and 080h
4023 * jr z,$+22
4025 * xor a
4026 * ld b,h
4027 * ld c,l
4028 * sbc hl,sp
402A * ld l,c
402B * ld h,b
402C * jp z,040deh
402F * push de
4030 * ld a,(03f82h)
4033 * inc a
4034 * ld (03f82h),a
4037 * jr $-27
4039 * push hl
403A * push de
403B * ex de,hl
403C * call iso_grid_cell_ptr
403F * pop de
4040 * pop hl
4041 * ld a,(ix+000h)
4044 * and 00fh
4046 * ld (04085h),a
4049 * ld a,002h
404B * inc ix
404D * inc e
404E * call f_4077
4051 * ld a,003h
4053 * ld bc,0ffe7h
4056 * add ix,bc
4058 * dec e
4059 * dec d
405A * call f_4077
405D * ld a,000h
405F * ld bc,00017h
4062 * add ix,bc
4064 * inc d
4065 * dec e
4066 * call f_4077
4069 * ld a,001h
406B * ld bc,00019h
406E * add ix,bc
4070 * inc d
4071 * inc e
4072 * call f_4077
4075 * jr $-89
