; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_orientation_parity at 2503 (64K)   PC: 23FA   CPC 6128: 29AE   called 2873 times by 24C6 24F6 252C 42DA 430F
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2503 * ld a,(iy+001h)
2506 * and 003h
2508 * ret z
2509 * xor 003h
250B * ret
