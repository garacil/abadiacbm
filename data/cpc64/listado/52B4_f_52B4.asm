; f_52B4 at 52B4 (64K)   PC: -   CPC 6128: -   called 26960 times by 0379
; '*' = executed in the exploration sessions; the listing runs to the next known entry
52B4 * rst 8
52B5   xor h
52B6   ld (bc),a
52B7   dec a
52B8 * jr nz,$+5
52BA   jp 039a8h
52BD * rst 8
52BE   xor h
52BF   ld bc,0203dh
52C2   ld b,0cdh
52C4   rst 28h
52C5   ld a,0c3h
52C7   xor b
52C8   add hl,sp
52C9 * rst 8
52CA   adc a,h
52CB   dec bc
52CC   dec a
52CD * jr nz,$+5
52CF * jp 039a8h
52D2 * rst 8
52D3   adc a,b
52D4   nop
52D5   dec a
52D6   adc a,b
52D7   ld b,03dh
52D9   ld hl,(00720h)
52DC   rst 10h
52DD   add a,(hl)
52DE   rlca
52DF   rst 10h
52E0   adc a,(hl)
52E1   ex af,af'
52E2   ret
52E3 * rst 8
52E4   adc a,b
52E5   dec b
52E6   dec a
52E7 * jp nz,053dfh
52EA   rst 8
52EB   adc a,(hl)
52EC   inc c
