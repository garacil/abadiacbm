; chr_turn at 2561 (64K)   PC: 2462   CPC 6128: 2A0C   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2561 * ld (iy+000h),000h
2565 * bit 7,(iy+005h)
2569 * jr z,$+10
256B * ld a,(iy+005h)
256E * xor 020h
2570 * ld (iy+005h),a
2573 * ld a,(iy+001h)
2576 * add a,c
2577 * and 003h
2579 * defb 0fdh,077h,001h
