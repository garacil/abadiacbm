; spr_tile_ptr_check at 30FD (64K)   PC: 3351   CPC 6128: 37A5   called 991838 times by 491C 49A0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
30FD * push ix
30FF * pop hl
3100 * ld de,08780h
3103 * and a
3104 * sbc hl,de
3106 * ret c
3107 * ld de,00780h
310A * sbc hl,de
310C * ccf
310D * ret
