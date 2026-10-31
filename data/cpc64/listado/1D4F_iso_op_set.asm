; iso_op_set at 1D4F (64K)   PC: 2B8F   CPC 6128: 2141   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1D4F * ld a,(ix+000h)
1D52 * cp 070h
1D54 * push af
1D55 * call f_1E22
1D58 * push de
1D59 * call f_1E22
1D5C * call iso_expression
1D5F * pop de
1D60 * pop af
1D61 * jr c,$+14
1D63 * ld a,(de)
1D64 * and a
1D65 * jp z,01c2ch
1D68 * ld a,c
1D69 * cp 064h
1D6B * jr c,$+4
1D6D   ld c,000h
1D6F * ld a,c
1D70 * ld (de),a
1D71 * jp 01c2ch
