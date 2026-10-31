; f_3A88 at 3A88 (64K)   PC: -   CPC 6128: -   called 21 times by 503C
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3A88 * ld hl,03a78h
3A8B * jr $+5
3A8D   ld hl,03a7dh
3A90 * ld a,004h
3A92 * ld b,07fh
3A94 * ld c,a
3A95 * dec c
3A96 * out (c),c
3A98 * ld c,(hl)
3A99 * inc hl
3A9A * set 6,c
3A9C * out (c),c
3A9E * dec a
3A9F * jr nz,$-11
3AA1 * ld c,010h
3AA3 * out (c),c
3AA5 * ld c,(hl)
3AA6 * set 6,c
3AA8 * out (c),c
3AAA * ret
3AAB   ld a,03ah
3AAD   jr $+28
