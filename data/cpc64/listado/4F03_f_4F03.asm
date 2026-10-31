; f_4F03 at 4F03 (64K)   PC: -   CPC 6128: -   called 53920 times by 4EF5
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4F03 * ld (04fd9h),hl
4F06 * ld l,0feh
4F08 * ld a,(022feh)
4F0B * cp 01ch
4F0D * ret nz
4F0E   ld a,(022f2h)
4F11   cp 05ch
4F13   ret nz
4F14   ld a,(bc)
4F15   ld (04fa9h),a
4F18   inc bc
4F19   ld (04f9ah),bc
4F1D   ld (04fa2h),bc
4F21   inc bc
4F22   inc bc
4F23   ld (04f9eh),bc
4F27   ld (04fa6h),bc
4F2B   ld a,(iy+004h)
4F2E   call iso_floor_base
4F31   sub b
4F32   cp 008h
4F34   ret nc
4F35   ld a,b
4F36   cp 016h
4F38   ret nz
4F39   ld a,(iy+002h)
4F3C   ld b,a
4F3D   sub 020h
4F3F   ret c
4F40   cp 00ah
4F42   ret nc
4F43   ld a,(iy+003h)
4F46   sub 062h
4F48   ret c
4F49   cp 00ah
4F4B   ret nc
4F4C   ld c,(iy+001h)
4F4F   ld a,(iy+000h)
4F52   push af
4F53   xor 002h
4F55   ld (iy+000h),a
4F58   push bc
4F59   ld a,b
4F5A   sub 021h
4F5C   neg
4F5E   add a,021h
4F60   ld (iy+002h),a
4F63   ld a,c
4F64   bit 0,a
4F66   jr nz,$+4
4F68   xor 002h
4F6A   ld (iy+001h),a
4F6D   bit 7,(iy+005h)
4F71   jr z,$+5
4F73   dec (iy+002h)
4F76   ld hl,04fc9h
4F79   ld (025aeh),hl
4F7C   ld (025d9h),de
4F80   set 7,(ix+00bh)
4F84   ld a,(ix+000h)
4F87   push af
4F88   call chr_animate
4F8B   pop af
4F8C   ld l,(ix+001h)
4F8F   ld h,(ix+002h)
4F92   ld e,(ix+005h)
4F95   ld d,(ix+006h)
4F98   exx
4F99   ld hl,(028deh)
4F9C   ld de,(028e0h)
4FA0   exx
4FA1   ld (028deh),hl
4FA4   ld (028e0h),de
4FA8   ld a,000h
4FAA   cp 0feh
4FAC   jr z,$+3
4FAE   exx
4FAF   ld (ix+003h),l
4FB2   ld (ix+004h),h
4FB5   ld (ix+009h),e
4FB8   ld (ix+00ah),d
4FBB   pop bc
4FBC   ld (iy+002h),b
4FBF   ld (iy+001h),c
4FC2   pop af
4FC3   ld (iy+000h),a
4FC6   ld l,000h
4FC8   ret
4FC9   ld l,(ix+005h)
4FCC   ld h,(ix+006h)
4FCF   push hl
4FD0   ld a,h
4FD1   ld h,000h
4FD3   call f_48EB
4FD6   ld b,d
4FD7   ld c,e
4FD8   ld de,085c0h
4FDB   push de
4FDC   ld l,(ix+007h)
4FDF   ld h,(ix+008h)
4FE2   ld (ix+007h),e
4FE5   ld (ix+008h),d
4FE8   ldir
4FEA   pop hl
4FEB   pop bc
4FEC   jp spr_flip_graphics_h
