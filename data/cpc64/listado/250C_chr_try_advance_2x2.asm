; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_try_advance_2x2 at 250C (64K)   PC: 2405   CPC 6128: 29B7   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
250C * cp 001h
250E * jr z,$+10
2510 * cp 0ffh
2512 * jr z,$+13
2514 * and a
2515 * ret nz
2516 * jr $+51
2518 * inc (iy+004h)
251B * ld a,080h
251D * jr $+7
251F * dec (iy+004h)
2522 * ld a,090h
2524 * ld (iy+005h),a
2527 * push hl
2528 * call chr_apply_step
252B * pop hl
252C * call chr_orientation_parity
252F * call nz,chr_apply_step
2532 * ld a,0ffh
2534 * ld (02912h),a
2537 * jr $+31
