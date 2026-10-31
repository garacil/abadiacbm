; f_4292 at 4292 (64K)   PC: -   CPC 6128: -   called 24231 times by 41C5 426B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4292 * res 4,(iy+005h)
4296 * bit 7,(iy+005h)
429A * jr z,$+72
429C * bit 5,(iy+005h)
42A0 * jr z,$+10
42A2 * exx
42A3 * ld hl,03f83h
42A6 * exx
42A7 * jp 0431dh
42AA * inc (iy+004h)
42AD * exx
42AE * ld hl,03f83h
42B1 * exx
42B2 * cp 001h
42B4 * jr z,$+17
42B6 * exx
42B7 * ld hl,03f89h
42BA * exx
42BB * dec (iy+004h)
42BE * set 4,(iy+005h)
42C2 * dec (iy+004h)
42C5 * cp c
42C6 * jr nz,$+81
42C8 * exx
42C9 * inc hl
42CA * inc hl
42CB * inc hl
42CC * exx
42CD * ld a,(iy+005h)
42D0 * and 010h
42D2 * ld (iy+005h),a
42D5 * push hl
42D6 * call chr_apply_step
42D9 * pop hl
42DA * call chr_orientation_parity
42DD * call z,chr_apply_step
42E0 * jr $+64
42E2 * cp 001h
42E4 * jr z,$+13
42E6 * cp 0ffh
42E8 * jr z,$+21
42EA * exx
42EB * ld hl,03f8fh
42EE * exx
42EF * jr $+40
42F1 * inc (iy+004h)
42F4 * ld a,080h
42F6 * exx
42F7 * ld hl,03f86h
