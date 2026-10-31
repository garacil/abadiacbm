; parch_restore_bottom_border at 535B (64K)   PC: 0900   CPC 6128: 6705   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
535B   ld a,(bc)
535C   rst 10h
535D   adc a,(hl)
535E   inc c
535F   ret
5360   rst 8
5361   adc a,(hl)
5362   inc b
5363   dec a
5364   jr nz,$+36
5366   rst 10h
5367   add a,(hl)
5368   inc b
5369   rst 8
536A   add a,a
536B   inc b
536C   dec a
536D   jr nz,$+26
536F   rst 8
5370   sbc a,l
5371   ld h,d
5372   inc a
5373   xor e
5374   ld h,020h
5376   inc bc
5377   jp 039a8h
537A   rst 10h
