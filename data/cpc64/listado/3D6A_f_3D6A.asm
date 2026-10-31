; f_3D6A at 3D6A (64K)   PC: -   CPC 6128: -   called 26973 times by 5119
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3D6A * ld c,000h
3D6C * ld hl,(028d7h)
3D6F * ld a,h
3D70 * or l
3D71 * ret z
3D72   ld a,l
3D73   and a
3D74   ret nz
3D75   ld a,(028d2h)
3D78   and a
3D79   ret nz
3D7A   ld a,h
3D7B   inc c
3D7C   cp 002h
3D7E   ret z
3D7F   dec c
3D80   and a
3D81   ret nz
3D82   inc a
3D83   ld (037e7h),a
3D86   ret
3D87   ld a,001h
3D89   ld (011dch),a
3D8C   call f_16A1
3D8F   ld a,(02940h)
3D92   and 07fh
3D94   ld (02940h),a
3D97   ld c,a
3D98   ld a,080h
3D9A   call f_4D30
3D9D   call 03c84h
3DA0   ld e,c
3DA1   dec hl
3DA2   nop
3DA3   nop
3DA4   nop
3DA5   nop
3DA6   nop
3DA7   ret
