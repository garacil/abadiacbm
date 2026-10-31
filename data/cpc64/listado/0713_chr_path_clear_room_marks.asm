; chr_path_clear_room_marks at 0713 (64K)   PC: 0F02   CPC 6128: 0AA3   called 3583 times by 0740
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0713 * ld hl,0023dh
0716 * ld bc,00130h
0719 * ld a,(hl)
071A * and 03fh
071C * ld (hl),a
071D * inc hl
071E * dec bc
071F * ld a,b
0720 * or c
0721 * jr nz,$-8
0723 * ret
