; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3A88 at 3A88 (64K)   PC: -   CPC 6128: -   called 21 times by 503C
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3A88 * ld hl,03a78h
3A8B * jr $+5
3A8D   ld hl,03a7dh
3A90 * ld a,004h
3A92 * ld b,07fh
3A94 * ld c,a
3A95 * dec c
3A96 * out (c),c
3A98 * ld c,(hl)
3A99 * inc hl
3A9A * set 6,c
3A9C * out (c),c
3A9E * dec a
3A9F * jr nz,$-11
3AA1 * ld c,010h
3AA3 * out (c),c
3AA5 * ld c,(hl)
3AA6 * set 6,c
3AA8 * out (c),c
3AAA * ret
3AAB   ld a,03ah
3AAD   jr $+28
