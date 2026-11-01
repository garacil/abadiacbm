; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; snd_silence_if_idle at 0FE6 (64K)   PC: 63A3   CPC 6128: 1376   called 67 times by 20D2 2165
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0FE6 * ld a,084h
0FE8 * ld (00c1eh),a
0FEB * ld (00c36h),a
0FEE * ld (00c4eh),a
0FF1 * ld c,03fh
0FF3 * ld a,007h
0FF5 * jp snd_stub_psg_write
0FF8   ld bc,00101h
0FFB   ld (bc),a
0FFC   rst 38h
0FFD   ld bc,00101h
1000   ld bc,00180h
1003   ld bc,00204h
1006   rst 38h
1007   inc b
1008   ld bc,00401h
100B   add a,b
100C   inc c
100D   ld bc,00c01h
1010   rst 38h
1011   ld bc,0017fh
1014   rst 38h
1015   ld (bc),a
1016   add a,b
1017   ld bc,00401h
101A   add a,b
101B   ld bc,0080fh
101E   rrca
101F   rst 38h
1020   ld a,(bc)
1021   ld a,a
1022   rrca
1023   ld bc,00f05h
1026   rst 38h
1027   add hl,bc
1028   ld a,a
1029   ld bc,002d8h
102C   add a,b
102D   ld bc,00100h
1030   ld a,a
1031   ld bc,00105h
1034   ld a,a
1035   ld bc,0010fh
1038   ld bc,02800h
103B   rrca
103C   rst 38h
103D   inc d
103E   ld a,a
103F   dec b
1040   ld bc,00502h
1043   ld (bc),a
1044   ld bc,0ff05h
1047   rrca
1048   ld bc,03c00h
104B   ld a,(bc)
104C   rst 38h
104D   inc d
104E   ld a,a
104F   rrca
1050   ld bc,0010fh
1053   nop
1054   jr z,$+17
1056   rst 38h
1057   rrca
1058   ld a,a
1059   ld bc,0010ch
105C   ld bc,02800h
105F   inc c
1060   rst 38h
1061   ld a,(bc)
1062   ld a,a
1063   ld bc,0140ch
1066   ld (bc),a
1067   rst 38h
1068   inc d
1069   ld a,a
106A   ld bc,00a0ah
106D   ld a,a
106E   ei
106F   ld (bc),a
1070   djnz $-4
1072   ccf
1073   djnz $+91
1075   inc d
1076   jp m,01063h
1079   ld e,e
107A   inc b
107B   ld e,c
107C   ex af,af'
107D   jp m,0103fh
1080   ld d,a
1081   djnz $+91
1083   djnz $+87
1085   djnz $+89
1087   djnz $+91
1089   jr nz,$+98
108B   jr nz,$+91
108D   jr nz,$+98
108F   jr nz,$+91
1091   ex af,af'
1092   ld h,b
1093   ex af,af'
1094   ld e,c
1095   djnz $+91
1097   inc d
1098   jp m,01063h
109B   ld e,e
109C   inc b
109D   ld e,c
109E   ex af,af'
109F   jp m,0103fh
10A2   ld d,a
10A3   djnz $+91
10A5   djnz $+87
10A7   djnz $+89
10A9   djnz $+91
10AB   jr nz,$+103
10AD   djnz $+100
10AF   djnz $+102
10B1   djnz $+98
10B3   djnz $+100
10B5   ld b,b
10B6   ld h,l
10B7   jr nz,$+105
10B9   djnz $+103
10BB   djnz $+102
10BD   jr nz,$+98
10BF   jr nz,$+103
10C1   jr nz,$+100
10C3   djnz $+102
10C5   ex af,af'
10C6   ld h,l
10C7   ex af,af'
10C8   ld h,h
10C9   jr nz,$+98
10CB   jr nz,$+103
10CD   djnz $+105
10CF   djnz $+107
10D1   djnz $+108
10D3   djnz $+114
10D5   jr nz,$+105
10D7   jr nz,$+103
10D9   ld b,0fah
10DB   ld h,e
10DC   djnz $+105
10DE   inc b
10DF   ld h,l
10E0   ld b,0fah
10E2   ccf
10E3   djnz $+100
10E5   djnz $+102
10E7   djnz $+98
10E9   djnz $+100
10EB   ld b,b
10EC   ld sp,hl
10ED   ld l,(hl)
10EE   djnz $+1
10F0   ei
10F1   dec l
10F2   djnz $-4
10F4   ld c,a
10F5   djnz $+0
10F7   defb 0fdh,010h,082h	;illegal sequence
10FA   ld d,b
10FB   ld a,(de)
10FC   rst 38h
10FD   ei
10FE   inc de
10FF   djnz $-4
1101   ld c,a
1102   djnz $+34
1104   ld d,b
1105   rst 38h
1106   ei
1107   add hl,hl
1108   djnz $-4
110A   inc c
110B   djnz $+25
110D   inc b
110E   rst 38h
110F   ei
1110   inc de
1111   djnz $-4
1113   ccf
1114   djnz $+98
1116   rrca
1117   rst 38h
1118   jp m,0103fh
111B   ei
111C   rla
111D   djnz $+125
111F   rrca
1120   rst 38h
1121   ei
1122   ret m
1123   rrca
1124   jp m,01031h
1127   ld d,h
1128   ld a,(bc)
1129   rst 38h
112A   ei
112B   dec l
112C   djnz $-4
112E   dec de
112F   djnz $+0
1131   ld b,d
1132   ld de,0046bh
1135   ld l,e
1136   dec b
1137   ld l,e
1138   inc b
1139   ld l,e
113A   dec b
113B   ld l,e
113C   inc b
113D   ld l,e
113E   dec b
113F   ld l,e
1140   rrca
1141   rst 38h
1142   ei
1143   dec l
1144   djnz $-4
1146   dec de
1147   djnz $+120
1149   inc b
114A   halt
114B   dec b
114C   halt
114D   inc b
114E   halt
114F   dec b
1150   halt
1151   inc b
1152   halt
1153   dec b
1154   halt
1155   rrca
1156   rst 38h
1157   ei
1158   add hl,hl
1159   djnz $-4
115B   ld (08210h),hl
115E   inc d
115F   ld a,(de)
1160   rrca
1161   rrca
1162   rst 38h
1163   ei
1164   ld (bc),a
1165   djnz $-4
1167   dec (hl)
1168   djnz $+0
116A   xor (hl)
116B   ld de,01e4bh
116E   ld c,a
116F   ld bc,0b7feh
1172   ld de,02849h
1175   ld c,a
1176   inc b
1177   cp 0aeh
1179   ld de,01e4bh
117C   ld c,a
117D   ld bc,0b7feh
1180   ld de,02849h
1183   ld c,a
1184   inc b
1185   cp 0aeh
1187   ld de,01e4bh
118A   ld c,a
118B   ld bc,0b7feh
118E   ld de,02849h
1191   ld c,a
1192   inc b
1193   cp 0aeh
1195   ld de,01e4bh
1198   ld c,a
1199   ld bc,0b7feh
119C   ld de,02849h
119F   ld c,a
11A0   inc b
11A1   cp 0aeh
11A3   ld de,01e4bh
11A6   ld c,a
11A7   ld bc,0b7feh
11AA   ld de,03c49h
11AD   rst 38h
11AE   ei
11AF   ld (bc),a
11B0   djnz $-4
11B2   dec (hl)
11B3   djnz $+69
11B5   ld e,0ffh
11B7   ei
11B8   ld (bc),a
11B9   djnz $-4
11BB   dec (hl)
11BC   djnz $+69
11BE   jr z,$+1
11C0   ei
11C1   dec l
11C2   djnz $-4
11C4   ld e,c
11C5   djnz $-92
11C7   inc d
11C8   ld a,(de)
11C9   and d
11CA   inc d
11CB   ld a,(de)
11CC   and b
11CD   ld e,019h
11CF   rst 38h
11D0   ei
11D1   dec l
11D2   djnz $-4
11D4   ld e,c
11D5   djnz $-94
11D7   ld e,019h
11D9   rst 38h
11DA   nop
11DB   ld h,c
11DC   nop
11DD   nop
11DE   nop
11DF   xor h
11E0   dec d
11E1   and a
11E2   dec d
11E3   ld a,a
11E4   dec d
11E5   add a,h
11E6   dec d
11E7   adc a,c
11E8   dec d
11E9   adc a,(hl)
11EA   dec d
11EB   sub e
11EC   dec d
11ED   sbc a,b
11EE   dec d
11EF   sbc a,l
11F0   dec d
11F1   and d
11F2   dec d
11F3   inc h
11F4   rla
11F5   ld e,l
11F6   rla
11F7   push de
11F8   rla
11F9   jp c,0df17h
11FC   rla
11FD   call po,0d817h
1200   jr $+31
1202   add hl,de
1203   ld b,e
1204   add hl,de
1205   ld l,b
1206   add hl,de
1207   ld (hl),d
1208   dec de
1209   ld (hl),a
120A   dec de
120B   ld c,e
120C   inc d
120D   di
120E   inc d
120F   ld b,(hl)
1210   inc d
1211   xor 014h
1213   ld (hl),l
1214   dec d
1215   ret nc
1216   rla
1217   dec h
1218   ld a,(de)
1219   ld c,c
121A   ld a,(de)
121B   ld (hl),l
121C   ld a,(de)
121D   or l
121E   ld a,(de)
121F   call po,0ee1ah
1222   ld a,(de)
1223   pop af
1224   ld a,(de)
1225   daa
1226   dec d
1227   or 01ah
1229   inc a
122A   dec d
122B   dec l
122C   dec de
122D   ld (hl),b
122E   dec d
122F   ld l,e
1230   dec d
1231   ld h,c
1232   dec d
1233   ld l,b
1234   dec d
1235   ld e,017h
1237   adc a,016h
1239   ld (hl),e
123A   inc de
123B   ret
123C   inc de
123D   pop af
123E   inc de
123F   ei
1240   inc de
1241   ei
1242   ld a,(de)
1243   and (hl)
1244   jr $-72
1246   jr $+7
1248   inc d
1249   ld d,b
124A   dec d
124B   add a,h
124C   dec de
124D   ret m
124E   inc d
124F   ld d,b
1250   inc d
1251   ld a,(de)
1252   dec d
1253   sbc a,01ah
1255   cp e
1256   ld a,(de)
1257   jp (hl)
1258   ld a,(de)
1259   ld a,d
125A   dec d
125B   cp 014h
125D   inc c
125E   dec d
125F   adc a,(hl)
1260   dec de
1261   sub h
1262   dec de
1263   ld a,01bh
1265   ld l,h
1266   dec de
1267   cp c
1268   add hl,de
1269   adc a,e
126A   add hl,de
126B   call po,0d713h
126E   inc de
126F   rl a
1271   cp a
1272   add hl,de
1273   ret m
1274   add hl,de
1275   inc e
1276   ld a,(de)
1277   inc e
1278   ld a,(de)
1279   jp (hl)
127A   rla
127B   inc a
127C   inc d
127D   ld b,c
127E   inc d
127F   call po,0e914h
1282   inc d
1283   ex af,af'
1284   inc d
1285   inc (hl)
1286   inc d
1287   adc a,(hl)
1288   inc d
1289   cp d
128A   inc d
128B   add iy,de
128D   add a,017h
