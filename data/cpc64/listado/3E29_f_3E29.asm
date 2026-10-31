; f_3E29 at 3E29 (64K)   PC: -   CPC 6128: -   called 26973 times by 2197
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3E29 * ld a,(037e4h)
3E2C * and a
3E2D * ret z
3E2E * ld a,080h
3E30 * ld (037dch),a
3E33 * ld a,(028f2h)
3E36 * and a
3E37 * ret nz
3E38 * call f_16A1
3E3B * call f_3DA8
3E3E * ld hl,02010h
3E41 * ld (028e8h),hl
3E44 * call f_4B44
3E47   ld c,b
3E48   ld b,c
3E49   ld d,e
3E4A   jr nz,$+84
3E4C   ld b,l
3E4D   ld d,e
3E4E   ld d,l
3E4F   ld b,l
3E50   ld c,h
3E51   ld d,h
3E52   ld c,a
3E53   jr nz,$+71
3E55   ld c,h
3E56   rst 38h
3E57 * ld hl,0300eh
3E5A * ld (028e8h),hl
3E5D * call f_4B44
3E60   jr nz,$+50
3E62   jr nc,$+34
3E64   jr nz,$+82
3E66   ld c,a
3E67   ld d,d
3E68   jr nz,$+69
3E6A   ld c,c
3E6B   ld b,l
3E6C   ld c,(hl)
3E6D   ld d,h
3E6E   ld c,a
3E6F   rst 38h
3E70 * ld hl,0400ch
3E73 * ld (028e8h),hl
3E76 * call f_4B44
3E79   ld b,h
3E7A   ld b,l
3E7B   jr nz,$+78
3E7D   ld b,c
3E7E   jr nz,$+75
3E80   ld c,(hl)
3E81   ld d,(hl)
3E82   ld b,l
3E83   ld d,e
3E84   ld d,h
3E85   ld c,c
3E86   ld b,a
3E87   ld b,c
3E88   ld b,e
3E89   ld c,c
3E8A   ld c,a
3E8B   ld c,(hl)
3E8C   rst 38h
3E8D * ld hl,08006h
3E90 * ld (028e8h),hl
3E93 * ld a,(03e61h)
3E96 * cp 031h
3E98 * jr z,$+46
3E9A * call f_4B44
3E9D   ld d,b
3E9E   ld d,l
3E9F   ld c,h
3EA0   ld d,e
3EA1   ld b,c
3EA2   jr nz,$+71
3EA4   ld d,e
3EA5   ld d,b
3EA6   ld b,c
3EA7   ld b,e
3EA8   ld c,c
3EA9   ld c,a
3EAA   jr nz,$+82
3EAC   ld b,c
3EAD   ld d,d
3EAE   ld b,c
3EAF   jr nz,$+71
3EB1   ld c,l
3EB2   ld d,b
3EB3   ld b,l
3EB4   ld e,d
3EB5   ld b,c
3EB6   ld d,d
3EB7   rst 38h
3EB8 * call f_2D50
3EBB * ld a,02fh
3EBD * call sys_key_down
3EC0 * jr z,$-8
3EC2 * pop hl
3EC3 * jp 020c7h
3EC6   jp 03346h
3EC9   exx
3ECA   ld bc,0f8ffh
3ECD   out (c),c
3ECF   ld bc,07f89h
3ED2   out (c),c
3ED4   exx
3ED5   ex af,af'
3ED6   xor a
3ED7   ld (0b11ah),a
3EDA   ld (0b15fh),a
3EDD   ex af,af'
3EDE   call 00044h
3EE1   call 00800h
3EE4   ld c,0ffh
3EE6   pop hl
3EE7   jp 00077h
3EEA   rst 10h
3EEB   jr z,$-53
3EED   nop
3EEE   nop
3EEF   ld a,(03eeeh)
3EF2   and 00fh
3EF4   ld (03eeeh),a
3EF7   ret nz
3EF8   ld a,001h
3EFA   ld (03eedh),a
3EFD   ld a,(02ba9h)
3F00   inc a
3F01   ld (02ba9h),a
3F04   cp 014h
3F06   ret c
3F07   xor a
3F08   ld (02ba7h),a
3F0B   ld a,002h
3F0D   ld (037efh),a
3F10   xor a
3F11   ld (037f5h),a
3F14   ret
3F15   ld de,04b84h
3F18   call 03f2dh
3F1B   and a
3F1C   ret nz
3F1D   ld de,03080h
3F20   jr $+13
3F22   ld de,03938h
3F25   call 03f2dh
3F28   and a
3F29   ret nz
3F2A   ld de,03020h
3F2D   ld c,000h
3F2F   ld a,(02b8bh)
3F32   cp 00bh
3F34   jr nc,$+29
3F36   ld a,(02b89h)
3F39   xor e
3F3A   ld e,a
3F3B   ld a,(02b8ah)
3F3E   xor d
3F3F   or e
3F40   cp 010h
3F42   jr nc,$+15
3F44   ld c,002h
3F46   and a
3F47   jr nz,$+10
3F49   ld a,(02b88h)
3F4C   cp 001h
3F4E   jr nz,$+3
3F50   dec c
3F51   ld a,c
3F52   ld (037e8h),a
3F55   ret
