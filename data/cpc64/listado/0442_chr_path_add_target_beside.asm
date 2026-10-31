; chr_path_add_target_beside at 0442 (64K)   PC: 0BC5   CPC 6128: 07D2   called 193257 times by 0436 043A 043E
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0442 * ld hl,00215h
0445 * ld a,b
0446 * and 003h
0448 * ld b,a
0449 * add a,a
044A * call util_add_bx_al
044D * ld a,b
044E * rrca
044F * rrca
0450 * xor 080h
0452 * and 0c0h
0454 * or (ix+004h)
0457 * ld c,a
0458 * ld a,(ix+004h)
045B * ld (iy+004h),a
045E * ld a,(ix+002h)
0461 * add a,(hl)
0462 * inc hl
0463 * ld (iy+002h),a
0466 * ld a,(ix+003h)
0469 * add a,(hl)
046A * ld (iy+003h),a
046D * push ix
046F * push bc
0470 * call iso_grid_cell_of
0473 * pop bc
0474 * ld (iy+004h),c
0477 * ld a,(ix+000h)
047A * pop ix
047C * jr c,$+25
047E * and 0efh
0480 * push bc
0481 * ld c,a
0482 * ld a,(ix+004h)
0485 * call iso_floor_base
0488 * sub b
0489 * sub c
048A * inc a
048B * cp 006h
048D * pop bc
048E * jr c,$+7
0490 * ld (iy+002h),0ffh
0494 * ret
0495 * inc iy
0497 * inc iy
0499 * inc iy
049B * ld (iy+002h),0ffh
049F * ret
