; spr_flip_adso at 2EE7 (64K)   PC: 2FB4   CPC 6128: 34E2   called 389 times by 25AD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2EE7 * ld a,(02b9ch)
2EEA * xor 001h
2EEC * ld (02b9ch),a
2EEF * ld hl,0a6eah
2EF2 * ld bc,05f05h
2EF5 * call spr_flip_graphics_h
2EF8 * ld hl,0a8c5h
2EFB * ld bc,05a04h
2EFE * jr $+89
