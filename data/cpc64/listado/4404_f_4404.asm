; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4404 at 4404 (64K)   PC: -   CPC 6128: -   called 275762 times by 43D8 43E5 43F2 43FF
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4404 * ld a,(ix+000h)
4407 * and c
4408 * ret nz
4409 * ld a,b
440A * bit 6,(ix+000h)
440E * jp nz,040d8h
4411 * bit 7,(ix+000h)
4415 * ret nz
4416 * set 7,(ix+000h)
441A * pop bc
441B * push de
441C * push bc
441D * ret
