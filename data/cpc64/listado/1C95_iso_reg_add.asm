; iso_reg_add at 1C95 (64K)   PC: 2AC0   CPC 6128: 2087   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1C95 * push bc
1C96 * call iso_operand_value
1C99 * ld a,c
1C9A * pop bc
1C9B * add a,c
1C9C * ld (de),a
1C9D * jr $-113
