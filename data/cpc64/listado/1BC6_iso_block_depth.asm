; iso_block_depth at 1BC6 (64K)   PC: 287D   CPC 6128: 1FB8   called 4703 times by 17FD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1BC6 * cp 0ffh
1BC8 * ret z
1BC9 * srl a
1BCB * add a,h
1BCC * ld d,a
1BCD * add a,l
1BCE * sub 00fh
1BD0 * ld e,a
1BD1 * ld a,010h
1BD3 * add a,d
1BD4 * sub l
1BD5 * ld d,a
1BD6 * ld (01bech),de
1BDA * ret
1BDB   nop
1BDC   nop
1BDD   nop
1BDE   nop
1BDF   nop
1BE0   nop
1BE1   nop
1BE2   nop
1BE3   nop
1BE4   nop
1BE5   nop
1BE6   nop
1BE7   nop
1BE8   nop
1BE9   nop
1BEA   nop
1BEB   nop
1BEC   nop
1BED   nop
1BEE   ld b,b
1BEF   inc e
1BF0   sbc a,a
1BF1   inc e
1BF2   xor h
1BF3   inc e
1BF4   defb 0ddh,01ch,0e1h	;illegal sequence
1BF7   inc e
1BF8   push hl
1BF9   inc e
1BFA   push af
1BFB   inc e
1BFC   inc bc
1BFD   dec e
1BFE   ld c,a
1BFF   dec e
1C00   ld e,l
1C01   inc e
1C02   ld h,b
1C03   inc e
1C04   ld h,e
1C05   inc e
1C06   ld h,(hl)
1C07   inc e
1C08   ld l,c
1C09   inc e
1C0A   ld (hl),h
1C0B   inc e
1C0C   add a,l
1C0D   inc e
1C0E   ld a,a
1C0F   inc e
1C10   sub c
1C11   inc e
1C12   adc a,e
1C13   inc e
1C14   jp nz,0fc1dh
1C17   inc e
1C18   xor a
1C19   dec e
1C1A   sbc a,e
1C1B   dec e
1C1C   sbc a,e
1C1D   dec e
1C1E   sbc a,e
1C1F   dec e
1C20   sbc a,e
1C21   dec e
1C22   sbc a,e
1C23   dec e
1C24   cp b
1C25   dec e
1C26 * ex (sp),ix
1C28 * ld (01be9h),bc
1C2C * ld a,(ix+000h)
1C2F * inc ix
1C31 * cpl
1C32 * add a,a
1C33 * push hl
1C34 * ld hl,01beeh
1C37 * call util_add_bx_al
1C3A * ld e,(hl)
1C3B * inc hl
1C3C * ld d,(hl)
1C3D * pop hl
1C3E * push de
1C3F * ret
