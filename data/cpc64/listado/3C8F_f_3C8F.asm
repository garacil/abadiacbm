; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3C8F at 3C8F (64K)   PC: -   CPC 6128: -   called 26960 times by 3CCB
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3C8F * jr nc,$+14
3C91   ld a,032h
3C93   ld (037e0h),a
3C96   ld a,005h
3C98   ld (037dfh),a
3C9B   xor a
3C9C   ret
3C9D * xor a
3C9E * call sys_key_down
3CA1 * ret nz
3CA2 * ld a,008h
3CA4 * call sys_key_down
3CA7 * ret nz
3CA8 * ld a,001h
3CAA * jp sys_key_down
3CAD   nop
