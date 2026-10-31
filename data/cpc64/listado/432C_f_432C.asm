; f_432C at 432C (64K)   PC: -   CPC 6128: -   called 3095 times by 06D8 41BF 4263
; '*' = executed in the exploration sessions; the listing runs to the next known entry
432C * sub c
432D * jr nc,$+10
432F * neg
4331 * xor 002h
4333 * jr nz,$+4
4335 * ld a,002h
4337 * ld c,a
4338 * ld hl,03f75h
433B * call util_add_bx_al
433E * ld b,(hl)
433F * ld hl,03f79h
4342 * ld a,c
4343 * add a,a
4344 * call util_add_bx_al
4347 * ld d,(hl)
4348 * inc hl
4349 * ld e,(hl)
434A * ex de,hl
434B * call chr_cmd_write_bits
434E * ret
