; parch_delay at 541C (64K)   PC: 0A26   CPC 6128: 67C6   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
541C   xor (hl)
541D   xor (hl)
541E   ld b,b
541F   add a,b
5420   ld h,0cdh
5422   ld (hl),c
5423   ld c,e
5424   inc sp
5425   jr $+47
5427   rst 8
5428   xor (hl)
5429   ld b,b
542A   ld b,b
542B   ld hl,(01520h)
542E   rst 8
542F   adc a,l
5430   ld (bc),a
5431   dec a
5432   adc a,c
5433   ld h,020h
5435   dec bc
5436   rst 10h
5437   xor (hl)
5438   xor (hl)
5439   ld b,b
543A   ld b,b
543B   ld h,0cdh
543D   ld a,h
543E   ld c,e
543F   inc (hl)
5440   ret
5441   jr $+19
5443   rst 8
5444   xor (hl)
5445   djnz $+44
5447   jr nz,$+13
5449   call ai_guillermo_is_close
544C   jr nz,$+3
544E   ret
544F   rst 10h
5450   xor (hl)
5451   xor (hl)
5452   djnz $+40
5454   ret
5455   call chr_cmd_discard
5458   xor a
5459   call sys_key_down
545C   jr nz,$+5
545E   jp 039a8h
5461   rst 10h
5462   add a,(hl)
5463   inc bc
5464   ret
5465 * rst 10h
5466   add a,(hl)
5467   ld (bc),a
5468 * ret
5469   rst 8
546A   adc a,b
546B   ld (bc),a
546C   dec a
546D   jr nz,$+39
546F   rst 8
5470   adc a,(hl)
5471   add hl,bc
5472   dec a
5473   adc a,l
5474   dec b
5475   dec a
5476   ld h,020h
5478   inc d
5479   rst 10h
547A   add a,(hl)
547B   ex af,af'
547C   rst 8
547D   add a,a
547E   ex af,af'
547F   dec a
5480   sub h
5481   ld (bc),a
5482   dec a
5483   ld h,020h
5485   ld b,0d7h
5487   xor l
5488   ld bc,08ed7h
548B   ld a,(bc)
548C   ret
548D   rst 10h
548E   adc a,(hl)
548F   ld a,(bc)
5490   rst 10h
5491   add a,(hl)
5492   ld (bc),a
5493   ret
5494   ret
