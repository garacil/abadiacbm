; iso_grid_cell_ptr at 0944 (64K)   PC: 116D   CPC 6128: 0CD4   called 1456787 times by 3F95 3FA1 400E 403C 4E04
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0944   ld a,l
0945   ld l,h
0946   ld h,000h
0948   add hl,hl
0949   add hl,hl
094A   add hl,hl
094B   ld d,h
094C   add a,l
094D   ld e,a
094E   add hl,hl
094F   add hl,de
0950   ld ix,(028dbh)
0954   ex de,hl
0955   add ix,de
0957   and a
0958   ret
