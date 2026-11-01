; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_0010 at 0010 (64K)   PC: -   CPC 6128: -   called 284561 times by 5213 5235 53F2 53F5 5465 567B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0010 * nop
0011   nop
0012   nop
0013   nop
0014   nop
0015   nop
0016   nop
0017   nop
0018   nop
0019   nop
001A   nop
001B   nop
001C   nop
001D   nop
001E   nop
001F   nop
0020   nop
0021   nop
0022   nop
0023   nop
0024   nop
0025   nop
0026   nop
0027   nop
0028   nop
0029   nop
002A   nop
002B   nop
002C   nop
002D   nop
002E   nop
002F   nop
0030   nop
0031   nop
0032   nop
0033   nop
0034   nop
0035   nop
0036   nop
0037   nop
0038 * jp 00000h
003B   nop
003C   nop
003D   nop
003E   nop
003F   nop
0040   nop
0041   nop
0042   nop
0043   nop
0044   nop
0045   nop
0046   nop
0047   nop
0048   nop
0049   nop
004A   nop
004B   nop
004C   nop
004D   nop
004E   nop
004F   nop
0050   nop
0051   nop
0052   nop
0053   nop
0054   nop
0055   nop
0056   nop
0057   nop
0058   nop
0059   nop
005A   nop
005B   nop
005C   nop
005D   nop
005E   nop
005F   nop
0060   nop
0061   nop
0062   nop
0063   nop
0064   nop
0065   nop
0066   nop
0067   nop
0068   nop
0069   nop
006A   nop
006B   nop
006C   nop
006D   nop
006E   nop
006F   nop
0070   nop
0071   nop
0072   nop
0073   nop
0074   nop
0075   nop
0076   nop
0077   nop
0078   nop
0079   nop
007A   nop
007B   nop
007C   nop
007D   nop
007E   nop
007F   nop
0080   nop
0081   nop
0082   nop
0083   nop
0084   nop
0085   nop
0086   nop
0087   nop
0088   nop
0089   nop
008A   nop
008B   nop
008C   nop
008D   nop
008E   nop
008F   nop
0090   nop
0091   nop
0092   nop
0093   nop
0094   nop
0095   nop
0096   nop
0097   nop
0098   nop
0099   nop
009A   nop
009B   nop
009C   nop
009D   nop
009E   nop
009F   nop
00A0   nop
00A1   nop
00A2   nop
00A3   nop
00A4   nop
00A5   nop
00A6   nop
00A7   nop
00A8   nop
00A9   nop
00AA   nop
00AB   nop
00AC   nop
00AD   nop
00AE   nop
00AF   nop
00B0   nop
00B1   nop
00B2   nop
00B3   nop
00B4   nop
00B5   nop
00B6   nop
00B7   nop
00B8   nop
00B9   nop
00BA   nop
00BB   nop
00BC   nop
00BD   nop
00BE   nop
00BF   nop
00C0   nop
00C1   nop
00C2   nop
00C3   nop
00C4   nop
00C5   nop
00C6   nop
00C7   nop
00C8   nop
00C9   nop
00CA   nop
00CB   nop
00CC   nop
00CD   nop
00CE   nop
00CF   nop
00D0   nop
00D1   nop
00D2   nop
00D3   nop
00D4   nop
00D5   nop
00D6   nop
00D7   nop
00D8   nop
00D9   nop
00DA   nop
00DB   nop
00DC   nop
00DD   nop
00DE   nop
00DF   nop
00E0   nop
00E1   nop
00E2   nop
00E3   nop
00E4   nop
00E5   nop
00E6   nop
00E7   nop
00E8   nop
00E9   nop
00EA   nop
00EB   nop
00EC   nop
00ED   nop
00EE   nop
00EF   nop
00F0   nop
00F1   nop
00F2   nop
00F3   nop
00F4   nop
00F5   nop
00F6   nop
00F7   nop
00F8   nop
00F9   nop
00FA   nop
00FB   nop
00FC   inc bc
00FD   ld bc,0fe26h
0100   nop
0101   jp 020beh
0104   ld c,026h
0106   ld a,(de)
0107   rst 38h
0108   rst 18h
0109   ld (087eeh),hl
010C   adc a,e
010D   sub c
010E   ld hl,057ffh
0111   or 0a9h
0113   rst 38h
0114   sub 0dfh
0116   sbc a,c
0117   ret pe
0118   or d
0119   ld b,a
011A   sub 00ch
011C   ld (0ffffh),hl
011F   ei
0120   sbc a,0c5h
0122   sbc a,l
0123   and c
0124   jr $-114
0126   daa
0127   add hl,bc
0128   ld (028afh),hl
012B   ex af,af'
012C   add hl,bc
012D   rlca
012E   dec c
012F   ld (hl),b
0130   rlca
0131   rlca
0132   inc c
0133   nop
0134   ccf
0135   ld (02174h),hl
0138   ld d,b
0139   dec bc
013A   ld c,00ch
013C   ld (bc),a
013D   sub (hl)
013E   jr nz,$+49
0140   ld (025b7h),hl
0143   ld a,(bc)
0144   ld (bc),a
0145   ex af,af'
0146   jr c,$+59
0148   ld hl,0210fh
014B   or a
014C   ld h,005h
014E   rlca
014F   ld b,00ah
0151   rra
0152   ld (0afe1h),hl
0155   ld hl,0b702h
0158   jr nz,$+9
015A   ld c,022h
015C   ld b,084h
015E   jr nz,$+72
0160   ld hl,01eabh
0163   ld e,a
0164   ld hl,0051bh
0167   ld (bc),a
0168   xor h
0169   jr nz,$+6
016B   add hl,bc
016C   ld c,h
016D   dec sp
016E   ld hl,026afh
0171   dec b
0172   dec c
0173   dec b
0174   ld e,l
0175   ld (de),a
0176   dec h
0177   sbc a,h
0178   ld (000c7h),hl
017B   ld e,c
017C   jr nz,$+8
017E   ld hl,03a29h
0181   ld hl,00202h
0184   dec c
0185   add hl,hl
0186   ld e,c
0187   ld bc,0040dh
018A   dec c
018B   ld b,d
018C   add hl,de
018D   ld (bc),a
018E   dec de
018F   ret
0190   ex af,af'
0191   nop
0192   ld d,003h
0194   ex af,af'
0195   ld e,c
0196   nop
0197   ld a,a
0198   rlca
0199   ld hl,0441bh
019C   xor l
019D   ld d,e
019E   inc bc
019F   ld b,d
01A0   dec hl
01A1   dec c
01A2   ld b,007h
01A4   ld (0a209h),hl
01A7   rlca
01A8   ld (05703h),hl
01AB   ld l,e
01AC   ld a,(bc)
01AD   ex af,af'
01AE   rlca
01AF   ld (0b20fh),hl
01B2   rlca
01B3   ld (08cech),hl
01B6   dec b
01B7   ld b,003h
01B9   rlca
01BA   rlca
01BB   ld (0c35dh),hl
01BE   add a,(hl)
01BF   add a,(hl)
01C0   add hl,bc
01C1   inc b
01C2   ld e,c
01C3   inc c
01C4   push hl
01C5   adc a,h
01C6   ld l,007h
01C8   ld hl,02b95h
01CB   ld b,a
01CC   ld bc,0090eh
01CF   rrca
01D0   inc c
01D1   dec bc
01D2   ld b,b
01D3   dec b
01D4   dec b
01D5   ex af,af'
01D6   nop
01D7   ld (bc),a
01D8   inc bc
01D9   inc c
01DA   ld a,(bc)
01DB   jr nz,$+12
01DD   ld bc,0600dh
01E0   and l
01E1   dec hl
01E2   dec d
01E3   ld (02320h),hl
01E6   inc de
01E7   or h
01E8   ld d,d
01E9   jr nz,$+38
01EB   rla
01EC   jr nz,$+38
01EE   ret m
01EF   scf
01F0   ld (02991h),a
01F3   ld a,c
01F4   ld hl,02115h
01F7   ld de,021b1h
01FA   ld e,e
01FB   ld de,021b1h
01FE   ld de,0c3b1h
0201   cp (hl)
0202   jr nz,$+2
0204   nop
0205   nop
0206   nop
0207   nop
0208   nop
0209   nop
020A   nop
020B   nop
020C   nop
020D   nop
020E   nop
020F   nop
0210   nop
0211   nop
0212   rst 38h
0213   nop
0214   nop
0215   ld (bc),a
0216   nop
0217   nop
0218   cp 0feh
021A   nop
021B   nop
021C   ld (bc),a
021D   rst 38h
021E   sbc a,001h
0220   nop
0221   nop
0222   nop
0223   ld bc,0ff00h
0226   sub 000h
0228   ld bc,00000h
022B   ret pe
022C   rst 38h
022D   ei
022E   sub 000h
0230   nop
0231   nop
0232   nop
0233   rst 38h
0234   rst 38h
0235   ei
0236   sbc a,001h
0238   ld bc,00101h
023B   jr $+2
023D   nop
023E   nop
023F   nop
0240   nop
0241   nop
0242   nop
0243   nop
0244   nop
0245   ex af,af'
0246   nop
0247   ex af,af'
0248   ex af,af'
0249   nop
024A   nop
024B   nop
024C   nop
024D   nop
024E   ex af,af'
024F   ex af,af'
0250   nop
0251   ex af,af'
0252   ex af,af'
0253   ex af,af'
0254   add hl,bc
0255   rlca
0256   dec c
0257   rlca
0258   rlca
0259   inc c
025A   nop
025B   nop
025C   nop
025D   ld bc,0031eh
0260   dec c
0261   ld b,00ah
0263   ld a,(bc)
0264   dec bc
0265   inc c
0266   ld (bc),a
0267   ex af,af'
0268   ex af,af'
0269   inc bc
026A   inc b
026B   nop
026C   nop
026D   nop
026E   inc bc
026F   inc b
0270   ld a,(bc)
0271   ld bc,00a0eh
0274   ld a,(bc)
0275   ld (bc),a
0276   ex af,af'
0277   ld a,(bc)
0278   ld a,(bc)
0279   ld bc,00004h
027C   nop
027D   nop
027E   ld bc,00f05h
0281   dec b
0282   ld b,003h
0284   rlca
0285   dec b
0286   rlca
0287   ld b,00ah
0289   add hl,bc
028A   inc b
028B   nop
028C   nop
028D   nop
028E   add hl,bc
028F   inc b
0290   ld (bc),a
0291   ld bc,0070ch
0294   dec b
0295   dec b
0296   dec b
0297   dec b
0298   ld b,003h
029A   inc b
029B   nop
029C   nop
029D   ld bc,0081eh
02A0   nop
02A1   ex af,af'
02A2   dec de
02A3   dec b
02A4   dec b
02A5   dec b
02A6   dec b
02A7   dec b
02A8   inc b
02A9   add hl,bc
02AA   inc b
02AB   nop
02AC   nop
02AD   nop
02AE   ld (bc),a
02AF   inc bc
02B0   inc c
02B1   ld a,(bc)
02B2   ld a,(bc)
02B3   ld bc,0050dh
02B6   dec c
02B7   dec b
02B8   ld b,002h
02BA   nop
02BB   nop
02BC   nop
02BD   nop
02BE   nop
02BF   nop
02C0   ld (bc),a
02C1   ld (bc),a
02C2   inc bc
02C3   inc c
02C4   ld a,(bc)
02C5   nop
02C6   ld a,(bc)
02C7   add hl,bc
02C8   ld b,000h
02CA   nop
02CB   nop
02CC   nop
02CD   nop
02CE   nop
02CF   nop
02D0   nop
02D1   nop
02D2   nop
02D3   ld (bc),a
02D4   inc bc
02D5   dec c
02D6   ld b,002h
02D8   ld (bc),a
02D9   nop
02DA   nop
02DB   nop
02DC   nop
02DD   nop
02DE   nop
02DF   nop
02E0   nop
02E1   nop
02E2   nop
02E3   nop
02E4   ld bc,0040dh
02E7   nop
02E8   nop
02E9   nop
02EA   nop
02EB   nop
02EC   nop
02ED   nop
02EE   nop
02EF   nop
02F0   nop
02F1   nop
02F2   nop
02F3   nop
02F4   nop
02F5   ld (bc),a
02F6   nop
02F7   nop
02F8   nop
02F9   nop
02FA   nop
02FB   nop
02FC   nop
02FD   nop
02FE   ex af,af'
02FF   ex af,af'
0300   nop
0301   ex af,af'
0302   ex af,af'
0303   nop
0304   nop
0305   nop
0306   ex af,af'
0307   ex af,af'
0308   nop
0309   ex af,af'
030A   ex af,af'
030B   nop
030C   nop
030D   ld bc,0032eh
