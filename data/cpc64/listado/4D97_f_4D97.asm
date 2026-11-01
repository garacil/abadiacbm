; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4D97 at 4D97 (64K)   PC: -   CPC 6128: -   called 26960 times by 4C04
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4D97 * ld a,(02947h)
4D9A * and 002h
4D9C * add a,a
4D9D * add a,a
4D9E * add a,a
4D9F * ld c,a
4DA0 * ld a,0efh
4DA2 * ld hl,0292dh
4DA5 * and (hl)
4DA6 * or c
4DA7 * ld (hl),a
4DA8 * ld a,(02940h)
4DAB * and 00ch
4DAD * ld c,a
4DAE * res 2,c
4DB0 * srl c
4DB2 * srl c
4DB4 * srl c
4DB6 * and 004h
4DB8 * or c
4DB9 * ld c,a
4DBA * ld hl,0292ah
4DBD * ld a,0fah
4DBF * and (hl)
4DC0 * or c
4DC1 * ld (hl),a
4DC2 * ret
