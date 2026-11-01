; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_think_or_step at 249A (64K)   PC: 2370   CPC 6128: 2945   called 163900 times by 2492
; '*' = executed in the exploration sessions; the listing runs to the next known entry
249A * jp nz,chr_animate
249D * ld a,(iy+000h)
24A0 * and 001h
24A2 * jp nz,02556h
24A5 * ld hl,023e2h
24A8 * jp (hl)
