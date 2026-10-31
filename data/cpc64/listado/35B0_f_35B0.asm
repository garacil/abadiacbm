; f_35B0 at 35B0 (64K)   PC: -   CPC 6128: -   called 24 times by 359E 35A4 35AA
; '*' = executed in the exploration sessions; the listing runs to the next known entry
35B0 * ld b,008h
35B2 * push bc
35B3 * push hl
35B4 * ld bc,00040h
35B7 * ex de,hl
35B8 * ldir
35BA * ex de,hl
35BB * pop hl
35BC * call f_3558
35BF * pop bc
35C0 * djnz $-14
35C2 * ret
