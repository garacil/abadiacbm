; iso_update_camera_room at 1F79 (64K)   PC: 1D3F   CPC 6128: 2355   called 26960 times by 21A6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1F79 * ld c,000h
1F7B * ld hl,028c6h
1F7E * ld iy,(028d9h)
1F82 * ld a,(iy+002h)
1F85 * and 0f0h
1F87 * cp (hl)
1F88 * jr z,$+9
1F8A * inc c
1F8B * ld (hl),a
1F8C * sub 00ch
1F8E * ld (02636h),a
1F91 * inc hl
1F92 * ld a,(iy+003h)
1F95 * and 0f0h
1F97 * cp (hl)
1F98 * jr z,$+9
1F9A * ld (hl),a
1F9B * inc c
1F9C * sub 00ch
1F9E * ld (02640h),a
1FA1 * inc hl
1FA2 * ld a,(iy+004h)
1FA5 * call iso_floor_base
1FA8 * ld a,b
1FA9 * cp (hl)
1FAA * jr z,$+26
1FAC   ld (0264eh),a
1FAF   ld (hl),a
1FB0   inc c
1FB1   ld hl,01e79h
1FB4   and a
1FB5   jr z,$+12
1FB7   ld hl,01f09h
1FBA   cp 00bh
1FBC   jr z,$+5
1FBE   ld hl,01f11h
1FC1   ld (02013h),hl
1FC4 * ld a,c
1FC5 * and a
1FC6 * ret z
1FC7 * ld (02909h),a
1FCA * ld a,(028c8h)
1FCD * cp 016h
1FCF * ld a,000h
1FD1 * jr nz,$+25
1FD3   ld a,(028c6h)
1FD6   cp 020h
1FD8   ld a,000h
1FDA   jr c,$+16
1FDC   ld a,001h
1FDE   jr nz,$+12
1FE0   ld a,(028c7h)
1FE3   cp 060h
1FE5   ld a,001h
1FE7   jr nz,$+3
1FE9   dec a
1FEA * ld (011dch),a
1FED * ld a,0feh
1FEF * ld (02b20h),a
1FF2 * ld hl,028c6h
1FF5 * ld c,(hl)
1FF6 * rld
1FF8 * ld (hl),c
1FF9 * and 00fh
1FFB * ld e,a
1FFC * and 001h
1FFE * ld b,a
1FFF * inc hl
2000 * ld c,(hl)
2001 * ld a,c
2002 * or e
2003 * ld e,a
2004 * rld
2006 * ld (hl),c
2007 * and 001h
2009 * xor b
200A * sla b
200C * or b
200D * ld (020a5h),a
2010 * ld d,000h
2012 * ld hl,01e79h
2015 * add hl,de
2016 * ld a,(hl)
2017 * call iso_select_room
201A * call chr_fill_height_buffer
201D * ld a,(020a5h)
2020 * rrca
2021 * rrca
2022 * ld hl,02bf0h
2025 * add a,l
2026 * ld l,a
2027 * adc a,h
2028 * sub l
2029 * ld h,a
202A * ld (028d5h),hl
202D * ld a,(020a5h)
2030 * add a,a
2031 * ld hl,01e81h
2034 * call util_add_bx_al
2037 * ld e,(hl)
2038 * inc hl
2039 * ld d,(hl)
203A * ld (02656h),de
203E * call obj_place_doors_in_room
2041 * call obj_place_objects_in_room
2044 * ld hl,02703h
2047 * ld e,(hl)
2048 * inc hl
2049 * ld a,(hl)
204A * cp 0ffh
204C * ret z
204D * ld d,a
204E * inc hl
204F * ld (02070h),de
2053 * ld e,(hl)
2054 * inc hl
2055 * ld d,(hl)
2056 * ld (02074h),de
205A * inc hl
205B * inc hl
205C * inc hl
205D * ld e,(hl)
205E * inc hl
205F * ld d,(hl)
2060 * inc hl
2061 * ld (025aeh),de
2065 * ld e,(hl)
2066 * inc hl
2067 * ld d,(hl)
2068 * inc hl
2069 * ld (025d9h),de
206D * push hl
206E * ld ix,00000h
2072 * ld iy,00000h
2076 * call spr_update_char_sprite
2079 * ld c,(iy+00eh)
207C * call chr_mark_hbuf
207F * pop hl
2080 * jr $-57
