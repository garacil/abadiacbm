; f_4FEF at 4FEF (64K)   PC: -   CPC 6128: -   called 26960 times by 219D
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4FEF * ld a,(028f6h)
4FF2 * and a
4FF3 * ret z
4FF4 * dec a
4FF5 * ld (028f6h),a
4FF8 * cp 007h
4FFA * ld a,020h
4FFC * jr nc,$+10
4FFE * ld hl,(028d3h)
5001 * ld a,(hl)
5002 * inc hl
5003 * ld (028d3h),hl
5006 * ld hl,0b40dh
5009 * ld (028e8h),hl
500C * ld hl,0e583h
500F * ld b,008h
5011 * push af
5012 * push bc
5013 * push hl
5014 * ld bc,0000ch
5017 * ld d,h
5018 * ld e,l
5019 * dec de
501A * dec de
501B * ldir
501D * pop hl
501E * call f_3558
5021 * pop bc
5022 * djnz $-16
5024 * pop af
5025 * jp txt_draw_char
