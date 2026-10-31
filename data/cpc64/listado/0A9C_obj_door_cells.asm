; obj_door_cells at 0A9C (64K)   PC: 12F5   CPC 6128: 0E2C   called 46694 times by 0A89 0B98
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0A9C * ex af,af'
0A9D * ld a,(iy+000h)
0AA0 * and 003h
0AA2 * ld hl,00ab4h
0AA5 * add a,a
0AA6 * call util_add_bx_al
0AA9 * ld c,(hl)
0AAA * inc hl
0AAB * ld b,(hl)
0AAC * push de
0AAD * push bc
0AAE * call iso_grid_cell_of
0AB1 * pop bc
0AB2 * pop de
0AB3 * ret
0AB4   ld bc,0e800h
0AB7   rst 38h
0AB8   rst 38h
0AB9   rst 38h
0ABA   jr $+2
