; f_4080 at 4080 (64K)   PC: -   CPC 6128: -   called 6479 times by 3FBD 4154
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4080 * ld a,c
4081 * and 03fh
4083 * ld c,a
4084 * ld a,000h
4086 * sub c
4087 * inc a
4088 * cp 003h
408A * ret nc
408B * ld a,(ix-001h)
408E * and 03fh
4090 * sub c
4091 * jr z,$+25
4093 * inc a
4094 * cp 003h
4096 * ret nc
4097 * ld b,a
4098 * ld a,(ix-018h)
409B * and 03fh
409D * sub c
409E * ret nz
409F * ld a,(ix-019h)
40A2 * and 03fh
40A4 * sub c
40A5 * inc a
40A6 * cp b
40A7 * ret nz
40A8 * jr $+22
40AA * ld a,(ix-018h)
40AD * and 03fh
40AF * sub c
40B0 * inc a
40B1 * cp 003h
40B3 * ret nc
40B4 * ld b,a
40B5 * ld a,(ix-019h)
40B8 * and 03fh
40BA * sub c
40BB * inc a
40BC * cp b
40BD * ret nz
40BE * set 7,(ix+000h)
40C2 * nop
40C3 * res 7,(ix+000h)
40C7 * bit 6,(ix+000h)
40CB * ld a,(03f81h)
40CE * jr nz,$+10
40D0 * set 7,(ix+000h)
40D4 * pop bc
40D5 * push de
40D6 * push bc
40D7 * ret
40D8 * pop bc
40D9 * ld (03f81h),a
40DC * ld a,0ffh
40DE * ld (02907h),a
40E1 * ld sp,(02901h)
40E5 * ei
40E6 * ret
40E7   call nz,01ea9h
40EA   ld h,e
40EB * call f_40FA
40EE * ld a,(02b88h)
40F1 * inc a
40F2 * cp 003h
40F4 * jr nz,$+60
40F6 * ld a,007h
40F8 * jr $+56
