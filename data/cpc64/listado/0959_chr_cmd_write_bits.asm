; chr_cmd_write_bits at 0959 (64K)   PC: 118E   CPC 6128: 0CE9   called 31743 times by 06E0 4327 434B 4375
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0959 * ld a,(iy+009h)
095C * cp 008h
095E * jr nz,$+25
0960 * ld (iy+009h),000h
0964 * ld a,(iy+00bh)
0967 * add a,(iy+00ch)
096A * ld e,a
096B * adc a,(iy+00dh)
096E * sub e
096F * ld d,a
0970 * inc (iy+00bh)
0973 * ld a,(iy+00ah)
0976 * ld (de),a
0977 * add hl,hl
0978 * rl (iy+00ah)
097C * inc (iy+009h)
097F * dec b
0980 * jr nz,$-39
0982 * ret
