; spr_project_entity at 0ABC (64K)   PC: 1314   CPC 6128: 0E4C   called 190360 times by 09B4 09F4
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0ABC * ld a,0c9h
0ABE * ld (02684h),a
0AC1 * call spr_project_entity_inner
0AC4 * ld c,a
0AC5 * xor a
0AC6 * ld (02684h),a
0AC9 * ret
