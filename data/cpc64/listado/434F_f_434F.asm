; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_434F at 434F (64K)   PC: -   CPC 6128: -   called 4229 times by 07E3 41AE
; '*' = executed in the exploration sessions; the listing runs to the next known entry
434F * ld d,(iy+003h)
4352 * ld e,(iy+002h)
4355 * push de
4356 * ld d,(iy+001h)
4359 * ld e,(iy+004h)
435C * push de
435D * ld (iy+009h),000h
4361 * ld (iy+00bh),000h
4365 * ld a,(iy+005h)
4368 * push af
4369 * call f_41C9
436C * pop af
436D * ld (iy+005h),a
4370 * ld hl,01000h
4373 * ld b,00ch
4375 * call chr_cmd_write_bits
4378 * pop hl
4379 * ld (iy+004h),l
437C * ld (iy+001h),h
437F * pop hl
4380 * ld (iy+002h),l
4383 * ld (iy+003h),h
4386 * ld (iy+009h),000h
438A * ld (iy+00bh),000h
438E * ret
