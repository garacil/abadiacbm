; f_3D3C at 3D3C (64K)   PC: -   CPC 6128: -   called 26973 times by 5112
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3D3C * ld a,(037dah)
3D3F * ld c,a
3D40 * ld a,(02944h)
3D43 * and 080h
3D45 * ret z
3D46   ld a,(037d8h)
3D49   and a
3D4A   ret z
3D4B   ld a,(011dch)
3D4E   and a
3D4F   ret z
3D50   ld hl,(037d4h)
3D53   inc hl
3D54   ld (037d4h),hl
3D57   ld a,l
3D58   and a
3D59   ret nz
3D5A   ld a,c
3D5B   and a
3D5C   ret nz
3D5D   ld a,h
3D5E   ld c,001h
3D60   cp 003h
3D62   ret z
3D63   inc c
3D64   cp 006h
3D66   ret z
3D67   ld c,000h
3D69   ret
