; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; txt_draw_char at 364D (64K)   PC: 37B0   CPC 6128: 3B17   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
364D * ld c,00fh
364F * and 07fh
3651 * cp 020h
3653 * ld de,0344ch
3656 * jr z,$+16
3658 * sub 02dh
365A * ret c
365B * ld l,a
365C * ld h,000h
365E * add hl,hl
365F * add hl,hl
3660 * add hl,hl
3661 * ld de,0b400h
3664 * add hl,de
3665 * ex de,hl
3666 * ld hl,(028e8h)
3669 * push hl
366A * call f_3778
366D * ld b,008h
366F * ld a,(de)
3670 * and 0f0h
3672 * xor c
3673 * ld (hl),a
3674 * ld a,(de)
3675 * add a,a
3676 * add a,a
3677 * add a,a
3678 * add a,a
3679 * inc hl
367A * xor c
367B * ld (hl),a
367C * dec hl
367D * call f_3558
3680 * inc de
3681 * djnz $-18
3683 * pop hl
3684 * inc l
3685 * inc l
3686 * ld (028e8h),hl
3689 * ret
