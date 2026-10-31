; f_39F1 at 39F1 (64K)   PC: -   CPC 6128: -   called 136940 times by 037E 039F 04B1 04D2 04FC
; '*' = executed in the exploration sessions; the listing runs to the next known entry
39F1 * push ix
39F3 * ld a,(03568h)
39F6 * ld (037eah),a
39F9 * ld a,(037f3h)
39FC * and c
39FD * ld c,a
39FE * ld ix,037b4h
3A02 * ld b,006h
3A04 * srl c
3A06 * ld a,03fh
3A08 * jr c,$+3
3A0A * xor a
3A0B * ld (03a24h),a
3A0E * ld hl,0023dh
3A11 * ld a,(ix+000h)
3A14 * inc ix
3A16 * cp 0ffh
3A18 * jr z,$+19
3A1A * call util_add_bx_al
3A1D * ld a,(ix+000h)
3A20 * inc ix
3A22 * ld e,(hl)
3A23 * and a
3A24 * nop
3A25 * call f_3A30
3A28 * ld (hl),a
3A29 * jr $-27
3A2B * djnz $-39
3A2D * pop ix
3A2F * ret
