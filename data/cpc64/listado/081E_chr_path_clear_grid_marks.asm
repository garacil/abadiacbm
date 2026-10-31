; chr_path_clear_grid_marks at 081E (64K)   PC: 102B   CPC 6128: 0BAE   called 28587 times by 05AB 07AB 07E0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
081E * ld bc,00240h
0821 * ld hl,(028dbh)
0824 * ld a,(hl)
0825 * and 03fh
0827 * ld (hl),a
0828 * inc hl
0829 * dec bc
082A * ld a,b
082B * or c
082C * jr nz,$-8
082E * ret
