; chr_command_bit at 2765 (64K)   PC: 26A5   CPC 6128: 2C10   called 55141 times by 2813 2818 2820 2826 282B 2833
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2765 * ld a,(iy+009h)
2768 * and a
2769 * jr nz,$+21
276B * ld a,(iy+00ch)
276E * add a,(iy+00bh)
2771 * inc (iy+00bh)
2774 * ld l,a
2775 * adc a,(iy+00dh)
2778 * sub l
2779 * ld h,a
277A * ld a,(hl)
277B * ld (iy+00ah),a
277E * ld a,(iy+009h)
2781 * inc a
2782 * and 007h
2784 * ld (iy+009h),a
2787 * ld a,(iy+00ah)
278A * add a,a
278B * ld (iy+00ah),a
278E * ret
