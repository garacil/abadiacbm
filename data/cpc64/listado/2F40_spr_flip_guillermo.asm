; spr_flip_guillermo at 2F40 (64K)   PC: 3011   CPC 6128: 353B   called 130 times by 25AD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F40 * ld a,(02b8dh)
2F43 * xor 001h
2F45 * ld (02b8dh),a
2F48 * ld hl,0a300h
2F4B * ld bc,0ae05h
2F4E * call spr_flip_graphics_h
2F51 * ld hl,0a666h
2F54 * ld bc,02104h
