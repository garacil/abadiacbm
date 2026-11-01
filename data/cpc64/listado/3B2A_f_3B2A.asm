; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3B2A at 3B2A (64K)   PC: -   CPC 6128: -   called 215040 times by 3AED 3AFC 3B0C 3B1B 3B26
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3B2A * push hl
3B2B * push bc
3B2C * push af
3B2D * call f_3778
3B30 * pop af
3B31 * ld (hl),a
3B32 * push af
3B33 * call f_3558
3B36 * pop af
3B37 * ld (hl),a
3B38 * pop bc
3B39 * pop hl
3B3A * ret
3B3B   ld a,(0294bh)
3B3E   and 080h
3B40   ld hl,(037d4h)
3B43   or h
3B44   or l
3B45   ret z
3B46   xor a
3B47   ld (037deh),a
3B4A   ld l,a
3B4B   ld h,a
3B4C   ld (037d4h),hl
3B4F   ld (037d8h),a
3B52   ld hl,02944h
3B55   res 7,(hl)
3B57   ld hl,0294bh
3B5A   res 7,(hl)
