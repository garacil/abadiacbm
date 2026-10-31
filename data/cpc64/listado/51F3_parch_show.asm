; parch_show at 51F3 (64K)   PC: 06D7   CPC 6128: 659D   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
51F3   ld b,b
51F4   cp 03dh
51F6   ld hl,(00420h)
51F9   rst 10h
51FA   and a
51FB   inc b
51FC   ret
51FD * rst 8
51FE   adc a,b
51FF   inc bc
5200   dec a
5201   adc a,d
5202   ld (bc),a
5203   ld a,026h
