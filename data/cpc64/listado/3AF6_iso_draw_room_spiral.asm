; iso_draw_room_spiral at 3AF6 (64K)   PC: 1BD6   CPC 6128: 4EB2   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3AF6 * dec (ix+001h)
3AF9 * dec (ix+001h)
3AFC * call f_3B2A
3AFF * inc h
3B00 * inc h
3B01 * djnz $-5
3B03 * ld b,(ix+002h)
3B06 * dec (ix+002h)
3B09 * dec (ix+002h)
3B0C * call f_3B2A
3B0F * dec l
3B10 * djnz $-4
3B12 * ld b,(ix+003h)
3B15 * dec (ix+003h)
3B18 * dec (ix+003h)
3B1B * call f_3B2A
3B1E * dec h
3B1F * dec h
3B20 * djnz $-5
3B22 * pop bc
3B23 * xor e
3B24 * djnz $-65
3B26 * call f_3B2A
3B29 * ret
