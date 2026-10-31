; f_0DBC at 0DBC (64K)   PC: -   CPC 6128: -   called 2405898 times by 0D03 0D0A 0D11
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0DBC * ld a,(ix+00eh)
0DBF * bit 0,a
0DC1 * ret z
0DC2 * and 087h
0DC4 * ld (ix+00eh),a
0DC7 * ld a,(00c08h)
0DCA * and a
0DCB * jp nz,00e67h
0DCE * dec (ix+002h)
0DD1 * jp nz,00e67h
0DD4 * ld (ix+00eh),001h
0DD8 * ld e,(ix+000h)
0DDB * ld d,(ix+001h)
0DDE * ld b,006h
0DE0 * ld hl,00f76h
0DE3 * ld a,(de)
0DE4 * cp (hl)
0DE5 * jr nz,$+19
0DE7 * inc hl
0DE8 * ld a,(hl)
0DE9 * inc hl
0DEA * ld h,(hl)
0DEB * ld l,a
0DEC * ld bc,00ddeh
0DEF * push bc
0DF0 * ex de,hl
0DF1 * inc hl
0DF2 * ld c,(hl)
0DF3 * inc hl
0DF4 * ld b,(hl)
0DF5 * inc hl
0DF6 * ex de,hl
0DF7 * jp (hl)
0DF8 * inc hl
0DF9 * inc hl
0DFA * inc hl
0DFB * djnz $-24
0DFD * cp 0ffh
0DFF * jr nz,$+7
0E01 * ld (ix+00eh),000h
0E05 * ret
0E06 * ex de,hl
0E07 * ld b,001h
0E09 * ld (ix+011h),b
0E0C * ld (ix+008h),b
0E0F * ld (ix+012h),b
0E12 * ld (ix+00dh),b
0E15 * dec b
0E16 * ld (ix+00ch),b
0E19 * ld (ix+009h),b
0E1C * ld c,(hl)
0E1D * inc hl
0E1E * ld a,(hl)
0E1F * inc hl
0E20 * ld (ix+002h),a
0E23 * bit 7,c
0E25 * jr z,$+15
0E27   ld a,(hl)
0E28   ld (00c0ch),a
0E2B   set 1,(ix+00eh)
0E2F   set 3,(ix+00eh)
0E33   inc hl
0E34 * ld (ix+007h),000h
0E38 * ld (ix+000h),l
0E3B * ld (ix+001h),h
0E3E * set 7,(ix+00eh)
0E42 * ld a,c
0E43 * and 00fh
0E45 * cp 00fh
0E47 * ret z
0E48 * res 7,(ix+00eh)
0E4C * add a,a
0E4D * ld hl,00c55h
0E50 * call f_0FB8
0E53 * ld e,(hl)
0E54 * inc hl
0E55 * ld d,(hl)
0E56 * ld a,c
0E57 * rrca
0E58 * rrca
0E59 * rrca
0E5A * rrca
0E5B * and 007h
0E5D * ex de,hl
0E5E * call f_0FDC
0E61 * ld (ix+003h),l
0E64 * ld (ix+004h),h
0E67 * bit 7,(ix+00eh)
0E6B * ret nz
0E6C * bit 2,(ix+00eh)
0E70 * ret nz
0E71 * call f_0EE5
0E74 * dec (ix+011h)
0E77 * ret nz
0E78 * dec (ix+008h)
0E7B * call z,f_0EA1
0E7E * ld a,(ix+00fh)
0E81 * ld (ix+011h),a
0E84 * ld a,(ix+013h)
0E87 * ld d,000h
0E89 * bit 7,a
0E8B * jr z,$+3
0E8D * dec d
0E8E * ld l,(ix+003h)
0E91 * ld h,(ix+004h)
0E94 * ld e,a
0E95 * add hl,de
0E96 * ld (ix+003h),l
0E99 * ld (ix+004h),h
0E9C * set 6,(ix+00eh)
0EA0 * ret
