; util_read_indirect_pair at 0BEC (64K)   PC: 1486   CPC 6128: 0F7C   called 674000 times by 0B60 0BE0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0BEC * ld a,(hl)
0BED * inc hl
0BEE * ld b,(hl)
0BEF * inc hl
0BF0 * push hl
0BF1 * ld l,a
0BF2 * ld h,b
0BF3 * ld a,(hl)
0BF4 * inc hl
0BF5 * ld b,(hl)
0BF6 * pop hl
0BF7 * ret
