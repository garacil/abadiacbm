; f_3CAE at 3CAE (64K)   PC: -   CPC 6128: -   called 26960 times by 3CC8
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3CAE * ld a,(02940h)
3CB1 * and 040h
3CB3 * ret z
3CB4   ld a,(0384dh)
3CB7   cp 00dh
3CB9   scf
3CBA   ret z
3CBB   cp 00eh
3CBD   scf
3CBE   ret z
3CBF   cp 00fh
3CC1   scf
3CC2   ret z
3CC3   and a
3CC4   ret
