; f_571C at 571C (64K)   PC: -   CPC 6128: -   called 26960 times by 04CD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
571C * rst 8
571D   xor l
571E   ld bc,0203dh
5721   inc bc
5722   jp 039a8h
5725 * rst 8
5726   adc a,l
5727   ld b,03eh
5729 * jp nz,05806h
572C   rst 8
572D   sub l
572E   dec bc
572F   dec a
5730   jr nz,$+17
5732   rst 8
5733   adc a,c
5734   nop
5735   dec a
5736   jr nz,$+8
5738   call 03bf3h
573B   rst 10h
573C   sub l
573D   inc c
573E   jp 039a8h
5741   rst 8
5742   sub l
5743   inc c
5744   dec a
5745   jr nz,$+22
5747   rst 8
5748   and h
5749   ld b,b
574A   add a,b
574B   ld hl,(00320h)
574E   jp 039a8h
5751   call f_4B7C
5754   ld l,0d7h
5756   sub l
5757   dec c
5758   jp 039a8h
575B   rst 8
575C   sub l
575D   dec c
575E   dec a
575F   jr nz,$+51
5761   rst 8
5762   and h
5763   ld b,b
5764   ld b,b
5765   ld hl,(01a20h)
5768   rst 8
5769   sbc a,h
576A   nop
576B   dec a
576C   jr nz,$+19
576E   rst 8
576F   sbc a,d
5770   ld (hl),d
5771   dec a
5772   adc a,c
5773   ld hl,(00620h)
5776   rst 10h
5777   cp l
5778   ld b,b
5779   rst 38h
577A   jr $+5
577C   rst 10h
577D   cp l
577E   ld bc,0a8c3h
5781   add hl,sp
5782   rst 8
5783   adc a,c
5784   nop
5785   dec a
5786   jr nz,$+9
5788   call f_4B7C
578B   inc hl
578C   rst 10h
578D   sub l
578E   ld c,0c3h
5790   xor b
5791   add hl,sp
5792   rst 8
5793   sub l
5794   ld c,03dh
5796   jr nz,$+21
5798   rst 8
5799   adc a,c
579A   nop
579B   dec a
579C   jr nz,$+12
579E   rst 10h
579F   sbc a,c
57A0   nop
57A1   rst 10h
57A2   sub l
57A3   rrca
57A4   call f_4B7C
57A7   cpl
57A8   jp 039a8h
57AB   rst 8
57AC   sub l
57AD   rrca
57AE   dec a
57AF   jr nz,$+32
57B1   rst 10h
57B2   sbc a,c
57B3   sbc a,c
57B4   ld bc,0cf2bh
57B7   sbc a,c
57B8   jr z,$+63
57BA   jr nz,$+18
57BC   call f_16A1
57BF   rst 10h
57C0   sub e
57C1   inc b
57C2   call 03d87h
57C5   rst 10h
57C6   cp h
57C7   nop
57C8   rst 10h
57C9   sub l
57CA   djnz $-53
57CC   jp 039a8h
57CF   rst 8
57D0   sub l
57D1   djnz $+63
57D3   jr nz,$+30
57D5   rst 8
57D6   sub h
57D7   inc b
57D8   dec a
57D9   sbc a,d
57DA   ld h,a
57DB   dec a
57DC   ld h,082h
57DE   ld e,03ch
57E0   ld h,020h
57E2   dec c
57E3   rst 10h
57E4   cp c
57E5   nop
57E6   rst 10h
57E7   xor l
57E8   ld bc,071cdh
57EB   ld c,e
57EC   inc h
57ED   rst 10h
57EE   sbc a,h
57EF   ld bc,0cfc9h
57F2   sbc a,d
57F3   ld (hl),e
57F4   dec a
57F5   jr nz,$+14
57F7   rst 10h
57F8   ret nz
57F9   ret nz
57FA   ex af,af'
57FB   ld h,0cdh
57FD   ld (hl),c
57FE   ld c,e
57FF   ld hl,095d7h
5802   dec bc
5803   jp 039a8h
5806 * rst 8
5807   adc a,b
5808   nop
5809   dec a
580A   adc a,b
580B   ld b,03dh
580D   ld hl,(00720h)
5810   rst 10h
5811   sub h
5812   ld (bc),a
5813   rst 10h
5814   sub e
5815   ld (bc),a
5816   ret
5817 * rst 8
5818   adc a,b
5819   ld bc,0203dh
581C   ld (hl),0cfh
581E   adc a,c
581F   ld bc,0933eh
5822   ld b,b
5823   rst 38h
5824   dec a
5825   ld h,020h
5827   ld bc,0d7c9h
582A   sub e
582B   nop
582C   rst 8
582D   adc a,l
582E   dec b
582F   dec a
5830   or c
5831   nop
5832   dec a
5833   ld h,020h
5835   inc e
5836   rst 8
5837   add a,b
5838   ld h,b
5839   inc a
583A   jr nz,$+6
583C   rst 10h
583D   or c
583E   ld bc,0d7c9h
5841   sub e
5842   ld b,b
5843   rst 38h
5844   rst 8
5845   sub h
5846   ld b,b
5847   rst 38h
5848   dec a
5849   jr nz,$+9
584B   call f_4B71
584E   rrca
584F   rst 10h
5850   or c
5851   ld bc,0cfc9h
5854   adc a,b
5855   inc bc
5856   dec a
5857 * jr nz,$+6
5859   rst 10h
585A   sub e
585B   ld bc,0cfc9h
585E   adc a,b
585F   dec b
5860   inc a
5861 * jp nz,058f3h
5864 * rst 8
5865   xor (hl)
5866   ld (bc),a
5867   ld hl,(00294h)
586A   ld a,026h
586C   adc a,l
586D   ld (bc),a
586E   ld a,026h
5870   adc a,e
5871   ld b,b
5872   rst 38h
5873   inc a
5874   ld h,020h
5876   scf
5877   rst 8
5878   xor (hl)
5879   inc b
587A   ld hl,(02689h)
587D   jr nz,$+19
587F   call ai_guillermo_is_close
5882   jr nz,$+14
5884   rst 10h
5885   xor (hl)
5886   inc b
5887   rst 10h
5888   sub e
5889   ld b,b
588A   rst 38h
588B   call f_4B7C
588E   scf
588F   ret
5890   rst 8
5891   xor (hl)
5892   inc b
5893   ld hl,(03d04h)
5896   jr nz,$+24
5898   rst 10h
5899   sub e
589A   ld b,b
589B   rst 38h
589C   rst 8
589D   adc a,c
589E   nop
589F   dec a
58A0   jr nz,$+13
58A2   rst 10h
58A3   sub e
58A4   ld (bc),a
58A5   rst 10h
58A6   sub h
58A7   inc bc
58A8   rst 10h
58A9   xor (hl)
58AA   xor (hl)
58AB   ld (bc),a
58AC   ld h,0c9h
58AE * rst 8
58AF   sub h
58B0   ld b,b
58B1   rst 38h
58B2   dec a
58B3 * jr nz,$+16
58B5   rst 8
58B6   adc a,c
58B7   nop
58B8   dec a
58B9   jr nz,$+9
58BB   call f_4B7C
58BE   ld h,0d7h
58C0   sbc a,e
58C1   ld bc,0cfc9h
58C4   sub h
58C5   ld (bc),a
58C6   dec a
58C7 * jr nz,$+40
58C9 * rst 8
58CA   adc a,l
58CB   dec b
58CC   dec a
58CD * jr nz,$+5
58CF   jp 039a8h
58D2 * rst 8
58D3   adc a,b
58D4   ld (bc),a
58D5   dec a
58D6   adc a,l
58D7   inc b
58D8   dec a
58D9   ld h,020h
58DB   ld c,0d7h
58DD   sub e
58DE   ld b,b
58DF   rst 38h
58E0   call ai_guillermo_is_close
58E3   jr nz,$+6
58E5   call f_4B7C
58E8   inc l
58E9   ret
58EA * rst 10h
58EB   sub e
58EC   inc bc
58ED * jr $+5
58EF * rst 10h
58F0   sub e
58F1   ld (bc),a
58F2 * ret
58F3   rst 10h
58F4   sub e
58F5   nop
58F6   ret
