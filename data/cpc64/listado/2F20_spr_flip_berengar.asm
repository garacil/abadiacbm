; spr_flip_berengar at 2F20 (64K)   PC: 2FEF   CPC 6128: 351B   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F20   ld a,(02bc9h)
2F23   xor 001h
2F25   ld (02bc9h),a
2F28   ld hl,(02bech)
2F2B   ld bc,01405h
2F2E   jr $+41
