; f_5060 at 5060 (64K)   PC: -   CPC 6128: -   called 42 times by 50D3
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5060 * ld a,(028d1h)
5063 * dec a
5064 * ld b,a
5065 * add a,a
5066 * ld c,a
5067 * add a,a
5068 * add a,b
5069 * add a,c
506A * ld hl,04ad0h
506D * call util_add_bx_al
5070 * ld a,(028d2h)
5073 * call util_add_bx_al
5076 * ld h,(hl)
5077 * ld l,000h
5079 * ld (028d7h),hl
507C * ret
