; f_0D40 at 0D40 (64K)   PC: -   CPC 6128: -   called 2405898 times by 0D18 0D1F 0D26
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0D40 * ld l,(ix+00eh)
0D43 * bit 0,l
0D45 * ret z
0D46 * bit 2,l
0D48 * ret nz
0D49 * bit 7,l
0D4B * ret nz
0D4C * bit 6,l
0D4E * jr z,$+21
0D50 * ld c,(ix+003h)
0D53 * ld a,(ix-003h)
0D56 * call snd_stub_psg_write
0D59 * ld c,(ix+004h)
0D5C * ld a,(ix-003h)
0D5F * inc a
0D60 * call snd_stub_psg_write
0D63 * bit 5,l
0D65 * jr z,$+52
0D67 * bit 4,l
0D69 * jr nz,$+13
0D6B * ld a,(ix-002h)
0D6E * ld c,(ix+007h)
0D71 * call snd_stub_psg_write
0D74 * jr $+37
0D76   ld a,(00c09h)
0D79   ld c,a
0D7A   ld a,00bh
0D7C   call snd_stub_psg_write
0D7F   ld a,(00c0ah)
0D82   ld c,a
0D83   ld a,00ch
0D85   call snd_stub_psg_write
0D88   ld a,(00c0bh)
0D8B   ld c,a
0D8C   ld a,00dh
0D8E   call snd_stub_psg_write
0D91   ld a,(ix-002h)
0D94   ld c,010h
0D96   call snd_stub_psg_write
0D99 * ld a,007h
0D9B * bit 1,l
0D9D * jr z,$+19
0D9F   ld a,03fh
0DA1   bit 3,l
0DA3   jr z,$+13
0DA5   ld a,(00c0ch)
0DA8   ld c,a
0DA9   ld a,006h
0DAB   call snd_stub_psg_write
0DAE   ld a,03fh
0DB0 * and (ix-001h)
0DB3 * ld c,a
0DB4 * ld a,(00c06h)
0DB7 * xor c
0DB8 * ld (00c06h),a
0DBB * ret
