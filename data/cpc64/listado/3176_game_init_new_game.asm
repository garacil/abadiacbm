; game_init_new_game at 3176 (64K)   PC: 33BB   CPC 6128: 381E   called 21 times by 20DF
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3176 * ld hl,037d2h
3179 * ld bc,00020h
317C * call util_clear_bytes
317F * ld hl,028deh
3182 * ld bc,0004bh
3185 * call util_clear_bytes
3188 * ld hl,0316bh
318B * call game_for_each_state_block
318E * ld hl,02968h
3191 * ld de,00014h
3194 * ld a,(hl)
3195 * cp 0ffh
3197 * jr z,$+7
3199 * ld (hl),0feh
319B * add hl,de
319C * jr $-8
319E * ld ix,02b87h
31A2 * ld de,0000fh
31A5 * xor a
31A6 * ld b,006h
31A8 * ld (ix+000h),a
31AB * ld (ix+001h),001h
31AF * ld (ix+005h),a
31B2 * ld (ix+009h),a
31B5 * ld (ix+00ah),0fdh
31B9 * ld (ix+00bh),a
31BC * add ix,de
31BE * djnz $-22
31C0 * ret
31C1   push af
31C2   push bc
31C3   ld bc,00500h
31C6   call 04477h
31C9   pop bc
31CA   pop af
31CB   dec a
31CC   jr nz,$-11
31CE   ret
31CF   ld de,02c00h
31D2   ld hl,08bffh
31D5   ld a,02ah
31D7   call 032abh
31DA   call 06000h
31DD   jr $-3
