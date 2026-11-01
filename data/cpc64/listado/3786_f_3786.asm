; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3786 at 3786 (64K)   PC: -   CPC 6128: -   called 1678554 times by 3552 45D6 45F8
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3786 * ld a,l
3787 * sub h
3788 * jr z,$+19
378A * jr c,$+26
378C * cp d
378D * ret nc
378E * ld h,a
378F * ld l,000h
3791 * add a,e
3792 * cp d
3793 * jr nc,$+4
3795 * ld a,e
3796 * ret
3797 * ld a,d
3798 * sub h
3799 * scf
379A * ret
379B * ld hl,00000h
379E * ld a,e
379F * cp d
37A0 * ret c
37A1 * scf
37A2 * ld a,d
37A3 * ret
37A4 * ld h,000h
37A6 * neg
37A8 * ld l,a
37A9 * cp e
37AA * ret nc
37AB * neg
37AD * add a,e
37AE * cp d
37AF * ret c
37B0 * scf
37B1 * ret z
37B2 * ld a,d
37B3 * ret
37B4   dec (hl)
37B5   ld bc,00436h
37B8   rst 38h
37B9   dec de
37BA   ex af,af'
37BB   dec hl
37BC   ld (bc),a
37BD   rst 38h
37BE   ld d,(hl)
37BF   ex af,af'
37C0   ld h,(hl)
37C1   ld (bc),a
37C2   rst 38h
37C3   add hl,hl
37C4   ld bc,0042ah
37C7   rst 38h
37C8   daa
37C9   ld bc,00428h
37CC   rst 38h
37CD   ld (hl),l
37CE   ld bc,00476h
37D1   rst 38h
37D2   nop
37D3   nop
37D4   nop
37D5   nop
37D6   nop
37D7   nop
37D8   nop
37D9   nop
37DA   nop
37DB   nop
37DC   nop
37DD   nop
37DE   nop
37DF   nop
37E0   nop
37E1   nop
37E2   nop
37E3   nop
37E4   nop
37E5   nop
37E6   nop
37E7   nop
37E8   nop
37E9   nop
37EA   nop
37EB   nop
37EC   nop
37ED   nop
37EE   nop
37EF   nop
37F0   nop
37F1   nop
37F2   nop
37F3   rst 28h
37F4   ld (bc),a
37F5   jp m,00000h
37F8   add a,h
37F9   ld c,b
37FA   ld b,d
37FB   cpl
37FC   scf
37FD   ld (bc),a
37FE   scf
37FF   jr c,$+81
3801   ld a,(08f34h)
3804   ld e,l
3805   ld (hl),a
3806   nop
3807   ld e,b
3808   ld hl,(03500h)
380B   scf
380C   ld d,e
380D   cp h
380E   jr $+4
3810   ld l,b
3811   ld d,d
3812   ld (bc),a
3813   jp m,00000h
3816   adc a,b
3817   inc a
3818   call nz,0373dh
381B   add a,d
381C   ld d,h
381D   inc a
381E   ld (bc),a
381F   adc a,b
3820   add a,h
3821   jp nz,058a4h
3824   ld b,b
3825   and l
3826   ld hl,09c02h
3829   ld hl,(0c702h)
382C   daa
382D   nop
382E   ld l,b
382F   ld h,c
3830   ld b,d
3831   ld a,(00f34h)
3834   jp m,00000h
3837   adc a,h
3838   ld c,b
3839   ld b,d
383A   ld (0c235h),a
383D   dec a
383E   ld e,h
383F   adc a,a
3840   cp h
3841   dec d
3842   ld (bc),a
3843   adc a,b
3844   sbc a,h
3845   ret nz
3846   ld d,d
3847   ld h,a
3848   inc b
3849   ld l,b
384A   ld d,a
384B   ld (bc),a
384C   jp m,00000h
384F   adc a,h
3850   ld c,e
3851   ld b,d
3852   ld (hl),035h
3854   jp nz,05568h
3857   ld (bc),a
3858   ret
3859   ld hl,(01900h)
385C   dec hl
385D   ld a,(de)
385E   rst 38h
385F   nop
3860   nop
3861   add a,h
3862   ld c,(hl)
3863   ld b,d
3864   inc (hl)
3865   add hl,sp
3866   ld b,d
3867   xor b
3868   jr $+2
386A   adc a,c
386B   dec hl
386C   adc a,d
386D   dec hl
386E   adc a,e
386F   dec hl
3870   sbc a,b
3871   dec hl
3872   add a,02bh
3874   sbc a,d
3875   dec hl
3876   rst 30h
3877   scf
3878   push af
3879   scf
387A   jp nc,0f228h
387D   jr z,$+21
387F   jr c,$+23
3881   jr c,$+22
3883   jr c,$-45
3885   jr z,$-8
3887   scf
3888   ex de,hl
3889   scf
388A   ld (hl),038h
388C   inc (hl)
388D   jr c,$+55
388F   jr c,$+80
3891   jr c,$+78
3893   jr c,$+79
3895   jr c,$+98
3897   jr c,$+96
3899   jr c,$+97
389B   jr c,$-25
389D   scf
389E   ld c,029h
38A0   rst 20h
38A1   scf
38A2   call po,0c537h
38A5   dec hl
38A6   di
38A7   scf
38A8   ld c,a
38A9   dec hl
38AA   ld d,h
38AB   dec hl
38AC   and 037h
38AE   ld e,e
38AF   ld a,(037e3h)
38B2   ld b,b
38B3   add hl,hl
38B4   pop hl
38B5   scf
38B6   ld d,l
38B7   add hl,hl
38B8   rst 18h
38B9   scf
38BA   ld e,h
38BB   add hl,hl
38BC   or b
38BD   inc b
38BE   jp po,0ee37h
38C1   scf
38C2   rst 28h
38C3   scf
38C4   ret p
38C5   scf
38C6   jp p,0e837h
38C9   scf
38CA   ld e,(hl)
38CB   add hl,hl
38CC   pop af
38CD   scf
38CE   jp pe,0dd37h
38D1   scf
38D2   exx
38D3   scf
38D4   jp c,0db37h
38D7   scf
38D8   ret c
38D9   scf
38DA   ld b,h
38DB   add hl,hl
38DC   call p,05037h
38DF   add hl,hl
38E0   ld c,(hl)
38E1   add hl,hl
38E2   xor l
38E3   inc a
38E4   jp nc,04737h
38E7   add hl,hl
38E8   rrca
38E9   add hl,hl
38EA   djnz $+43
38EC   ld b,018h
38EE   ld b,00ch
38F0   ld b,00ch
38F2   inc c
38F3   jr $+14
38F5   jr $+8
38F7   inc c
38F8   ld b,00ch
38FA   ld b,018h
38FC * pop hl
38FD * ld a,(hl)
38FE * inc hl
38FF * push hl
3900 * call f_3910
3903 * ld (0390dh),hl
3906 * pop hl
3907 * call f_3926
390A * push hl
390B * ld a,c
390C * ld (00000h),a
390F * ret
