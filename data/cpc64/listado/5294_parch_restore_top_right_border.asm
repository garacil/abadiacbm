; parch_restore_top_right_border at 5294 (64K)   PC: 07C8   CPC 6128: 663E   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5294   cp b
5295   ld b,b
5296   add a,b
5297   ld hl,(08040h)
529A   dec a
529B   jr nz,$+8
529D   rst 10h
529E   cp a
529F   cp a
52A0   ld b,b
52A1   jr nz,$+40
52A3   rst 10h
52A4   cp a
52A5   cp a
52A6   djnz $+40
52A8 * rst 8
52A9   sbc a,d
52AA   ld (hl),d
52AB   dec a
52AC * jr nz,$+7
52AE   rst 10h
52AF   ret nz
52B0   ret nz
52B1   ld (bc),a
52B2   ld h,0c9h
