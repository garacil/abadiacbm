; snd_stub_psg_write at 0FBE (64K)   PC: 63A2   CPC 6128: 134E   called 1544120 times by 0D36 0D56 0D60 0D71
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0FBE * ld b,0f4h
0FC0 * out (c),a
0FC2 * ld b,0f6h
0FC4 * in a,(c)
0FC6 * or 0c0h
0FC8 * out (c),a
0FCA * and 03fh
0FCC * out (c),a
0FCE * ld b,0f4h
0FD0 * out (c),c
0FD2 * ld b,0f6h
0FD4 * ld c,a
0FD5 * or 080h
0FD7 * out (c),a
0FD9 * out (c),c
0FDB * ret
