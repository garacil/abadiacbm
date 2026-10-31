; spr_unflip_monk_faces at 304F (64K)   PC: 3283   CPC 6128: 36C4   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
304F   push iy
3051   ld iy,02ba5h
3055   ld hl,02be8h
3058   ld b,004h
305A   push bc
305B   ld e,(hl)
305C   inc hl
305D   ld d,(hl)
305E   inc hl
305F   push hl
3060   ld a,(iy+006h)
3063   and a
3064   jr z,$+13
3066   ld (iy+006h),000h
306A   ex de,hl
306B   ld bc,01405h
306E   call spr_flip_graphics_h
3071   pop hl
3072   ld bc,0000fh
3075   add iy,bc
3077   pop bc
3078   djnz $-30
307A   pop iy
307C   ret
307D   ld hl,07f80h
3080   ld de,028d0h
3083   ld bc,00338h
3086   ret
