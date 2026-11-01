; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_backup_args at 28AD (64K)   PC: 2834   CPC 6128: 2D5C   called 30686 times by 279C 2806
; '*' = executed in the exploration sessions; the listing runs to the next known entry
28AD * push iy
28AF * pop hl
28B0 * inc hl
28B1 * inc hl
28B2 * ld de,028b9h
28B5 * ld bc,0000ah
28B8 * ret
28B9   ld d,l
28BA   nop
28BB   nop
28BC   ld b,0c0h
28BE   ld h,c
28BF   ld sp,00000h
28C2   nop
28C3   nop
28C4   nop
28C5   nop
28C6   nop
28C7   nop
28C8   nop
28C9   ld bc,00054h
28CC   nop
28CD   ld b,0c0h
28CF   ld h,c
28D0   rra
28D1   ld bc,01204h
28D4   ld c,e
28D5   ret p
28D6   dec hl
28D7   xor h
28D8   dec c
28D9   add a,a
28DA   dec hl
28DB   ld l,0aeh
28DD   ld bc,0c006h
28E0   ld h,c
28E1   jr nc,$+2
28E3   nop
28E4   nop
28E5   ld d,e
28E6   ld b,c
28E7   ld b,e
28E8   jr z,$-94
28EA   nop
28EB   nop
28EC   nop
28ED   nop
28EE   nop
28EF   nop
28F0   nop
28F1   nop
28F2   nop
28F3   nop
28F4   nop
28F5   nop
28F6   nop
28F7   nop
28F8   nop
28F9   nop
28FA   nop
28FB   nop
28FC   nop
28FD   nop
28FE   nop
28FF   nop
2900   nop
2901   nop
2902   nop
2903   nop
2904   nop
2905   nop
2906   nop
2907   nop
2908   nop
2909   nop
290A   nop
290B   nop
290C   nop
290D   nop
290E   nop
290F   nop
2910   nop
2911   nop
2912   nop
2913   ld sp,hl
2914   cp a
2915   ret
2916   ld b,c
2917   ld d,d
2918   ld c,l
2919   ld b,l
291A   ld d,e
291B   nop
291C   nop
291D   nop
291E   nop
291F   ld b,0c0h
2921   ld h,c
2922   xor c
2923   ld (bc),a
2924   nop
2925   nop
2926   nop
2927   nop
2928   nop
2929   nop
292A   ex af,af'
292B   adc a,c
292C   dec hl
292D   ex af,af'
292E   sbc a,b
292F   dec hl
2930   rra
2931   and a
2932   dec hl
2933   add hl,de
2934   or (hl)
2935   dec hl
2936   rra
2937   push bc
2938   dec hl
2939   inc c
293A   call nc,0ff2bh
293D   ld bc,02b89h
2940   jr nz,$+2
2942   defb 0fdh,000h,001h	;illegal sequence
2945   sbc a,b
2946   dec hl
2947   nop
2948   add a,b
2949   ld (bc),a
294A   nop
294B   ld bc,02ba7h
294E   nop
294F   add a,b
2950   ld (bc),a
2951   nop
2952   nop
2953   or (hl)
2954   dec hl
2955   nop
2956   nop
2957   djnz $+2
2959   nop
295A   push bc
295B   dec hl
295C   nop
295D   nop
295E   nop
295F   nop
2960   nop
2961   call nc,0002bh
2964   nop
2965   nop
2966   nop
2967   rst 38h
2968   cp 01eh
296A   ld b,d
296B   ld e,042h
296D   dec b
296E   ld (038b4h),hl
2971   dec b
2972   ld (00080h),hl
2975   nop
2976   nop
2977   nop
2978   nop
2979   nop
297A   nop
297B   nop
297C   cp 028h
297E   ld (03228h),a
2981   dec b
2982   ld (038aah),hl
2985   dec b
2986   inc h
2987   add a,b
2988   nop
2989   nop
298A   nop
298B   nop
298C   nop
298D   nop
298E   nop
298F   nop
2990   cp 032h
2992   ld (03232h),a
2995   dec b
2996   ld (03a2ah),hl
2999   dec b
299A   ld (00000h),hl
299D   nop
299E   nop
299F   nop
29A0   nop
29A1   nop
29A2   nop
29A3   nop
29A4   cp 032h
29A6   ld (03232h),a
29A9   dec b
29AA   ld (03a2ah),hl
29AD   dec b
29AE   ld (00000h),hl
29B1   nop
29B2   nop
29B3   nop
29B4   nop
29B5   nop
29B6   nop
29B7   nop
29B8   cp 032h
29BA   ld (03232h),a
29BD   dec b
29BE   ld (03a2ah),hl
29C1   dec b
29C2   ld (00000h),hl
29C5   nop
29C6   nop
29C7   nop
29C8   nop
29C9   nop
29CA   nop
29CB   nop
29CC   cp 032h
29CE   ld (03232h),a
29D1   dec b
29D2   ld (03a2ah),hl
29D5   dec b
29D6   ld (00000h),hl
29D9   nop
29DA   nop
29DB   nop
29DC   nop
29DD   nop
29DE   nop
29DF   nop
29E0   cp 000h
29E2   nop
29E3   nop
29E4   nop
29E5   ld b,028h
29E7   sbc a,b
29E8   ld a,(02806h)
29EB   add a,b
29EC   nop
29ED   nop
29EE   nop
29EF   nop
29F0   nop
29F1   nop
29F2   nop
29F3   nop
29F4   cp 000h
29F6   nop
29F7   nop
29F8   nop
29F9   ld b,028h
29FB   sbc a,b
29FC   ld a,(02806h)
29FF   add a,b
2A00   nop
2A01   nop
2A02   nop
2A03   nop
2A04   nop
2A05   nop
2A06   nop
2A07   nop
2A08   cp 000h
2A0A   nop
2A0B   nop
2A0C   nop
2A0D   ld b,028h
2A0F   sbc a,b
2A10   ld a,(02806h)
2A13   add a,b
2A14   nop
2A15   nop
2A16   nop
2A17   nop
2A18   nop
2A19   nop
2A1A   nop
2A1B   nop
2A1C   cp 000h
2A1E   nop
2A1F   nop
2A20   nop
2A21   ld b,028h
2A23   sbc a,b
2A24   ld a,(02806h)
2A27   add a,b
2A28   nop
2A29   nop
2A2A   nop
2A2B   nop
2A2C   nop
2A2D   nop
2A2E   nop
2A2F   nop
2A30   cp 000h
2A32   nop
2A33   nop
2A34   nop
2A35   ld b,028h
2A37   sbc a,b
2A38   ld a,(02806h)
2A3B   add a,b
2A3C   nop
2A3D   nop
2A3E   nop
2A3F   nop
2A40   nop
2A41   nop
2A42   nop
2A43   nop
2A44   cp 000h
2A46   nop
2A47   nop
2A48   nop
2A49   ld b,028h
2A4B   sbc a,b
2A4C   ld a,(02806h)
2A4F   add a,b
2A50   nop
2A51   nop
2A52   nop
2A53   nop
2A54   nop
2A55   nop
2A56   nop
2A57   nop
2A58   cp 000h
2A5A   nop
2A5B   nop
2A5C   nop
2A5D   ld b,028h
2A5F   sbc a,b
2A60   ld a,(02806h)
2A63   add a,b
2A64   nop
2A65   nop
2A66   nop
2A67   nop
2A68   nop
2A69   nop
2A6A   nop
2A6B   nop
2A6C   cp 000h
2A6E   nop
2A6F   nop
2A70   nop
2A71   inc b
2A72   inc c
2A73   ret nc
2A74   rst 10h
2A75   inc b
2A76   inc c
2A77   add a,b
2A78   nop
2A79   nop
2A7A   nop
2A7B   nop
2A7C   nop
2A7D   nop
2A7E   nop
2A7F   nop
2A80   cp 000h
2A82   nop
2A83   nop
2A84   nop
2A85   inc b
2A86   inc c
2A87   ld d,b
2A88   sub a
2A89   inc b
2A8A   inc c
2A8B   add a,b
2A8C   nop
2A8D   nop
2A8E   nop
2A8F   nop
2A90   nop
2A91   nop
2A92   nop
2A93   nop
2A94   cp 000h
2A96   nop
2A97   nop
2A98   nop
2A99   inc b
2A9A   inc c
2A9B   jr nz,$-103
2A9D   inc b
2A9E   inc c
2A9F   add a,b
2AA0   nop
2AA1   nop
2AA2   nop
2AA3   nop
2AA4   nop
2AA5   nop
2AA6   nop
2AA7   nop
2AA8   cp 000h
2AAA   nop
2AAB   nop
2AAC   nop
2AAD   inc b
2AAE   inc c
2AAF   or b
2AB0   sub a
2AB1   inc b
2AB2   inc c
2AB3   add a,b
2AB4   nop
2AB5   nop
2AB6   nop
2AB7   nop
2AB8   nop
2AB9   nop
2ABA   nop
2ABB   nop
2ABC   cp 000h
2ABE   nop
2ABF   nop
2AC0   nop
2AC1   inc b
2AC2   inc c
2AC3   add a,b
2AC4   sub a
2AC5   inc b
2AC6   inc c
2AC7   add a,b
2AC8   nop
2AC9   nop
2ACA   nop
2ACB   nop
2ACC   nop
2ACD   nop
2ACE   nop
2ACF   nop
2AD0   cp 000h
2AD2   nop
2AD3   nop
2AD4   nop
2AD5   inc b
2AD6   inc c
2AD7   add a,b
2AD8   sub a
2AD9   inc b
2ADA   inc c
2ADB   add a,b
2ADC   nop
2ADD   nop
2ADE   nop
2ADF   nop
2AE0   nop
2AE1   nop
2AE2   nop
2AE3   nop
2AE4   cp 000h
2AE6   nop
2AE7   nop
2AE8   nop
2AE9   inc b
2AEA   inc c
2AEB   add a,b
2AEC   sub a
2AED   inc b
2AEE   inc c
2AEF   add a,b
2AF0   nop
2AF1   nop
2AF2   nop
2AF3   nop
2AF4   nop
2AF5   nop
2AF6   nop
2AF7   nop
2AF8   cp 000h
2AFA   nop
2AFB   nop
2AFC   nop
2AFD   inc b
2AFE   inc c
2AFF   ld b,0a0h
2B01   inc b
2B02   inc c
2B03   add a,b
2B04   nop
2B05   nop
2B06   nop
2B07   nop
2B08   nop
2B09   nop
2B0A   nop
2B0B   nop
2B0C   cp 000h
2B0E   nop
2B0F   nop
2B10   nop
2B11   inc b
2B12   inc c
2B13   and b
2B14   rst 10h
2B15   inc b
2B16   inc c
2B17   add a,b
2B18   nop
2B19   nop
2B1A   nop
2B1B   nop
2B1C   nop
2B1D   nop
2B1E   nop
2B1F   nop
2B20   cp 000h
2B22   nop
2B23   nop
2B24   nop
2B25   inc d
2B26   ld d,b
2B27   nop
2B28   nop
2B29   inc d
2B2A   ld d,b
2B2B   add a,b
2B2C   nop
2B2D   nop
2B2E   nop
2B2F   nop
2B30   nop
2B31   nop
2B32   cp 0feh
2B34   rst 38h
2B35   ld bc,06121h
2B38   scf
2B39   ld (bc),a
2B3A   ld (bc),a
2B3B   ld (01eb7h),hl
2B3E   ld (bc),a
2B3F   nop
2B40   inc b
2B41   ld h,(hl)
2B42   ld e,a
2B43   ld (bc),a
2B44   inc bc
2B45   jr z,$-96
2B47   jr z,$+4
2B49   inc bc
2B4A   djnz $+128
2B4C   ld h,002h
2B4E   ld (bc),a
2B4F   ret po
2B50   ld h,b
2B51   halt
2B52   nop
2B53   ld (bc),a
2B54   ret nz
2B55   ld h,b
2B56   ld a,e
2B57   nop
2B58   rst 38h
2B59   nop
2B5A   ld bc,05e34h
2B5D   inc de
2B5E   nop
2B5F   nop
2B60   ld l,e
2B61   ld d,l
2B62   ld b,080h
2B64   nop
2B65   dec a
2B66   add hl,hl
2B67   nop
2B68   nop
2B69   ld bc,05e36h
2B6C   inc de
2B6D   nop
2B6E   nop
2B6F   nop
2B70   nop
2B71   nop
2B72   nop
2B73   nop
2B74   nop
2B75   nop
2B76   nop
2B77   nop
2B78   nop
2B79   dec (hl)
2B7A   dec (hl)
2B7B   inc de
2B7C   nop
2B7D   nop
2B7E   ex af,af'
2B7F   ex af,af'
2B80   ld (bc),a
2B81   nop
2B82   nop
2B83   ex af,af'
2B84   ex af,af'
2B85   ld (bc),a
2B86   rst 38h
2B87   nop
2B88   ld bc,02222h
2B8B   nop
2B8C   nop
2B8D   nop
2B8E   cp 0deh
2B90   nop
2B91   nop
2B92   nop
2B93   nop
2B94   nop
2B95   djnz $+2
2B97   ld bc,02424h
2B9A   nop
2B9B   nop
2B9C   nop
2B9D   cp 0e0h
2B9F   nop
2BA0   defb 0fdh,000h,01ch	;illegal sequence
2BA3   ld (hl),020h
2BA5   nop
2BA6   nop
2BA7   ld h,026h
2BA9   rrca
2BAA   nop
2BAB   nop
2BAC   defb 0feh
