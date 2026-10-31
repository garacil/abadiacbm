; f_4404 at 4404 (64K)   PC: -   CPC 6128: -   called 275762 times by 43D8 43E5 43F2 43FF
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4404 * ld a,(ix+000h)
4407 * and c
4408 * ret nz
4409 * ld a,b
440A * bit 6,(ix+000h)
440E * jp nz,040d8h
4411 * bit 7,(ix+000h)
4415 * ret nz
4416 * set 7,(ix+000h)
441A * pop bc
441B * push de
441C * push bc
441D * ret
