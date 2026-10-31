; spr_flip_malachi at 2F00 (64K)   PC: 2FCD   CPC 6128: 34FB   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F00   ld a,(02babh)
2F03   xor 001h
2F05   ld (02babh),a
2F08   ld hl,(02be8h)
2F0B   ld bc,01405h
2F0E   jr $+73
