; chr_fill_height_buffer at 2873 (64K)   PC: 27E9   CPC 6128: 2D22   called 6279 times by 0836 201A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2873 * ld hl,(028dbh)
2876 * ld d,h
2877 * ld e,l
2878 * inc de
2879 * ld bc,0023fh
287C * ld (hl),000h
287E * ldir
2880 * call iso_grid_set_origin
2883 * and a
2884 * ld hl,07b98h
2887 * jr z,$+12
2889 * ld hl,09e40h
288C * cp 00bh
288E * jr z,$+5
2890   ld hl,09f60h
2893 * ld (03454h),hl
2896 * jp chr_hbuf_fill_room
