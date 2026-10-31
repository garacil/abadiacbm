; f_4B7C at 4B7C (64K)   PC: -   CPC 6128: -   called 260 times by 5B5F 5DC7 5DFB
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4B7C * pop hl
4B7D * inc hl
4B7E * push hl
4B7F * ld a,(028f2h)
4B82 * and a
4B83 * ret nz
4B84 * di
4B85 * dec hl
4B86 * ld de,051afh
4B89 * ld a,(hl)
4B8A * ex de,hl
4B8B * call util_add_bx_al
4B8E * ld a,(hl)
4B8F * ld (01127h),a
4B92 * ex de,hl
4B93 * ld b,(hl)
4B94 * inc hl
4B95 * ld a,001h
4B97 * ld (028f2h),a
4B9A * ld (028f3h),a
4B9D * ld (028f1h),a
4BA0 * ld hl,0bb00h
4BA3 * ld a,b
4BA4 * and a
4BA5 * call nz,f_4BB2
4BA8 * ld (028efh),hl
4BAB * xor a
4BAC * ld (028ech),a
4BAF * scf
4BB0 * ei
4BB1 * ret
