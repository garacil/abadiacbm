; chr_think_or_step at 249A (64K)   PC: 2370   CPC 6128: 2945   called 163900 times by 2492
; '*' = executed in the exploration sessions; the listing runs to the next known entry
249A * jp nz,chr_animate
249D * ld a,(iy+000h)
24A0 * and 001h
24A2 * jp nz,02556h
24A5 * ld hl,023e2h
24A8 * jp (hl)
