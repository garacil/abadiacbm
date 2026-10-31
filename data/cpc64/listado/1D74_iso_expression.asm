; iso_expression at 1D74 (64K)   PC: 2BC4   CPC 6128: 2166   called 8435 times by 1C6C 1C77 1D5C
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1D74 * ld a,(ix+000h)
1D77 * cp 0c8h
1D79 * ret nc
1D7A * cp 084h
1D7C * jr nz,$+10
1D7E * inc ix
1D80 * ld a,c
1D81 * neg
1D83 * ld c,a
1D84 * jr $-16
1D86 * push bc
1D87 * call f_1E22
1D8A * ld a,c
1D8B * pop bc
1D8C * add a,c
1D8D * ld c,a
1D8E * jr $-26
