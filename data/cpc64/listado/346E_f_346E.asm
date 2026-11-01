; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_346E at 346E (64K)   PC: -   CPC 6128: -   called 6279 times by 3468
; '*' = executed in the exploration sessions; the listing runs to the next known entry
346E * ld c,(ix+000h)
3471 * inc c
3472 * ret z
3473 * dec c
3474 * ld d,(ix+003h)
3477 * bit 3,c
3479 * jr nz,$+10
347B * ld a,d
347C * rrca
347D * rrca
347E * rrca
347F * rrca
3480 * and 00fh
3482 * ld d,a
3483 * ld h,(ix+001h)
3486 * call f_3549
3489 * jr nc,$+114
348B * bit 3,c
348D * exx
348E * ld d,(ix+004h)
3491 * jr nz,$+8
3493 * ld a,(ix+003h)
3496 * and 00fh
3498 * ld d,a
3499 * ld h,(ix+002h)
349C * call f_354D
349F * exx
34A0 * jr nc,$+91
34A2 * exx
34A3 * xor a
34A4 * ld (0351ch),a
34A7 * ld (03515h),a
34AA * ld a,(ix+000h)
34AD * ld c,a
34AE * and 007h
34B0 * ld b,a
34B1 * ld a,c
34B2 * rrca
34B3 * rrca
34B4 * rrca
34B5 * rrca
34B6 * and 00fh
34B8 * dec b
34B9 * call z,f_3521
34BC * dec b
34BD * call z,f_352C
34C0 * dec b
34C1 * call z,f_3535
34C4 * dec b
34C5 * call z,f_3540
34C8 * ld c,e
34C9 * ld h,000h
34CB * add hl,hl
34CC * add hl,hl
34CD * add hl,hl
34CE * ld e,l
34CF * ld d,h
34D0 * add hl,hl
34D1 * add hl,de
34D2 * ld de,(028dbh)
34D6 * add hl,de
34D7 * ex af,af'
34D8 * exx
34D9 * ld a,e
34DA * ld (034eah),a
34DD * ld (03510h),a
34E0 * ld a,l
34E1 * exx
34E2 * call util_add_bx_al
34E5 * ex af,af'
34E6 * dec b
34E7 * jr nz,$+35
34E9 * ld b,000h
34EB * ld d,h
34EC * ld e,l
34ED * ld (hl),a
34EE * inc hl
34EF * djnz $-2
34F1 * ld hl,00018h
34F4 * add hl,de
34F5 * dec c
34F6 * jr nz,$-13
34F8 * ld c,(ix+000h)
34FB * ld de,00004h
34FE * add ix,de
3500 * bit 3,c
3502 * jp z,f_346E
3505 * inc ix
3507 * jp f_346E
350A * ld de,00018h
350D * ld b,c
350E * ld c,a
350F * ld a,000h
3511 * push bc
3512 * push hl
3513 * ld (hl),c
3514 * inc hl
3515 * dec c
3516 * dec a
3517 * jr nz,$-4
3519 * pop hl
351A * pop bc
351B * add hl,de
351C * inc c
351D * djnz $-14
351F * jr $-39
