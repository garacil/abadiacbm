; f_3C8F at 3C8F (64K)   PC: -   CPC 6128: -   called 26960 times by 3CCB
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3C8F * jr nc,$+14
3C91   ld a,032h
3C93   ld (037e0h),a
3C96   ld a,005h
3C98   ld (037dfh),a
3C9B   xor a
3C9C   ret
3C9D * xor a
3C9E * call sys_key_down
3CA1 * ret nz
3CA2 * ld a,008h
3CA4 * call sys_key_down
3CA7 * ret nz
3CA8 * ld a,001h
3CAA * jp sys_key_down
3CAD   nop
