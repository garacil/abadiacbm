; f_4925 at 4925 (64K)   PC: -   CPC 6128: -   called 67499 times by 45B4 460F
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4925 * ld hl,(04972h)
4928 * ld (04975h),hl
492B * inc c
492C * inc b
492D * ld (04972h),bc
4931 * exx
4932 * ld de,(04690h)
4936 * exx
4937 * ld ix,(02be6h)
493B * ld bc,(02928h)
493F * srl b
4941 * srl b
4943 * srl b
4945 * srl c
4947 * srl c
4949 * xor a
494A * ld (04a2ch),a
494D * ld (04a48h),a
4950 * ld a,(02928h)
4953 * sub 004h
4955 * ld (04a28h),a
4958 * ld (04a44h),a
495B * push bc
495C * push ix
495E * exx
495F * push de
4960 * exx
4961 * ld b,c
4962 * ld c,002h
4964 * ld hl,0497fh
4967 * ld (0497dh),hl
496A * ld a,(ix+002h)
496D * and a
496E * jr z,$+73
4970 * exx
4971 * ld bc,00000h
4974 * ld hl,00000h
4977 * ld a,(ix+000h)
497A * bit 7,a
497C * jp nz,0497fh
497F * cp l
4980 * ld a,(ix+001h)
4983 * jr nc,$+7
4985 * cp h
4986 * jr nc,$+4
4988 * jr $+46
498A * cp b
498B * jr nc,$+43
498D * ld a,(ix+000h)
4990 * cp c
4991 * jr nc,$+37
4993 * bit 7,(ix+000h)
4997 * jr nz,$+31
4999 * ld hl,049aah
499C * ld (0497dh),hl
499F * push de
49A0 * call spr_tile_ptr_check
49A3 * pop de
49A4 * jr c,$+6
49A6 * set 7,(ix+000h)
49AA * push de
49AB * exx
49AC * push bc
49AD * ld a,(ix+002h)
49B0 * call f_49E5
49B3 * pop bc
49B4 * exx
49B5 * pop de
49B6 * exx
49B7 * call f_491B
49BA * inc ix
49BC * inc ix
49BE * inc ix
49C0 * dec c
49C1 * jr nz,$-87
49C3 * exx
49C4 * inc de
49C5 * inc de
49C6 * inc de
49C7 * inc de
49C8 * exx
49C9 * djnz $-103
49CB * exx
49CC * pop de
49CD * ld hl,(02928h)
49D0 * ld h,000h
49D2 * add hl,hl
49D3 * add hl,hl
49D4 * add hl,hl
49D5 * add hl,de
49D6 * ex de,hl
49D7 * exx
49D8 * pop ix
49DA * ld bc,00060h
49DD * add ix,bc
49DF * pop bc
49E0 * dec b
49E1 * jp nz,0495bh
49E4 * ret
