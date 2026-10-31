; obj_object_sprite_update at 0A2B (64K)   PC: 126E   CPC 6128: 0DBB   called 10 times by 09B9
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0A2B * bit 7,(iy+000h)
0A2F * ret nz
0A30 * set 7,c
0A32 * ld (ix+000h),c
0A35 * ld a,h
0A36 * sub 008h
0A38 * ld (ix+002h),a
0A3B * ld a,l
0A3C * sub 002h
0A3E * ld (ix+001h),a
0A41 * ret
