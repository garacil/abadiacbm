; f_3B66 at 3B66 (64K)   PC: -   CPC 6128: -   called 23628 times by 53F8
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3B66 * ld a,(0294eh)
3B69 * bit 1,a
3B6B * ret z
3B6C   and 0fdh
3B6E   ld (0294eh),a
3B71   call 03c84h
3B74   ld (hl),a
3B75   dec hl
3B76   nop
3B77   nop
3B78   dec (hl)
3B79   dec (hl)
3B7A   inc de
3B7B   ld a,(02940h)
3B7E   and 0dfh
3B80   ld (02940h),a
3B83   ld a,(0295ch)
3B86   and 0dfh
3B88   ld (0295ch),a
3B8B   push ix
3B8D   call f_4D2A
3B90   pop ix
3B92   call 03c84h
3B95   ld h,e
3B96   dec hl
3B97   nop
3B98   nop
3B99   nop
3B9A   nop
3B9B   nop
3B9C   ld hl,02bech
3B9F   ld de,0b293h
3BA2   call 03be6h
3BA5   call nz,0002bh
3BA8   adc a,b
3BA9   adc a,b
3BAA   ld (bc),a
3BAB   nop
3BAC   ld hl,02beeh
3BAF   ld de,0b2f7h
3BB2   call 03be6h
3BB5   out (02bh),a
3BB7   inc bc
3BB8   ld (de),a
3BB9   ld h,l
3BBA   jr $+2
3BBC   ld hl,(02bcfh)
3BBF   ld (hl),010h
3BC1   xor a
3BC2   ld (02bcdh),a
3BC5   ld (02bceh),a
3BC8   ld hl,02bech
3BCB   ld de,0b2f7h
3BCE   call 03be6h
3BD1   call nz,0002bh
3BD4   ret z
3BD5   inc h
3BD6   nop
3BD7   nop
3BD8   call spr_unflip_monk_faces
3BDB   ld hl,02bech
3BDE   ld de,0b35bh
3BE1   ld (hl),e
3BE2   inc hl
3BE3   ld (hl),d
3BE4   inc hl
3BE5   ret
3BE6   push hl
3BE7   push de
3BE8   call spr_unflip_monk_faces
3BEB   pop de
3BEC   pop hl
3BED   call 03be1h
3BF0   jp 03c84h
3BF3   push ix
3BF5   push iy
3BF7   ld ix,02960h
3BFB   jr $+20
3BFD   ld a,(02955h)
3C00   and 010h
3C02   ret z
3C03   xor a
3C04   ld (02957h),a
3C07   push ix
3C09   push iy
3C0B   ld ix,02952h
3C0F   call 04dcdh
3C12   pop iy
3C14   pop ix
3C16   xor a
3C17   ld (037e0h),a
3C1A   ret
3C1B   ret
3C1C   call 03c84h
3C1F   ld l,b
3C20   dec hl
3C21   nop
3C22   nop
3C23   jr $+102
3C25   jr $-49
3C27   add a,h
3C28   inc a
3C29   ld l,b
3C2A   dec hl
3C2B   nop
3C2C   nop
3C2D   ld e,b
3C2E   inc a
3C2F   ld (bc),a
3C30   ld a,080h
3C32   ld (02963h),a
3C35   call 03c84h
3C38   ld e,c
3C39   dec hl
3C3A   add a,b
3C3B   nop
3C3C   ld h,b
3C3D   add hl,hl
3C3E   nop
3C3F   ld a,(037deh)
3C42   and a
3C43   ret nz
3C44   inc a
3C45   ld (037deh),a
3C48   call 03c84h
3C4B   add a,c
3C4C   dec hl
3C4D   nop
3C4E   nop
3C4F   ld e,d
3C50   ld hl,(0cd04h)
3C53   add a,h
3C54   inc a
3C55   ld l,l
3C56   dec hl
3C57   nop
3C58   nop
3C59   adc a,c
3C5A   ld a,008h
3C5C   call 03c84h
3C5F   ld l,l
3C60   dec hl
3C61   nop
3C62   nop
3C63   nop
3C64   nop
3C65   nop
3C66   call 03c84h
3C69   ld (hl),d
3C6A   dec hl
3C6B   nop
3C6C   nop
3C6D   dec (hl)
3C6E   dec (hl)
3C6F   inc de
3C70   call 03c84h
3C73   ld h,e
3C74   dec hl
3C75   nop
3C76   nop
3C77   dec de
3C78   inc hl
3C79   jr $-49
3C7B   add a,h
3C7C   inc a
3C7D   ld l,l
3C7E   dec hl
3C7F   nop
3C80   nop
3C81   nop
3C82   nop
3C83   nop
3C84   pop hl
3C85   ld e,(hl)
3C86   inc hl
3C87   ld d,(hl)
3C88   inc hl
3C89   ld bc,00005h
3C8C   ldir
3C8E   ret
