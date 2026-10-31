; chr_path_find at 05FA (64K)   PC: 0DA5   CPC 6128: 098A   called 64490 times by 03ED 05F3
; '*' = executed in the exploration sessions; the listing runs to the next known entry
05FA * ld a,0feh
05FC * ld (02907h),a
05FF * ld a,000h
0601 * and 001h
0603 * ret nz
0604 * ld a,(028fah)
0607 * and a
0608 * ret nz
0609 * ld a,076h
060B * ld (0440dh),a
060E * xor a
060F * ld (02907h),a
0612 * ld a,(iy+004h)
0615 * call iso_floor_base
0618 * ld e,b
0619 * ld a,(ix+002h)
061C * and 03fh
061E * call iso_floor_base
0621 * ld a,e
0622 * ld hl,0023dh
0625 * and a
0626 * jr z,$+12
0628 * ld hl,002edh
062B * cp 00bh
062D * jr z,$+5
062F   ld hl,002f5h
0632 * ld (03f73h),hl
0635 * cp b
0636 * jr z,$+113
0638   ld a,010h
063A   jr c,$+4
063C   ld a,020h
063E   ld c,a
063F   ld a,(iy+003h)
0642   and 0f0h
0644   ld e,a
0645   ld a,(iy+002h)
0648   rrca
0649   rrca
064A   rrca
064B   rrca
064C   and 00fh
064E   or e
064F   call util_add_bx_al
0652   ld a,(hl)
0653   and c
0654   ld a,c
0655   jr nz,$+39
0657   cp 010h
0659   ld a,066h
065B   jr z,$+4
065D   ld a,06eh
065F   ld (0440dh),a
0662   call chr_room_coords
0665   ld (02903h),hl
0668   call 04399h
066B   call chr_path_clear_room_marks
066E   ld a,076h
0670   ld (0440dh),a
0673   ld a,(02907h)
0676   and a
0677   ret z
0678   ex de,hl
0679   jp 00734h
067C   cp 010h
067E   ld a,00dh
0680   jr z,$+4
0682   ld a,001h
0684   ld (00692h),a
0687   call chr_path_build_grid
068A   ld hl,08174h
068D   ld bc,00240h
0690   ld a,(hl)
0691   cp 000h
0693   jr nz,$+4
0695   set 6,(hl)
0697   inc hl
0698   dec bc
0699   ld a,b
069A   or c
069B   jr nz,$-11
069D   ld (02905h),bc
06A1   call chr_path_reset_alternatives
06A4   jp 0076dh
06A7 * ld l,(ix+000h)
06AA * ld h,(ix+001h)
06AD * ld a,(iy+002h)
06B0 * xor l
06B1 * ld c,a
06B2 * and 0f0h
06B4 * jr nz,$+112
06B6 * ld a,(iy+003h)
06B9 * xor h
06BA * ld b,a
06BB * and 0f0h
06BD * jr nz,$+103
06BF * ld a,0fdh
06C1 * ld (02907h),a
06C4 * ld a,b
06C5 * or c
06C6 * jr nz,$+38
