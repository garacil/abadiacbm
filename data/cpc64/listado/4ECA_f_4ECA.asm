; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4ECA at 4ECA (64K)   PC: -   CPC 6128: -   called 26960 times by 21D3
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4ECA * ld a,(028ddh)
4ECD * and a
4ECE * ret z
4ECF * ld iy,02b87h
4ED3 * ld ix,029a4h
4ED7 * ld hl,0855ch
4EDA * ld de,02cf0h
4EDD * ld bc,028deh
4EE0 * call f_4EF4
4EE3 * ld bc,028e3h
4EE6 * ld hl,08656h
4EE9 * ld de,02d10h
4EEC * ld iy,02b96h
4EF0 * ld ix,029b8h
