; f_3A5D at 3A5D (64K)   PC: -   CPC 6128: -   called 21 times by 5A61
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3A5D * pop hl
3A5E * ld b,001h
3A60 * jr z,$+5
3A62 * ld b,c
3A63 * inc hl
3A64 * inc hl
3A65 * ld e,(hl)
3A66 * inc hl
3A67 * ld d,(hl)
3A68 * inc hl
3A69 * ld a,d
3A6A * or e
3A6B * jr z,$+6
3A6D * djnz $-8
3A6F * ex de,hl
3A70 * jp (hl)
3A71   push hl
3A72   ret
3A73   inc d
3A74   inc d
3A75   inc d
3A76   inc d
3A77   inc d
3A78   inc d
3A79   inc bc
3A7A   ld c,006h
3A7C   inc d
3A7D   inc d
3A7E   nop
3A7F   dec e
3A80   inc b
3A81   inc d
3A82   ret
