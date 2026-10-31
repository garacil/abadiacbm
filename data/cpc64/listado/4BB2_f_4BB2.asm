; f_4BB2 at 4BB2 (64K)   PC: -   CPC 6128: -   called 545 times by 4BA5
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4BB2 * ld a,(hl)
4BB3 * inc hl
4BB4 * cp 0ffh
4BB6 * jr nz,$-4
4BB8 * djnz $-6
4BBA * ret
4BBB   push ix
4BBD   ld hl,0a41dh
4BC0   ld (028e8h),hl
4BC3   ld a,(037e6h)
4BC6   and 001h
4BC8   jr z,$+12
4BCA   call f_4B44
4BCD   jr nz,$+34
4BCF   jr nz,$+1
4BD1   pop ix
4BD3   ret
4BD4   call f_4B44
4BD7   ld d,e
4BD8   ld a,(0ff4eh)
4BDB   pop ix
4BDD   ret
