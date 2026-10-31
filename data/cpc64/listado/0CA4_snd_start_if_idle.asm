; snd_start_if_idle at 0CA4 (64K)   PC: 0543   CPC 6128: 1034   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0CA4 * ld ix,00c40h
0CA8 * ld a,(ix+00eh)
0CAB * and a
0CAC * ret nz
0CAD   jr $+18
0CAF * ld ix,00c10h
0CB3 * jr $+12
0CB5 * ld ix,00c28h
0CB9 * jr $+6
0CBB * ld ix,00c40h
