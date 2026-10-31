; spr_draw_or_darken at 2236 (64K)   PC: 2069   CPC 6128: 2674   called 26960 times by 21E9
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2236 * ld a,(011dch)
2239 * and a
223A * jp z,0447dh
223D   ld hl,02968h
2240   ld de,00014h
2243   ld a,(hl)
2244   cp 0ffh
2246   jr z,$+11
2248   cp 0feh
224A   jr z,$+4
224C   res 7,(hl)
224E   add hl,de
224F   jr $-12
2251   ld a,(0297ch)
2254   cp 0feh
2256   ret z
2257   ld a,(02944h)
225A   and 080h
225C   ret z
225D   ld a,0bch
225F   ld (02b20h),a
2262   jp 0447dh
