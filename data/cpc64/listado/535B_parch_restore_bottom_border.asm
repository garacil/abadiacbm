; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; parch_restore_bottom_border at 535B (64K)   PC: 0900   CPC 6128: 6705   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
535B   ld a,(bc)
535C   rst 10h
535D   adc a,(hl)
535E   inc c
535F   ret
5360   rst 8
5361   adc a,(hl)
5362   inc b
5363   dec a
5364   jr nz,$+36
5366   rst 10h
5367   add a,(hl)
5368   inc b
5369   rst 8
536A   add a,a
536B   inc b
536C   dec a
536D   jr nz,$+26
536F   rst 8
5370   sbc a,l
5371   ld h,d
5372   inc a
5373   xor e
5374   ld h,020h
5376   inc bc
5377   jp 039a8h
537A   rst 10h
