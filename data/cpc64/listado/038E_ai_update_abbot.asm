; ai_update_abbot at 038E (64K)   PC: 0B04   CPC 6128: 071E   called 26960 times by 222C
; '*' = executed in the exploration sessions; the listing runs to the next known entry
038E * ld iy,02bb4h
0392 * ld ix,03816h
0396 * xor a
0397 * ld (037e9h),a
039A * call f_5B21
039D * ld c,03fh
039F * call f_39F1
03A2 * ld hl,02721h
03A5 * call chr_update
03A8 * ld ix,03816h
03AC * bit 7,(iy+009h)
03B0 * jp z,ai_check_planned_move
03B3 * ld a,(037e9h)
03B6 * and a
03B7 * ret nz
03B8 * push ix
03BA * ld a,(ix-001h)
03BD * cp 0ffh
03BF * jr z,$+79
03C1 * cp 0feh
03C3 * jr z,$+70
03C5 * cp 0fdh
03C7 * jr z,$+61
03C9 * cp 0fch
03CB * jr z,$+52
03CD * ld c,a
03CE * add a,a
03CF * add a,c
03D0 * ld c,a
03D1 * ld b,000h
03D3 * add ix,bc
03D5 * push ix
03D7 * pop hl
03D8 * push hl
03D9 * ld de,00203h
03DC * ldi
03DE * ldi
03E0 * ldi
03E2 * ld a,0ffh
03E4 * ld (de),a
03E5 * pop hl
03E6 * dec hl
03E7 * dec hl
03E8 * ld de,00204h
03EB * jr $+41
03ED * call chr_path_find
03F0 * pop ix
03F2 * ld a,(02907h)
03F5 * cp 0fdh
03F7 * ret nz
03F8 * ld a,(ix-001h)
03FB * ld (ix-003h),a
03FE * ret
03FF   ld hl,02b68h
0402   jr $+15
0404   ld hl,02b59h
0407   jr $+10
0409   ld hl,02bb4h
040C   jr $+5
040E * ld hl,02b87h
0411 * ld de,00201h
0414 * push iy
0416 * call chr_path_add_targets_around
0419 * ld ix,00203h
041D * ld (00213h),ix
0421 * ld a,(ix+000h)
0424 * cp 0ffh
0426 * pop iy
0428 * jr nz,$-59
042A   pop ix
042C   ret
