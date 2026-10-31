; chr_try_advance_2x2 at 250C (64K)   PC: 2405   CPC 6128: 29B7   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
250C * cp 001h
250E * jr z,$+10
2510 * cp 0ffh
2512 * jr z,$+13
2514 * and a
2515 * ret nz
2516 * jr $+51
2518 * inc (iy+004h)
251B * ld a,080h
251D * jr $+7
251F * dec (iy+004h)
2522 * ld a,090h
2524 * ld (iy+005h),a
2527 * push hl
2528 * call chr_apply_step
252B * pop hl
252C * call chr_orientation_parity
252F * call nz,chr_apply_step
2532 * ld a,0ffh
2534 * ld (02912h),a
2537 * jr $+31
