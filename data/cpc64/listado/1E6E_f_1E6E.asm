; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_1E6E at 1E6E (64K)   PC: -   CPC 6128: -   called 46 times by 20C8
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1E6E * pop hl
1E6F * ld b,0bch
1E71 * ld c,(hl)
1E72 * inc hl
1E73 * push hl
1E74 * inc c
1E75 * ret z
1E76 * dec c
1E77 * pop hl
1E78 * out (c),c
1E7A * inc b
1E7B * ld c,(hl)
1E7C * out (c),c
1E7E * inc hl
1E7F * jr $-16
1E81   xor (hl)
1E82   jr nz,$-85
1E84   jr nz,$-79
1E86   jr nz,$-70
1E88   jr nz,$+2
1E8A   nop
1E8B   nop
1E8C   nop
1E8D   nop
1E8E   nop
1E8F   nop
1E90   nop
1E91   daa
1E92   nop
1E93   ld a,000h
1E95   nop
1E96   nop
1E97   nop
1E98   nop
1E99   nop
1E9A   ld a,(bc)
1E9B   add hl,bc
1E9C   nop
1E9D   rlca
1E9E   ex af,af'
1E9F   ld hl,(02628h)
1EA2   add hl,hl
1EA3   scf
1EA4   jr c,$+59
1EA6   nop
1EA7   nop
1EA8   nop
1EA9   nop
1EAA   nop
1EAB   ld (bc),a
1EAC   ld bc,00d00h
1EAF   ld c,024h
1EB1   inc hl
1EB2   dec h
1EB3   dec hl
1EB4   inc l
1EB5   dec l
1EB6   nop
1EB7   nop
1EB8   nop
1EB9   nop
1EBA   nop
1EBB   inc bc
1EBC   nop
1EBD   rra
1EBE   nop
1EBF   nop
1EC0   nop
1EC1   ld (02e00h),hl
1EC4   cpl
1EC5   jr nc,$+2
1EC7   nop
1EC8   nop
1EC9   nop
1ECA   nop
1ECB   inc b
1ECC   dec e
1ECD   ld e,03eh
1ECF   dec a
1ED0   nop
1ED1   ld hl,03100h
1ED4   ld (00033h),a
1ED7   nop
1ED8   nop
1ED9   nop
1EDA   inc c
1EDB   dec bc
1EDC   inc e
1EDD   dec b
1EDE   ld b,03ch
1EE0   nop
1EE1   jr nz,$+2
1EE3   inc (hl)
1EE4   dec (hl)
1EE5   ld (hl),000h
1EE7   nop
1EE8   nop
1EE9   nop
1EEA   nop
1EEB   nop
1EEC   rrca
1EED   djnz $+19
1EEF   ld (de),a
1EF0   nop
1EF1   dec de
1EF2   nop
1EF3   ld a,(de)
1EF4   ld a,(0003bh)
1EF7   nop
1EF8   nop
1EF9   nop
1EFA   nop
1EFB   nop
1EFC   nop
1EFD   nop
1EFE   nop
1EFF   inc de
1F00   inc d
1F01   dec d
1F02   jr $+27
1F04   nop
1F05   nop
1F06   nop
1F07   nop
1F08   nop
1F09   nop
1F0A   nop
1F0B   nop
1F0C   nop
1F0D   nop
1F0E   nop
1F0F   nop
1F10   nop
1F11   ld d,000h
1F13   nop
1F14   nop
1F15   nop
1F16   nop
1F17   nop
1F18   nop
1F19   nop
1F1A   nop
1F1B   nop
1F1C   nop
1F1D   nop
1F1E   nop
1F1F   nop
1F20   nop
1F21   rla
1F22   nop
1F23   nop
1F24   nop
1F25   nop
1F26   nop
1F27   nop
1F28   nop
1F29   nop
1F2A   ld b,l
1F2B   ld b,h
1F2C   nop
1F2D   ld c,b
1F2E   ld c,c
1F2F   nop
1F30   nop
1F31   nop
1F32   ld h,a
1F33   ld h,(hl)
1F34   nop
1F35   ld h,l
1F36   ld h,h
1F37   nop
1F38   nop
1F39   nop
1F3A   nop
1F3B   ld b,e
1F3C   ld b,a
1F3D   ld c,d
1F3E   nop
1F3F   nop
1F40   nop
1F41   nop
1F42   nop
1F43   ld l,d
1F44   ld l,c
1F45   ld l,b
1F46   nop
1F47   nop
1F48   nop
1F49   nop
1F4A   nop
1F4B   ld b,d
1F4C   nop
1F4D   ld c,e
1F4E   nop
1F4F   nop
1F50   nop
1F51   nop
1F52   nop
1F53   ld l,h
1F54   nop
1F55   ld l,e
1F56   nop
1F57   nop
1F58   nop
1F59   nop
1F5A   nop
1F5B   ld b,c
1F5C   ld b,b
1F5D   ld c,h
1F5E   nop
1F5F   nop
1F60   nop
1F61   nop
1F62   nop
1F63   ld l,a
1F64   ld l,(hl)
1F65   ld l,l
1F66   nop
1F67   nop
1F68   nop
1F69   nop
1F6A   ccf
1F6B   ld b,(hl)
1F6C   nop
1F6D   ld c,l
1F6E   ld c,(hl)
1F6F   nop
1F70   nop
1F71   nop
1F72   ld (hl),e
1F73   ld (hl),d
1F74   nop
1F75   ld (hl),c
1F76   ld (hl),b
1F77   nop
1F78   nop
