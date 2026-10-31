; iso_op_x_dec at 1C66 (64K)   PC: 2A8A   CPC 6128: 2058   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1C66 * dec l
1C67 * jr $-59
1C69 * call f_1E22
1C6C * call iso_expression
1C6F * ld a,h
1C70 * add a,c
1C71 * ld h,a
1C72 * jr $-70
1C74 * call f_1E22
1C77 * call iso_expression
1C7A * ld a,l
1C7B * add a,c
1C7C * ld l,a
1C7D * jr $-81
1C7F * ld c,001h
1C81 * ld a,06eh
1C83 * jr $+18
1C85 * ld a,06dh
1C87 * ld c,001h
1C89 * jr $+12
1C8B   ld a,06eh
1C8D   ld c,0ffh
1C8F   jr $+6
1C91   ld a,06dh
1C93   ld c,0ffh
