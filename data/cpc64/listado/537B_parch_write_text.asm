; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; parch_write_text at 537B (64K)   PC: 0932   CPC 6128: 6725   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
537B   adc a,(hl)
537C   dec b
537D   rst 10h
537E   sbc a,a
537F   sbc a,a
5380   ld a,a
5381   ld hl,(0a0d7h)
5384   and b
5385   ld a,a
5386   ld hl,(0cfc9h)
5389   adc a,(hl)
538A   dec b
538B   dec a
538C   jr nz,$+21
538E   rst 10h
538F   add a,(hl)
5390   dec b
5391   rst 10h
5392   sbc a,(hl)
5393   ld b,b
5394   rst 18h
5395   rst 8
5396   add a,b
5397   ld h,b
5398   inc a
5399   jr nz,$+5
539B   rst 10h
539C   adc a,(hl)
539D   inc c
539E   jp 039e5h
53A1   rst 8
53A2   adc a,(hl)
53A3   ld b,03dh
53A5   jr nz,$+8
53A7   rst 10h
53A8   add a,(hl)
53A9   nop
53AA   call 039e5h
53AD   rst 8
53AE   adc a,(hl)
53AF   dec bc
53B0   dec a
53B1   jr nz,$+12
53B3   rst 8
53B4   adc a,c
53B5   nop
53B6   dec a
53B7   jr nz,$+5
53B9   rst 10h
53BA   xor h
53BB   ld bc,0cfc9h
53BE   adc a,(hl)
53BF   rlca
53C0   dec a
53C1   jr nz,$+29
53C3   rst 8
53C4   adc a,l
53C5   dec b
53C6   dec a
53C7   jr nz,$+22
53C9   rst 8
53CA   sbc a,d
53CB   ld (09a3dh),hl
53CE   inc hl
53CF   dec a
53D0   ld hl,(00a20h)
53D3   rst 10h
53D4   add a,a
53D5   ld bc,08ed7h
53D8   dec bc
53D9   call f_4B71
53DC   rra
53DD   ret
53DE   ret
53DF * rst 8
53E0   adc a,b
53E1   ld bc,0203dh
53E4   rlca
53E5   rst 10h
53E6   adc a,(hl)
53E7   add hl,bc
53E8   rst 10h
53E9   add a,(hl)
53EA   nop
53EB   ret
53EC * rst 8
53ED   add a,a
53EE   ld (bc),a
53EF   dec a
53F0 * jr nz,$+11
53F2 * rst 10h
53F3   adc a,(hl)
53F4   nop
53F5 * rst 10h
53F6   cp d
53F7   nop
53F8 * call f_3B66
53FB * rst 8
53FC   adc a,(hl)
53FD   nop
53FE   dec a
53FF * jp nz,05469h
5402 * call ai_guillermo_is_close
5405 * jp nz,05465h
5408   rst 8
5409   add a,(hl)
540A   inc bc
540B   dec a
540C   jr nz,$+73
540E   rst 8
540F   xor (hl)
5410   ld b,b
5411   add a,b
5412   ld hl,(01220h)
5415   rst 8
5416   add a,c
5417   jr c,$+62
5419   jr nz,$+12
541B   rst 10h
