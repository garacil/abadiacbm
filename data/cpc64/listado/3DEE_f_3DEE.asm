; f_3DEE at 3DEE (64K)   PC: -   CPC 6128: -   called 26960 times by 219A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3DEE * ld a,(02940h)
3DF1 * ld c,a
3DF2 * and 04ch
3DF4 * ld b,a
3DF5 * ld a,(02947h)
3DF8 * and 002h
3DFA * or b
3DFB * ld b,a
3DFC * ld a,(0290fh)
3DFF * or b
3E00 * ld (0290fh),a
3E03 * ld a,c
3E04 * and 080h
3E06 * ret z
3E07   bit 6,c
3E09   ret nz
3E0A   ld a,(037d2h)
3E0D   inc a
3E0E   ld (037d2h),a
3E11   ret nz
3E12   ld a,(0296ah)
3E15   srl a
3E17   ld (023e4h),a
3E1A   ld a,0feh
3E1C   ld (02406h),a
3E1F   ld a,001h
3E21   ld (037e4h),a
3E24   call f_4B71
3E27   defb 022h,0c9h
