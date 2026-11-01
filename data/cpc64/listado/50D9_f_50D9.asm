; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_50D9 at 50D9 (64K)   PC: -   CPC 6128: -   called 63 times by 50C0 50C3 50C6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
50D9 * push hl
50DA * ld a,003h
50DC * ld (050feh),a
50DF * ld a,(de)
50E0 * ld bc,0ab49h
50E3 * cp 002h
50E5 * jr z,$+16
50E7 * ld bc,0ab39h
50EA * and a
50EB * jr nz,$+10
50ED * ld a,00bh
50EF * ld (050feh),a
50F2 * ld bc,050d7h
50F5 * ld a,008h
50F7 * push af
50F8 * ld a,(bc)
50F9 * ld (hl),a
50FA * inc hl
50FB * inc bc
50FC * ld a,(bc)
50FD * ld (hl),a
50FE * inc bc
50FF * dec hl
5100 * call f_3558
5103 * pop af
5104 * dec a
5105 * jr nz,$-14
5107 * pop hl
5108 * inc hl
5109 * inc hl
510A * inc de
510B * ret
