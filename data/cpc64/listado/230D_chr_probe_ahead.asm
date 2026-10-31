; chr_probe_ahead at 230D (64K)   PC: 21DC   CPC 6128: 27B8   called 66731 times by 243E 27FB 41C2 4268
; '*' = executed in the exploration sessions; the listing runs to the next known entry
230D * ld e,a
230E * ld a,(iy+004h)
2311 * call iso_floor_base
2314 * ld a,(0290bh)
2317 * cp b
2318 * scf
2319 * ld a,e
231A * ret nz
231B * ld a,(iy+004h)
231E * sub b
231F * ld b,e
