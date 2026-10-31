; f_3568 at 3568 (64K)   PC: -   CPC 6128: -   called 8 times by 20C4
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3568 * ld a,00dh
356A * ld (000feh),a
356D * call f_3A83
3570 * ld bc,07f8dh
3573 * out (c),c
3575 * call f_3598
3578 * ld b,008h
357A * ld de,0c600h
357D * ld hl,08300h
3580 * push bc
3581 * ld bc,00200h
3584 * ldir
3586 * ex de,hl
3587 * ld bc,00600h
358A * add hl,bc
358B * ex de,hl
358C * pop bc
358D * djnz $-13
358F * call game_snapshot_initial_state
3592 * call f_35C3
3595 * jp vid_init_stub
