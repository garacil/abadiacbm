; chr_hbuf_skip_list at 35F8 (64K)   PC: 379D   CPC 6128: 3AC2   called 8 times by 35C6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
35F8 * ld a,(hl)
35F9 * cp 0ffh
35FB * ret z
35FC * bit 3,a
35FE * jr z,$+3
3600 * inc hl
3601 * inc hl
3602 * inc hl
3603 * inc hl
3604 * inc hl
3605 * jr $-13
