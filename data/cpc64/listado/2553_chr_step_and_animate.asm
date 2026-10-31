; chr_step_and_animate at 2553 (64K)   PC: 2455   CPC 6128: 29FE   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2553 * call chr_apply_step
2556 * ld a,(iy+000h)
2559 * inc a
255A * and 003h
255C * ld (iy+000h),a
255F * jr $+29
