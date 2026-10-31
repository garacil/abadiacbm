; f_5495 at 5495 (64K)   PC: -   CPC 6128: -   called 26960 times by 04AC
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5495 * rst 8
5496   xor e
5497   ld bc,0203dh
549A   inc bc
549B   jp 039a8h
549E * rst 8
549F   adc a,l
54A0   inc bc
54A1   dec a
54A2 * jr nz,$+103
54A4   rst 8
54A5   adc a,b
54A6   ld bc,0203dh
54A9   inc bc
54AA   jp 039a8h
54AD   rst 8
54AE   adc a,b
54AF   ld (bc),a
54B0   dec a
54B1   jr nz,$+56
54B3   rst 8
54B4   sub d
54B5   ld e,03dh
54B7   jr nz,$+14
54B9   rst 8
54BA   adc a,c
54BB   nop
54BC   dec a
54BD   jr nz,$+5
54BF   rst 10h
54C0   sub d
54C1   rra
54C2   jp 039a8h
54C5   rst 8
54C6   sub d
54C7   rra
54C8   dec a
54C9   jr nz,$+17
54CB   call ai_guillermo_is_close
54CE   jr nz,$+9
54D0   call f_4B7C
54D3   ld (09bd7h),a
54D6   ld bc,0a8c3h
54D9   add hl,sp
54DA   call ai_guillermo_is_close
54DD   jr nz,$+9
54DF   call f_4B71
54E2   ld sp,092d7h
54E5   ld e,0c3h
54E7   xor b
54E8   add hl,sp
54E9   rst 8
54EA   adc a,b
54EB   inc bc
54EC   dec a
54ED   jr nz,$+28
54EF   rst 10h
54F0   sub b
54F1   inc bc
54F2   rst 10h
54F3   sub d
54F4   nop
54F5   rst 8
54F6   sbc a,l
54F7   ld h,b
54F8   dec a
54F9   jr nz,$+6
54FB   call f_4B7C
54FE   daa
54FF   rst 8
5500   sub c
5501   inc bc
5502   dec a
5503   jr nz,$+5
5505   rst 10h
5506   xor e
5507   ld bc,0cfc9h
550A   adc a,b
550B   inc bc
550C   dec a
550D * jr nz,$+6
550F   rst 10h
5510   sub b
5511   ld bc,0cfc9h
5514   adc a,b
5515   ld bc,0203dh
5518   inc b
5519   rst 10h
551A   sub b
551B   nop
551C   ret
