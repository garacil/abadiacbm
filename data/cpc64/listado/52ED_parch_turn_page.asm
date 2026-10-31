; parch_turn_page at 52ED (64K)   PC: 0860   CPC 6128: 6697   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
52ED   dec a
52EE   jr nz,$+20
52F0   rst 10h
52F1   add a,(hl)
52F2   ld b,b
52F3   cp 0cfh
52F5   add a,a
52F6   ld b,b
52F7   cp 03dh
52F9   jr nz,$+8
52FB   rst 10h
52FC   adc a,h
52FD   dec bc
52FE   rst 10h
52FF   adc a,(hl)
5300   ld b,0c9h
5302   rst 8
5303   adc a,(hl)
5304   nop
5305   dec a
5306   jr nz,$+20
5308   rst 10h
5309   cp d
530A   ld (bc),a
530B   rst 10h
530C   add a,(hl)
530D   ld b,0cfh
530F   add a,a
5310   ld b,03dh
5312   jr nz,$+7
5314   rst 10h
5315   adc a,(hl)
5316   ld (bc),a
5317   jr $+3
5319   ret
531A   rst 8
531B   adc a,(hl)
531C   inc b
531D   inc a
531E   jr nz,$+66
5320   rst 8
5321   add a,d
5322   inc c
5323   ld a,020h
5325   ld b,0d7h
5327   add a,(hl)
5328   ld b,b
5329   rst 38h
532A   jr $+6
532C   rst 10h
532D   adc a,(hl)
532E   inc b
532F   ret
5330   rst 8
5331   adc a,(hl)
5332   ld (bc),a
5333   dec a
5334   jr nz,$+18
5336   call ai_guillermo_is_close
5339   jr nz,$+12
533B   call f_4B71
533E   add hl,bc
533F   rst 10h
5340   adc a,(hl)
5341   inc bc
5342   rst 10h
5343   adc a,a
5344   nop
5345   ret
5346   rst 8
5347   adc a,(hl)
5348   inc bc
5349   dec a
534A   jr nz,$+22
534C   rst 10h
534D   adc a,a
534E   adc a,a
534F   ld bc,0cf2bh
5352   adc a,a
5353   ld b,b
5354   jp m,0203eh
5357   rlca
5358   call f_4B71
