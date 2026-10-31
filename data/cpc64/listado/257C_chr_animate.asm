; chr_animate at 257C (64K)   PC: 247D   CPC 6128: 2A27   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
257C * call chr_select_frame
257F * ld a,0ffh
2581 * ld (02912h),a
2584 * push hl
2585 * call chr_project_or_hide
2588 * pop hl
2589 * ld a,(hl)
258A * ld (ix+007h),a
258D * inc hl
258E * ld a,(hl)
258F * ld (ix+008h),a
2592 * inc hl
2593 * ld a,(hl)
2594 * ld (ix+005h),a
2597 * inc hl
2598 * ld a,(hl)
2599 * ld (ix+006h),a
259C * ld a,080h
259E * or c
259F * ld (ix+000h),a
25A2 * ld a,(iy+001h)
25A5 * call iso_orient_relative
25A8 * srl a
25AA * xor (iy+006h)
25AD * call nz,spr_flip_guillermo
25B0 * ld a,0ffh
25B2 * ld (02912h),a
25B5 * ret
