; parch_draw_hborder at 5271 (64K)   PC: 078B   CPC 6128: 661B   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5271   dec a
5272   add a,b
5273   ld h,b
5274   inc a
5275   ld h,020h
5277   dec b
5278   rst 10h
5279   cp a
527A   cp a
527B   ld bc,0cf26h
527E   add a,d
527F   ld d,03eh
5281 * jr nz,$+39
5283   rst 8
