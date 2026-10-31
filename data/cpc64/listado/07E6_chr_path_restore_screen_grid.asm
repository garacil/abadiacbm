; chr_path_restore_screen_grid at 07E6 (64K)   PC: 0FF4   CPC 6128: 0B76   called 4033 times by 07D6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
07E6 * ld hl,0ae2eh
07E9 * ld (028dbh),hl
07EC * push iy
07EE * ld iy,028c4h
07F2 * call iso_grid_set_origin
07F5 * ld a,(iy+004h)
07F8 * ld (0290bh),a
07FB * pop iy
07FD * scf
07FE * ret
