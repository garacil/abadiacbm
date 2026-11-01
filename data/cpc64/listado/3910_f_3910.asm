; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3910 at 3910 (64K)   PC: -   CPC 6128: -   called 2719540 times by 3900 39A2
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3910 * add a,a
3911 * ld hl,0386ah
3914 * add a,l
3915 * ld l,a
3916 * adc a,h
3917 * sub l
3918 * ld h,a
3919 * ld e,(hl)
391A * inc hl
391B * ld d,(hl)
391C * ex de,hl
391D * ret
391E * pop hl
391F * call f_3926
3922 * push hl
3923 * ld a,c
3924 * and a
3925 * ret
