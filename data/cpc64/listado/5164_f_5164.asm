; f_5164 at 5164 (64K)   PC: -   CPC 6128: -   called 612 times by 5156 515C
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5164 * and a
5165 * ret z
5166 * ld b,a
5167 * push bc
5168 * push hl
5169 * ld b,006h
516B * ld (hl),d
516C * call f_3558
516F * djnz $-4
5171 * pop hl
5172 * pop bc
5173 * inc hl
5174 * djnz $-13
5176 * ret
5177   ld c,c
5178   ld e,b
5179   ret c
517A   ld e,b
517B   ld c,c
517C   ret c
517D   ld e,b
517E   ld e,b
517F   ret
5180   rst 38h
5181   ld a,a
5182   ccf
5183   rra
5184   ld a,(0290dh)
5187   and a
5188   jr nz,$+9
518A   ld a,r
518C   and 003h
518E   jr nz,$+3
5190   inc a
5191   call nz,05199h
5194   call f_4B7C
5197   nop
5198   ret
5199   ld (0290dh),a
519C   dec a
519D   ld c,a
519E   add a,a
519F   add a,c
51A0   ld hl,05177h
51A3   call util_add_bx_al
51A6   ld de,0b59eh
51A9   ld bc,00003h
51AC   ldir
51AE   ret
51AF   jr c,$+67
51B1   ld b,c
51B2   ld b,c
51B3   dec (hl)
51B4   ld b,l
51B5   ld b,c
51B6   ld b,c
51B7   ld b,c
51B8   ld c,c
51B9   ld c,c
51BA   ld d,h
51BB   ld d,h
51BC   ld b,c
51BD   ld b,c
51BE   ld d,c
51BF   ld b,c
51C0   ld b,c
51C1   ld d,h
51C2   ld d,h
51C3   ld b,c
51C4   ld b,c
51C5   ld b,c
51C6   ld b,c
51C7   ld b,c
51C8   ld b,c
51C9   ld b,c
51CA   ld b,c
51CB   ld b,c
51CC   ld b,c
51CD   ld b,c
51CE   ld c,c
51CF   ld b,c
51D0   add hl,sp
51D1   add hl,sp
51D2   ld d,h
51D3   ld d,h
51D4   ld b,c
51D5   ld d,c
51D6   ld d,h
51D7   ld d,h
51D8   ld b,c
51D9   ld d,h
51DA   ld d,h
51DB   ld d,c
51DC   ld b,c
51DD   add hl,sp
51DE   add hl,sp
51DF   ld b,c
51E0   ld b,c
51E1   add hl,sp
51E2   ld c,c
51E3   ld c,c
51E4   dec (hl)
51E5   dec (hl)
51E6   ld d,c
