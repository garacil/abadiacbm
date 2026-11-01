; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4AC8 at 4AC8 (64K)   PC: -   CPC 6128: -   called 47617 times by 4AA1 4AA8
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4AC8 * push de
4AC9 * exx
4ACA * call f_49E5
4ACD * pop de
4ACE * ret
4ACF   nop
4AD0   nop
4AD1   nop
4AD2   nop
4AD3   nop
4AD4   nop
4AD5   nop
4AD6   nop
4AD7   nop
4AD8   nop
4AD9   dec b
4ADA   nop
4ADB   dec b
4ADC   nop
4ADD   nop
4ADE   nop
4ADF   nop
4AE0   dec b
4AE1   nop
4AE2   dec b
4AE3   nop
4AE4   nop
4AE5   rrca
4AE6   nop
4AE7   nop
4AE8   nop
4AE9   dec b
4AEA   nop
4AEB   nop
4AEC   rrca
4AED   nop
4AEE   dec b
4AEF   nop
4AF0   nop
4AF1   nop
4AF2   nop
4AF3   rrca
4AF4   nop
4AF5   dec b
4AF6   nop
4AF7   dec b
4AF8   nop
4AF9   nop
4AFA   rrca
4AFB   nop
4AFC   nop
4AFD   nop
4AFE   ld (bc),a
4AFF   nop
4B00   nop
4B01   ld (bc),a
4B02   ld (bc),a
4B03   ld (bc),a
4B04   ld (bc),a
4B05   ld (bc),a
4B06   nop
4B07   ld (bc),a
4B08   ld bc,00100h
4B0B   nop
4B0C   nop
4B0D   ld bc,00102h
4B10   ld (bc),a
4B11   ld (bc),a
4B12   jr nz,$+80
4B14   ld c,a
4B15   ld b,e
4B16   ld c,b
4B17   ld b,l
4B18   jr nz,$+34
4B1A   ld d,b
4B1B   ld d,d
4B1C   ld c,c
4B1D   ld c,l
4B1E   ld b,c
4B1F   jr nz,$+86
4B21   ld b,l
4B22   ld d,d
4B23   ld b,e
4B24   ld c,c
4B25   ld b,c
4B26   jr nz,$+34
4B28   ld d,e
4B29   ld b,l
4B2A   ld e,b
4B2B   ld d,h
4B2C   ld b,c
4B2D   jr nz,$+34
4B2F   ld c,(hl)
4B30   ld c,a
4B31   ld c,(hl)
4B32   ld b,c
4B33   jr nz,$+34
4B35   ld d,(hl)
4B36   ld a,050h
4B38   ld b,l
4B39   ld d,d
4B3A   ld b,c
4B3B   ld d,e
4B3C   ld b,e
4B3D   ld c,a
4B3E   ld c,l
4B3F   dec l
4B40   ld l,02fh
4B42   defb 03eh
