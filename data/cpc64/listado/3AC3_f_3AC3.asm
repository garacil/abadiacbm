; f_3AC3 at 3AC3 (64K)   PC: -   CPC 6128: -   called 42 times by 3AB4 3AB9
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3AC3 * ld hl,00000h
3AC6 * ld ix,03aabh
3ACA * ld (ix+000h),03fh
3ACE * ld (ix+001h),04fh
3AD2 * ld (ix+002h),03fh
3AD6 * ld (ix+003h),04eh
3ADA * ld b,020h
3ADC * xor a
3ADD * push bc
3ADE * ld b,(ix+000h)
3AE1 * jr $+9
3AE3 * push bc
3AE4 * ld b,(ix+000h)
3AE7 * dec (ix+000h)
3AEA * dec (ix+000h)
3AED * call f_3B2A
3AF0 * inc l
3AF1 * djnz $-4
3AF3 * defb 0ddh,046h,001h
