; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4717 at 4717 (64K)   PC: -   CPC 6128: -   called 841898 times by 46AE
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4717 * exx
4718 * ld h,a
4719 * ld l,000h
471B * rra
471C * adc hl,hl
471E * rra
471F * adc hl,hl
4721 * rra
4722 * adc hl,hl
4724 * rra
4725 * adc hl,hl
4727 * rra
4728 * and 0f0h
472A * or l
472B * exx
472C * ret
472D   push ix
472F   ld hl,04451h
4732   push de
4733   exx
4734   pop hl
4735   ld e,l
4736   ld d,h
4737   ld bc,00000h
473A   ld (hl),0ffh
473C   inc de
473D   ldir
473F   push de
4740   pop ix
4742   ld de,00050h
4745   exx
4746   ld b,00fh
4748   push ix
474A   ld a,(hl)
474B   exx
474C   ld h,a
474D   exx
474E   inc hl
474F   ld a,(hl)
4750   inc hl
4751   exx
4752   ld l,a
4753   ld a,0ffh
4755   ld b,000h
4757   inc b
4758   dec b
4759   jr z,$+18
475B   ld (ix+000h),a
475E   ld (ix+014h),a
4761   ld (ix+028h),a
4764   ld (ix+03ch),a
4767   inc ix
4769   djnz $-14
476B   ld b,010h
476D   add hl,hl
476E   add hl,hl
476F   jr c,$+14
4771   ld (ix+000h),a
4774   ld (ix+014h),a
4777   ld (ix+028h),a
477A   ld (ix+03ch),a
477D   inc ix
477F   djnz $-17
4781   ld b,000h
4783   ld (ix+000h),a
4786   ld (ix+014h),a
4789   ld (ix+028h),a
478C   ld (ix+03ch),a
478F   inc ix
4791   djnz $-14
4793   pop ix
4795   add ix,de
4797   exx
4798   djnz $-80
479A   push ix
479C   pop hl
479D   ld bc,00000h
47A0   ld e,l
47A1   ld d,h
47A2   inc de
47A3   ld (hl),0ffh
47A5   ldir
47A7   pop ix
47A9   jp 04597h
47AC * ld ix,02968h
47B0 * ld a,(ix+000h)
47B3 * cp 0ffh
47B5 * jr z,$+43
47B7 * cp 0feh
47B9 * jr z,$+31
47BB * and 040h
47BD * jr z,$+27
47BF * call f_47E7
47C2 * res 7,(ix+000h)
47C6 * res 6,(ix+000h)
47CA * bit 7,(ix+005h)
47CE * jr z,$+10
47D0 * res 7,(ix+005h)
47D4 * ld (ix+000h),0feh
47D8 * ld bc,00014h
47DB * add ix,bc
47DD * jp 047b0h
47E0 * ld sp,(04473h)
47E4 * jp 0447dh
