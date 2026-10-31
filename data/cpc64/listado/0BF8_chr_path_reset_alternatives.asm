; chr_path_reset_alternatives at 0BF8 (64K)   PC: 1498   CPC 6128: 0F88   called 3215 times by 075D
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0BF8 * ld de,00203h
0BFB * ld (00213h),de
0BFF * inc de
0C00 * inc de
0C01 * inc de
0C02 * ld a,0ffh
0C04 * ld (de),a
0C05 * ret
0C06   nop
0C07   nop
0C08   ld bc,00000h
0C0B   nop
0C0C   nop
0C0D   nop
0C0E   ex af,af'
0C0F   add hl,bc
0C10   ld (hl),080h
0C12   nop
0C13   nop
0C14   nop
0C15   nop
0C16   nop
0C17   nop
0C18   nop
0C19   nop
0C1A   ld bc,00000h
0C1D   nop
0C1E   nop
0C1F   nop
0C20   nop
0C21   nop
0C22   nop
0C23   nop
0C24   nop
0C25   ld (bc),a
0C26   add hl,bc
0C27   ld (de),a
0C28   ld (hl),080h
0C2A   nop
0C2B   nop
0C2C   nop
0C2D   nop
0C2E   nop
0C2F   nop
0C30   nop
0C31   nop
0C32   nop
0C33   nop
0C34   nop
0C35   nop
0C36   nop
0C37   nop
0C38   nop
0C39   nop
0C3A   nop
0C3B   nop
0C3C   nop
0C3D   inc b
0C3E   ld a,(bc)
0C3F   inc h
0C40   ld (hl),080h
0C42   nop
0C43   nop
0C44   nop
0C45   nop
0C46   nop
0C47   nop
0C48   nop
0C49   nop
0C4A   nop
0C4B   nop
0C4C   nop
0C4D   nop
0C4E   nop
0C4F   cp 03ch
0C51   jp z,03633h
0C54   cp 0eeh
0C56   ld c,018h
0C58   ld c,04dh
0C5A   dec c
0C5B   adc a,(hl)
0C5C   inc c
0C5D   jp c,02f0bh
0C60   dec bc
0C61   adc a,a
0C62   ld a,(bc)
0C63   rst 30h
0C64   add hl,bc
0C65   ld l,b
0C66   add hl,bc
0C67   pop hl
0C68   ex af,af'
0C69   ld h,c
0C6A   ex af,af'
0C6B   jp (hl)
0C6C   rlca
