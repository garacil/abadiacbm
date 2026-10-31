; spr_flip_graphics_h at 2F57 (64K)   PC: 3028   CPC 6128: 3552   called 540 times by 2136 2EF5 2F4E
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F57 * push bc
2F58 * ld e,l
2F59 * ld d,h
2F5A * ld b,000h
2F5C * ld (02fa3h),bc
2F60 * dec c
2F61 * add hl,bc
2F62 * exx
2F63 * pop bc
2F64 * inc c
2F65 * srl c
2F67 * ld l,c
2F68 * exx
2F69 * push de
2F6A * ld b,h
2F6B * ld c,l
2F6C * exx
2F6D * exx
2F6E * ld a,(bc)
2F6F * ld h,a
2F70 * ld l,000h
2F72 * rra
2F73 * adc hl,hl
2F75 * rra
2F76 * adc hl,hl
2F78 * rra
2F79 * adc hl,hl
2F7B * rra
2F7C * adc hl,hl
2F7E * rra
2F7F * and 0f0h
2F81 * or l
2F82 * ex af,af'
2F83 * ld a,(de)
2F84 * ld h,a
2F85 * ld l,000h
2F87 * rra
2F88 * adc hl,hl
2F8A * rra
2F8B * adc hl,hl
2F8D * rra
2F8E * adc hl,hl
2F90 * rra
2F91 * adc hl,hl
2F93 * rra
2F94 * and 0f0h
2F96 * or l
2F97 * ld (bc),a
2F98 * ex af,af'
2F99 * ld (de),a
2F9A * dec bc
2F9B * inc de
2F9C * exx
2F9D * dec l
2F9E * jr nz,$-49
2FA0 * exx
2FA1 * pop hl
2FA2 * ld de,00000h
2FA5 * add hl,de
2FA6 * ex de,hl
2FA7 * dec l
2FA8 * add hl,de
2FA9 * exx
2FAA * djnz $-67
2FAC * ret
