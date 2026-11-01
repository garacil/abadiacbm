; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_5129 at 5129 (64K)   PC: -   CPC 6128: -   called 306 times by 2171 5124
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5129 * pop hl
512A * ld c,(hl)
512B * inc hl
512C * push hl
512D * ld a,(028d0h)
5130 * sub c
5131 * jr nc,$+14
5133 * ld a,(037e4h)
5136 * and a
5137 * jr nz,$+7
5139 * ld a,00bh
513B * ld (03814h),a
513E * xor a
513F * ld (028d0h),a
5142 * ld c,a
5143 * ld hl,05180h
5146 * and 003h
5148 * call util_add_bx_al
514B * ld e,(hl)
514C * ld hl,0cdb4h
514F * srl c
5151 * srl c
5153 * ld a,c
5154 * ld d,00fh
5156 * call f_5164
5159 * ld a,001h
515B * ld d,e
515C * call f_5164
515F * ld a,007h
5161 * sub c
5162 * ld d,0ffh
