; iso_op_end at 1C40 (64K)   PC: 2A58   CPC 6128: 2032   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1C40 * pop ix
1C42 * ld a,(01bdch)
1C45 * and a
1C46 * ld a,000h
1C48 * ld (01bdch),a
1C4B * ret nz
1C4C * ld a,02ch
1C4E * ld (01c60h),a
1C51 * ld (01d06h),a
1C54 * inc a
1C55 * ld (01c66h),a
1C58 * xor a
1C59 * ld (01e3eh),a
1C5C * ret
1C5D * inc h
1C5E * jr $-50
