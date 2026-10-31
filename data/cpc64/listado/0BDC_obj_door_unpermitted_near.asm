; obj_door_unpermitted_near at 0BDC (64K)   PC: 146D   CPC 6128: 0F6C   called 269600 times by 0B3E 0B49
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0BDC * or (hl)
0BDD * inc hl
0BDE * and c
0BDF * ret nz
0BE0 * call util_read_indirect_pair
0BE3 * sub e
0BE4 * cp 006h
0BE6 * ret nc
0BE7 * ld a,b
0BE8 * sub d
0BE9 * cp 006h
0BEB * ret
