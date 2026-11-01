; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4164 at 4164 (64K)   PC: -   CPC 6128: -   called 630 times by 417A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4164 * xor a
4165 * ld (040c2h),a
4168 * ld c,(iy+00eh)
416B * call chr_mark_hbuf
416E * ret
416F * res 7,(ix+000h)
4173 * pop de
4174 * pop ix
4176 * pop bc
4177 * call f_41A8
417A * call f_4164
417D * jp ai_update_adso
4180   ld bc,0e800h
4183   rst 38h
4184   rst 38h
4185   rst 38h
4186   jr $+2
4188   inc bc
4189   nop
418A   ld (bc),a
418B   ld bc,00300h
418E   ld bc,00102h
4191   nop
4192   ld (bc),a
4193   inc bc
4194   nop
4195   ld bc,00203h
4198   inc bc
4199   ld (bc),a
419A   nop
419B   ld bc,00302h
419E   ld bc,00100h
41A1   ld (bc),a
41A2   nop
41A3   inc bc
41A4   ld (bc),a
41A5   ld bc,00003h
