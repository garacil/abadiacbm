; f_090A at 090A (64K)   PC: -   CPC 6128: -   called 2072 times by 076A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
090A * ld bc,0004ch
090D * ld de,00001h
0910 * ld hl,(028dbh)
0913 * add hl,bc
0914 * ld b,010h
0916 * set 6,(hl)
0918 * add hl,de
0919 * djnz $-3
091B * ret
