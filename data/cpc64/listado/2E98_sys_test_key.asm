; sys_test_key at 2E98 (64K)   PC: 2EEB   CPC 6128: 348D   called 596686 times by 2E6C
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2E98 * ld c,a
2E99 * srl a
2E9B * srl a
2E9D * srl a
2E9F * add a,e
2EA0 * ld e,a
2EA1 * adc a,d
2EA2 * sub e
2EA3 * ld d,a
2EA4 * ld a,c
2EA5 * and 007h
2EA7 * ld hl,02eb3h
2EAA * add a,l
2EAB * ld l,a
2EAC * adc a,h
2EAD * sub l
2EAE * ld h,a
2EAF * ld a,(de)
2EB0 * cpl
2EB1 * and (hl)
2EB2 * ret
2EB3   ld bc,00402h
2EB6   ex af,af'
2EB7   djnz $+34
2EB9   ld b,b
2EBA   add a,b
