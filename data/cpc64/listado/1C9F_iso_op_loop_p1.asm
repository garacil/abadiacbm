; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_op_loop_p1 at 1C9F (64K)   PC: 2AD2   CPC 6128: 2091   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1C9F * ld a,06dh
1CA1 * call iso_operand_value
1CA4 * jr z,$+15
1CA6 * push ix
1CA8 * push bc
1CA9 * jp 01c2ch
1CAC * ld a,06eh
1CAE * call iso_operand_value
1CB1 * jr nz,$-11
1CB3 * ld b,001h
1CB5 * ld a,(ix+000h)
1CB8 * inc ix
1CBA * inc ix
1CBC * cp 082h
1CBE * jr z,$-9
1CC0 * dec ix
1CC2 * inc b
1CC3 * cp 0feh
1CC5 * jr z,$-16
1CC7 * cp 0fdh
1CC9 * jr z,$-20
1CCB * cp 0e8h
1CCD * jr z,$-24
1CCF * cp 0e7h
1CD1 * jr z,$-28
1CD3 * dec b
1CD4 * cp 0fah
1CD6 * jr nz,$-33
1CD8 * djnz $-35
1CDA * jp 01c2ch
1CDD * push hl
1CDE * jp 01c2ch
1CE1 * pop hl
1CE2 * jp 01c2ch
