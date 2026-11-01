; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_apply_step at 2539 (64K)   PC: 2437   CPC 6128: 29E4   called 49146 times by 24F2 24F9 2528 252F 2553 42D6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2539 * ld a,(hl)
253A * add a,(iy+002h)
253D * ld (iy+002h),a
2540 * inc hl
2541 * ld a,(hl)
2542 * add a,(iy+003h)
2545 * ld (iy+003h),a
2548 * ret
