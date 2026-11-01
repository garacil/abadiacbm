; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_2D50 at 2D50 (64K)   PC: -   CPC 6128: -   called 32034 times by 20D5 2D99 3EB8
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2D50 * di
2D51 * ld bc,0f40eh
2D54 * out (c),c
2D56 * ld b,0f6h
2D58 * in a,(c)
2D5A * and 030h
2D5C * ld c,a
2D5D * or 0c0h
2D5F * out (c),a
2D61 * out (c),c
2D63 * inc b
2D64 * ld a,092h
2D66 * out (c),a
2D68 * push bc
2D69 * ld hl,02de8h
2D6C * ld de,02df2h
2D6F * set 6,c
2D71 * ld b,0f6h
2D73 * out (c),c
2D75 * ld b,0f4h
2D77 * in a,(c)
2D79 * ld b,a
2D7A * ld a,c
2D7B * and 00fh
2D7D * ld a,b
2D7E * or (hl)
2D7F * cpl
2D80 * ld (hl),b
2D81 * ld b,a
2D82 * ld a,(de)
2D83 * and b
2D84 * or (hl)
2D85 * ld (de),a
2D86 * inc c
2D87 * inc de
2D88 * inc hl
2D89 * ld a,c
2D8A * and 00fh
2D8C * cp 00ah
2D8E * jr c,$-31
2D90 * pop bc
2D91 * ld a,082h
2D93 * out (c),a
2D95 * dec b
2D96 * out (c),c
2D98 * ret
