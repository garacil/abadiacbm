; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_path_build_grid at 082F (64K)   PC: 1041   CPC 6128: 0BBF   called 6177 times by 06F1 0767
; '*' = executed in the exploration sessions; the listing runs to the next known entry
082F * ld de,08174h
0832 * ld (028dbh),de
0836 * call chr_fill_height_buffer
0839 * ld a,(02b89h)
083C * ld c,(iy+002h)
083F * call chr_room_distance_near
0842 * ld b,a
0843 * jr nc,$+33
0845 * ld a,(02b8ah)
0848 * ld c,(iy+003h)
084B * call chr_room_distance_near
084E * ld c,a
084F * jr nc,$+21
0851 * push bc
0852 * ld a,(iy+004h)
0855 * call iso_floor_base
0858 * ld c,b
0859 * ld a,(02b8bh)
085C * call iso_floor_base
085F * ld a,b
0860 * cp c
0861 * pop bc
0862 * jr z,$+37
0864 * ld a,(028c6h)
0867 * ld c,(iy+002h)
086A * call chr_room_distance_near
086D * ld b,a
086E * ret nc
086F * ld a,(028c7h)
0872 * ld c,(iy+003h)
0875 * call chr_room_distance_near
0878 * ld c,a
0879 * ret nc
087A   push bc
087B   ld a,(iy+004h)
087E   call iso_floor_base
0881   ld a,(028c8h)
0884   cp b
0885   pop bc
0886   ret nz
0887 * ld (008a0h),iy
088B * ld hl,0270fh
088E * ld a,b
088F * cp 001h
0891 * ld b,005h
0893 * jr nz,$+11
0895 * ld a,c
0896 * cp 001h
0898 * jr nz,$+6
089A * ld hl,02705h
089D * inc b
089E * push bc
089F * ld bc,00000h
08A2 * ld e,(hl)
08A3 * inc hl
08A4 * ld d,(hl)
08A5 * inc hl
08A6 * ld a,d
08A7 * xor b
08A8 * jr nz,$+6
08AA * ld a,e
08AB * xor c
08AC * jr z,$+12
08AE * push hl
08AF * push de
08B0 * pop iy
08B2 * ld c,010h
08B4 * call chr_mark_hbuf
08B7 * pop hl
08B8 * ld bc,00008h
08BB * add hl,bc
08BC * pop bc
08BD * djnz $-31
08BF * ld iy,02b35h
08C3 * ld de,00005h
08C6 * ld a,00fh
08C8 * bit 6,(iy+001h)
08CC * call nz,obj_door_mark_cells
08CF * ld de,00005h
08D2 * add iy,de
08D4 * ld a,(iy+000h)
08D7 * cp 0ffh
08D9 * jr nz,$-19
08DB * ld iy,(008a0h)
08DF * ld c,000h
08E1 * call chr_mark_hbuf
08E4 * ret
