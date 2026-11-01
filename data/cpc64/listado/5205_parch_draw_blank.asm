; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; parch_draw_blank at 5205 (64K)   PC: 06ED   CPC 6128: 65AF   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5205   adc a,h
5206   dec d
5207   dec a
5208   ld hl,(001a5h)
520B   dec a
520C   ld hl,(00b8ch)
520F   dec a
5210   ld hl,(00420h)
5213 * rst 10h
5214   and a
5215   inc bc
5216 * ret
5217 * rst 8
5218   add a,(hl)
5219   ld b,b
521A   cp 03dh
521C   adc a,b
521D   dec b
521E   dec a
521F   adc a,(hl)
5220   ld b,03ch
5222   ld h,02ah
5224 * jr nz,$+6
5226   rst 10h
5227   and a
5228   ld (bc),a
5229   ret
522A * rst 8
522B   sub e
522C   ld b,b
522D   rst 38h
522E   dec a
522F * jr nz,$+6
5231   rst 10h
5232   and a
5233   dec b
5234   ret
5235 * rst 10h
5236   and a
5237   nop
5238 * rst 8
5239   and h
523A   djnz $+44
523C   djnz $+63
523E * jr nz,$+48
5240   rst 8
5241   adc a,l
5242   inc bc
5243   dec a
5244   adc a,b
5245   nop
5246   dec a
5247   ld h,020h
5249   dec b
524A   rst 10h
524B   ret nz
524C   ret nz
524D   djnz $+40
524F   rst 8
5250   and h
5251   ld b,b
5252   jr nz,$+44
5254   ld b,b
5255   jr nz,$+63
5257   jr nz,$+7
5259   rst 10h
525A   ret nz
525B   ret nz
525C   ld bc,0cf26h
525F   sbc a,d
5260   dec c
5261   dec a
5262   and a
5263   nop
5264   dec a
5265   ld h,020h
5267   ld b,0d7h
5269   ret nz
526A   ret nz
526B   ld b,b
526C   jr nz,$+40
526E * rst 8
526F   adc a,b
5270   nop
