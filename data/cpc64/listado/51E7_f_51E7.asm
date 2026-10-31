; f_51E7 at 51E7 (64K)   PC: -   CPC 6128: -   called 26960 times by 3CC5
; '*' = executed in the exploration sessions; the listing runs to the next known entry
51E7 * rst 8
51E8   sub b
51E9   ld b,b
51EA   defb 0fdh,03dh,09dh	;illegal sequence
51ED   ld d,b
51EE   inc a
51EF   ld h,0abh
51F1   ld h,090h
