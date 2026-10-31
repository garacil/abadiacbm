; f_3558 at 3558 (64K)   PC: -   CPC 6128: -   called 547936 times by 16C7 35BC 367D 36E6 3B33 4B6A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3558 * ld a,h
3559 * add a,008h
355B * ld h,a
355C * ret nc
355D * ld a,040h
355F * add a,l
3560 * ld l,a
3561 * adc a,h
3562 * sub l
3563 * or 0c0h
3565 * ld h,a
3566 * ret
3567   ret
