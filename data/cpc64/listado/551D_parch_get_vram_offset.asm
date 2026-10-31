; parch_get_vram_offset at 551D (64K)   PC: 0A7F   CPC 6128: 68C7   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
551D * rst 8
551E   adc a,l
551F   dec b
5520   dec a
5521 * jr nz,$+17
5523   rst 8
5524   sub c
5525   inc b
5526   dec a
5527   jr nz,$+8
5529   rst 10h
552A   xor e
552B   ld bc,09dd7h
552E   nop
552F   rst 10h
5530   sub b
5531   inc b
5532 * rst 8
5533   adc a,b
5534   ld b,03dh
5536 * jr nz,$+6
5538   rst 10h
5539   sub b
553A   inc bc
553B   ret
553C * rst 8
553D   adc a,b
553E   nop
553F   dec a
5540 * jp nz,0558ah
5543   rst 8
5544   adc a,l
5545   inc bc
5546   dec a
5547   jp nz,05586h
554A   rst 8
554B   sub d
554C   ld b,03dh
554E   jr nz,$+43
5550   rst 10h
5551   or b
5552   ld b,b
5553   add a,b
5554   rst 8
5555   sub c
5556   inc bc
5557   dec a
5558   jr nz,$+6
555A   rst 10h
555B   sub b
