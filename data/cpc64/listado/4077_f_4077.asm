; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4077 at 4077 (64K)   PC: -   CPC 6128: -   called 5546462 times by 404E 405A 4066 4072
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4077 * ld c,(ix+000h)
407A * ld (03f81h),a
407D * bit 7,c
407F * ret nz
