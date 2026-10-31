; iso_select_room at 2855 (64K)   PC: 27C8   CPC 6128: 2D00   called 102 times by 2017
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2855 * ld (0290eh),a
2858 * ld hl,06100h
285B * and a
285C * jr z,$+19
285E * di
285F * ld bc,07fc7h
2862 * ld b,a
2863 * ld a,(hl)
2864 * add a,l
2865 * ld l,a
2866 * adc a,h
2867 * sub l
2868 * ld h,a
2869 * djnz $-6
286B * ld bc,07fc0h
286E * ei
286F * ld (011dah),hl
2872 * ret
