; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_call_return at 1DFE (64K)   PC: 2C5E   CPC 6128: 21F0   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1DFE * pop af
1DFF * ld (01bebh),a
1E02 * pop bc
1E03 * ld (01be9h),bc
1E07 * pop bc
1E08 * ld (01bech),bc
1E0C * pop bc
1E0D * ld a,c
1E0E * ld (01d06h),a
1E11 * ld a,b
1E12 * ld (01e3eh),a
1E15 * pop bc
1E16 * ld a,c
1E17 * ld (01c60h),a
1E1A * ld a,b
1E1B * ld (01c66h),a
1E1E * pop hl
1E1F * jp 01c2ch
