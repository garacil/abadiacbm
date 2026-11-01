; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3F56 at 3F56 (64K)   PC: -   CPC 6128: -   called 24637 times by 55F9
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3F56 * ld a,(037f2h)
3F59 * and 001h
3F5B * ret nz
3F5C * ld a,(02940h)
3F5F * and 010h
3F61 * cp 010h
3F63 * ret z
3F64 * ld a,(02b68h)
3F67 * bit 7,a
3F69 * ret nz
3F6A * ld a,(02b6ch)
3F6D * call iso_floor_base
3F70 * ld a,b
3F71 * and a
3F72 * ret
3F73   dec a
3F74   ld (bc),a
3F75   ld bc,00603h
3F78   inc bc
3F79   adc a,b
3F7A   nop
3F7B   ld d,c
3F7C   nop
3F7D   ld l,(hl)
3F7E   jr nz,$+115
3F80   nop
3F81   nop
3F82   nop
3F83   add a,b
3F84   nop
3F85   ld (bc),a
3F86   jr nz,$+2
3F88   inc b
3F89   ret nz
3F8A   nop
3F8B   ld (bc),a
3F8C   jr nc,$+2
3F8E   inc b
3F8F   add a,b
3F90   nop
3F91   defb 001h
