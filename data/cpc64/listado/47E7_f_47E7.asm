; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_47E7 at 47E7 (64K)   PC: -   CPC 6128: -   called 25467 times by 47BF
; '*' = executed in the exploration sessions; the listing runs to the next known entry
47E7 * xor a
47E8 * ld (0486dh),a
47EB * ld h,(ix+00dh)
47EE * ld b,(ix+00fh)
47F1 * exx
47F2 * ld de,00000h
47F5 * exx
47F6 * ld a,h
47F7 * cp 0c8h
47F9 * ret nc
47FA * sub 028h
47FC * ld h,a
47FD * jr nc,$+21
47FF * neg
4801 * cp b
4802 * ret nc
4803 * exx
4804 * ld h,000h
4806 * ld l,(ix+00eh)
4809 * call f_48EB
480C * exx
480D * ld a,b
480E * add a,h
480F * ld b,a
4810 * ld h,000h
4812 * exx
4813 * ld l,(ix+010h)
4816 * ld h,(ix+011h)
4819 * add hl,de
481A * exx
481B * ld l,(ix+00ch)
481E * ld c,(ix+00eh)
4821 * ld a,l
4822 * cp 048h
4824 * ret nc
4825 * sub 008h
4827 * ld l,a
4828 * jr nc,$+23
482A * neg
482C * cp (ix+00eh)
482F * ret nc
4830 * ld (0486dh),a
4833 * exx
4834 * add a,l
4835 * ld l,a
4836 * adc a,h
4837 * sub l
4838 * ld h,a
4839 * exx
483A * ld a,c
483B * add a,l
483C * ld c,a
483D * ld l,000h
483F * ld a,c
4840 * add a,l
4841 * sub 040h
4843 * jr c,$+9
4845 * ld (0486dh),a
4848 * neg
484A * add a,c
484B * ld c,a
484C * ld a,c
484D * ld (04868h),a
4850 * ld a,b
4851 * ld c,a
4852 * add a,h
4853 * sub 0a0h
4855 * jr c,$+6
4857 * neg
4859 * add a,c
485A * ld c,a
485B * ld a,c
485C * ld (04863h),a
485F * call f_3778
4862 * ld b,000h
4864 * push hl
4865 * exx
4866 * pop de
4867 * ld bc,00000h
486A * ldir
486C * ld a,000h
486E * add a,l
486F * ld l,a
4870 * adc a,h
4871 * sub l
4872 * ld h,a
4873 * exx
4874 * ld a,h
4875 * add a,008h
4877 * ld h,a
4878 * jr nc,$+11
487A * ld a,040h
487C * add a,l
487D * ld l,a
487E * adc a,h
487F * sub l
4880 * or 0c0h
4882 * ld h,a
4883 * djnz $-31
4885 * ret
