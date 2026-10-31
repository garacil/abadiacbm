; parch_draw_vborder at 5284 (64K)   PC: 07A8   CPC 6128: 662E   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5284   and h
5285   ld b,b
5286   jr nz,$+44
5288   ld b,b
5289   jr nz,$+63
528B   jr nz,$+8
528D   rst 10h
528E   cp a
528F   cp a
5290   ld b,b
5291   add a,b
5292   ld h,0cfh
