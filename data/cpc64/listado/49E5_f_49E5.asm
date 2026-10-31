; f_49E5 at 49E5 (64K)   PC: -   CPC 6128: -   called 463353 times by 49B0 4ACA
; '*' = executed in the exploration sessions; the listing runs to the next known entry
49E5 * ld h,000h
49E7 * ld l,a
49E8 * ld c,l
49E9 * add hl,hl
49EA * add hl,hl
49EB * add hl,hl
49EC * add hl,hl
49ED * add hl,hl
49EE * ld a,083h
49F0 * add a,h
49F1 * ld h,a
49F2 * exx
49F3 * ld h,091h
49F5 * exx
49F6 * bit 7,c
49F8 * jr nz,$+26
49FA * ld a,c
49FB * and 070h
49FD * rrca
49FE * ld h,a
49FF * ld a,c
4A00 * rrca
4A01 * rrca
4A02 * rrca
4A03 * and 001h
4A05 * or h
4A06 * add a,0c6h
4A08 * ld h,a
4A09 * ld a,c
4A0A * cp 00bh
4A0C * jr c,$+40
4A0E * exx
4A0F * ld h,08fh
4A11 * exx
4A12 * ld c,008h
4A14 * ld b,004h
4A16 * ld a,(hl)
4A17 * exx
4A18 * ld l,a
4A19 * ld c,(hl)
4A1A * inc h
4A1B * ld b,(hl)
4A1C * dec h
4A1D * ld a,(de)
4A1E * and b
4A1F * or c
4A20 * ld (de),a
4A21 * inc de
4A22 * exx
4A23 * inc hl
4A24 * djnz $-14
4A26 * exx
4A27 * ld a,000h
4A29 * add a,e
4A2A * ld e,a
4A2B * ld a,000h
4A2D * adc a,d
4A2E * ld d,a
4A2F * exx
4A30 * dec c
4A31 * jr nz,$-29
4A33 * ret
4A34 * push hl
4A35 * exx
4A36 * pop hl
4A37 * ld b,008h
4A39 * ld c,008h
4A3B * ldi
4A3D * ldi
4A3F * ldi
4A41 * ldi
4A43 * ld a,000h
4A45 * add a,e
4A46 * ld e,a
4A47 * ld a,000h
4A49 * adc a,d
4A4A * ld d,a
4A4B * djnz $-18
4A4D * exx
4A4E * ret
4A4F   nop
4A50   ld h,b
4A51   ld b,b
4A52   nop
4A53   nop
4A54   ld b,004h
4A56   nop
4A57   nop
4A58   and b
4A59   ret nz
4A5A   rst 38h
4A5B   nop
4A5C   jp m,0fffch
4A5F * ld de,0c21ch
4A62 * ld a,0fch
4A64 * ld (04a28h),a
4A67 * ld (04a44h),a
4A6A * ld a,007h
4A6C * ld (04a2ch),a
4A6F * ld (04a48h),a
4A72 * ld ix,08aaah
4A76 * ld iy,04a4fh
4A7A * ld (iy+000h),004h
4A7E * ld (iy+004h),001h
4A82 * ld (iy+008h),005h
4A86 * ld (iy+00ch),002h
4A8A * ld c,008h
4A8C * ld iy,04a4fh
4A90 * ld b,004h
4A92 * push bc
4A93 * ld b,(iy+000h)
4A96 * inc (iy+000h)
4A99 * inc (iy+000h)
4A9C * push bc
4A9D * ld a,(ix+002h)
4AA0 * and a
4AA1 * call nz,f_4AC8
4AA4 * ld a,(ix+005h)
4AA7 * and a
4AA8 * call nz,f_4AC8
4AAB * ld b,(iy+003h)
4AAE * ld c,(iy+001h)
4AB1 * add ix,bc
4AB3 * ld h,b
4AB4 * ld l,(iy+002h)
4AB7 * add hl,de
4AB8 * ex de,hl
4AB9 * pop bc
4ABA * djnz $-30
4ABC * ld bc,00004h
4ABF * add iy,bc
4AC1 * pop bc
4AC2 * djnz $-48
4AC4 * dec c
4AC5 * jr nz,$-57
4AC7 * ret
