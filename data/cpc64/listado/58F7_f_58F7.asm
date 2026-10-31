; f_58F7 at 58F7 (64K)   PC: -   CPC 6128: -   called 29100 times by 04F7
; '*' = executed in the exploration sessions; the listing runs to the next known entry
58F7 * rst 8
58F8   and h
58F9   djnz $+44
58FB   djnz $+63
58FD * jr nz,$+5
58FF   rst 10h
5900   or e
5901   nop
5902 * rst 8
5903   or h
5904   ld bc,0203dh
5907   inc b
5908   call f_4B7C
590B   daa
590C * rst 8
590D   or l
590E   ld bc,0203dh
5911   rlca
5912   rst 10h
5913   or l
5914   nop
5915   call f_4B71
5918   jr z,$-47
591A   or l
591B   ld (bc),a
591C   dec a
591D * jr nz,$+21
591F   rst 10h
5920   or l
5921   nop
5922   rst 10h
5923   or (hl)
5924   ld (0b7d7h),a
5927   nop
5928   call f_16A1
592B   call 03b3bh
592E   call f_4B71
5931   ld hl,(09ccfh)
5934   nop
5935   dec a
5936 * jr nz,$+76
5938 * rst 8
5939   or (hl)
593A   ld bc,0203eh
593D   jr nz,$-47
593F   add a,d
5940   ld b,b
5941   jr $+62
5943   jr nz,$+6
5945   rst 10h
5946   or (hl)
5947   nop
5948   ret
5949   rst 10h
594A   or (hl)
594B   or (hl)
594C   ld bc,0cf2dh
594F   or (hl)
5950   ld bc,0203dh
5953   ex af,af'
5954   rst 10h
5955   sbc a,h
5956   ld bc,071cdh
5959   ld c,e
595A   dec hl
595B   ret
595C   jr $+38
595E * rst 8
595F   add a,l
5960   ld b,b
5961   jr $+64
5963 * jr nz,$+25
5965   rst 10h
5966   sub (hl)
5967   ld b,b
5968   rst 38h
5969   rst 8
596A   cp b
596B   ld b,b
596C   add a,b
596D   ld hl,(00820h)
5970   call f_4B71
5973   inc de
5974   rst 10h
5975   or (hl)
5976   ld h,h
5977   ret
5978   rst 10h
5979   or a
597A   ld bc,0d7c9h
597D   or a
597E   nop
597F * rst 10h
5980   or (hl)
5981   nop
5982 * rst 8
5983   adc a,b
5984   inc bc
5985   dec a
5986 * jr nz,$+14
5988   rst 10h
5989   sub (hl)
598A   ld bc,0a3d7h
598D   rlca
598E   rst 10h
598F   and d
5990   inc c
5991   jp 05a3bh
5994 * rst 8
5995   adc a,b
5996   dec b
5997   dec a
5998   adc a,b
5999   ld bc,02a3dh
599C * jr nz,$+14
599E   rst 10h
599F   sub (hl)
59A0   nop
59A1   rst 10h
59A2   and e
59A3   ld bc,0a2d7h
59A6   dec bc
59A7   jp 05a3bh
59AA * rst 8
59AB   adc a,b
59AC   ld b,03dh
59AE * jr nz,$+9
59B0   rst 10h
59B1   sbc a,b
59B2   ld b,0d7h
59B4   sub (hl)
59B5   ld (bc),a
59B6   ret
59B7 * rst 8
59B8   adc a,b
59B9   nop
59BA   dec a
59BB * jp nz,05a36h
59BE   rst 8
59BF   sbc a,b
59C0   inc b
59C1   dec a
59C2   jr nz,$+66
59C4   rst 8
59C5   sbc a,d
59C6   scf
59C7   dec a
59C8   jr nz,$+5
59CA   rst 10h
59CB   sbc a,e
59CC   ld (bc),a
59CD   rst 8
59CE   adc a,c
59CF   nop
59D0   dec a
59D1   jr nz,$+50
59D3   rst 8
59D4   and c
59D5   ld h,h
59D6   ld a,020h
59D8   inc b
59D9   rst 10h
59DA   sbc a,e
59DB   ld (bc),a
59DC   ret
59DD   rst 10h
59DE   and c
59DF   and c
59E0   ld bc,0cd2bh
59E3   cp e
59E4   ld c,e
59E5   rst 8
59E6   and c
59E7   ld bc,0012ah
59EA   dec a
59EB   jr nz,$+24
59ED   ld a,03ch
59EF   call sys_key_down
59F2   jr nz,$+14
59F4   ld a,02eh
59F6   call sys_key_down
59F9   jr nz,$+3
59FB   ret
59FC   rst 10h
59FD   sbc a,b
59FE   dec b
59FF   ret
5A00   rst 10h
5A01   sbc a,e
5A02   ld (bc),a
5A03   ret
5A04   rst 10h
5A05   sub (hl)
5A06   ld b,b
5A07   rst 38h
5A08   rst 8
5A09   sbc a,b
5A0A   dec b
5A0B   dec a
5A0C   jr nz,$+13
5A0E   rst 8
5A0F   sbc a,d
5A10   ld b,b
5A11   ld a,03dh
5A13   jr nz,$+3
5A15   ret
5A16   rst 10h
5A17   sbc a,b
5A18   ld b,0cfh
5A1A   sbc a,b
5A1B   ld b,03dh
5A1D   jr nz,$+25
5A1F   call ai_guillermo_is_close
5A22   jr nz,$+19
5A24   rst 8
5A25   sbc a,d
5A26   ld b,b
5A27   ld a,03dh
5A29   jr nz,$+12
5A2B   rst 10h
5A2C   and c
5A2D   nop
5A2E   rst 10h
5A2F   sbc a,b
5A30   inc b
5A31   call f_4B7C
5A34   ld (de),a
5A35   ret
5A36 * rst 10h
5A37   sub (hl)
5A38   ld b,b
5A39   rst 38h
5A3A * ret
5A3B   rst 8
5A3C   sbc a,b
5A3D   and e
5A3E   dec a
5A3F   jr nz,$+3
5A41   ret
5A42   call ai_guillermo_is_close
5A45   jr nz,$+5
5A47   call 03a58h
5A4A   rst 10h
5A4B   sbc a,b
5A4C   and e
5A4D   ret
5A4E   ret
5A4F * rst 8
5A50   adc a,b
5A51   xor d
5A52   dec a
5A53 * jr nz,$+5
5A55 * ret
5A56   jr $+30
5A58 * rst 10h
5A59   xor d
5A5A   adc a,b
5A5B * call f_3D07
5A5E   nop
5A5F * rst 8
5A60   adc a,b
5A61 * call f_3A5D
5A64   ld (hl),l
5A65   ld e,d
5A66   sub c
5A67   ld e,d
5A68   jp po,0e95ah
5A6B   ld e,d
5A6C   call m,00f5ah
5A6F   ld e,e
5A70   inc de
5A71   ld e,e
5A72   nop
5A73   nop
5A74   ret
5A75   rst 8
5A76   adc a,l
5A77   dec b
5A78   dec a
5A79   jr nz,$+8
5A7B   call 03c70h
5A7E   call 03c52h
5A81   rst 8
5A82   adc a,l
5A83   ld b,03dh
5A85   jr nz,$+11
5A87   call 03c66h
5A8A   call 03bach
5A8D   rst 10h
5A8E   xor l
5A8F   nop
5A90   ret
5A91   call f_3AAF
5A94   rst 10h
5A95   sbc a,(hl)
5A96   ld b,b
5A97   rst 28h
5A98   call f_3A88
5A9B   call obj_open_left_wing_doors
5A9E   call snd_stub_event
5AA1   rst 8
5AA2   adc a,l
5AA3   inc bc
5AA4   ld a,020h
5AA6   ld b,0cdh
5AA8   dec sp
5AA9   dec sp
5AAA   call 03c3fh
5AAD   rst 8
5AAE   adc a,l
5AAF   ld (bc),a
5AB0   dec a
5AB1   jr nz,$+5
5AB3   call 03b7bh
5AB6   rst 8
5AB7   adc a,l
5AB8   inc bc
5AB9   dec a
5ABA   jr nz,$+26
5ABC   call 03c30h
5ABF   call 03bbch
5AC2   rst 10h
5AC3   xor b
5AC4   nop
5AC5   rst 10h
5AC6   and (hl)
5AC7   nop
5AC8   rst 8
5AC9   and h
5ACA   djnz $+44
5ACC   jr nz,$+8
5ACE   call 03c1ch
5AD1   rst 10h
5AD2   or e
5AD3   ld bc,08dcfh
5AD6   dec b
5AD7   dec a
5AD8   and h
5AD9   ex af,af'
5ADA   ld hl,(02026h)
5ADD   inc bc
5ADE   call 03c5ch
5AE1   ret
5AE2   call f_3AAF
5AE5   call snd_stub_bells
5AE8   ret
5AE9   call snd_stub_event
5AEC   rst 8
5AED   adc a,l
5AEE   inc b
5AEF   dec a
5AF0   jr nz,$+11
5AF2   call 03b9ch
5AF5   rst 10h
5AF6   xor e
5AF7   nop
5AF8   rst 10h
5AF9   or b
5AFA   djnz $-53
5AFC * call f_3AAF
5AFF * rst 8
5B00   adc a,l
5B01   inc bc
5B02   dec a
5B03 * jr nz,$+8
5B05   rst 10h
5B06   xor e
5B07   ld bc,09dd7h
5B0A   nop
5B0B * call snd_stub_bells
5B0E * ret
5B0F   call snd_stub_event
5B12   ret
5B13   call f_3AAF
5B16   call 03a8dh
5B19   rst 10h
5B1A   sbc a,(hl)
5B1B   ld b,b
5B1C   rst 18h
5B1D   call snd_stub_bells
5B20   ret
