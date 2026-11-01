; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_put_tile at 1295 (64K)   PC: 28A7   CPC 6128: 1633   called 64240 times by 1D26 1D2F
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1295 * ld a,h
1296 * sub 008h
1298 * cp 014h
129A * ret nc
129B * ld d,a
129C * ld a,l
129D * sub 008h
129F * cp 010h
12A1 * ret nc
12A2 * ld e,a
12A3 * push hl
12A4 * ex de,hl
12A5 * ld a,l
12A6 * ld l,h
12A7 * ld h,000h
12A9 * add hl,hl
12AA * add hl,hl
12AB * add hl,hl
12AC * add hl,hl
12AD * add hl,hl
12AE * ld e,l
12AF * ld d,h
12B0 * add hl,hl
12B1 * add hl,de
12B2 * add a,a
12B3 * ld e,a
12B4 * add a,a
12B5 * add a,e
12B6 * add a,l
12B7 * ld l,a
12B8 * adc a,h
12B9 * sub l
12BA * ld h,a
12BB * ld de,08780h
12BE * add hl,de
12BF * jp 012c9h
12C2   ld de,00780h
12C5   add hl,de
12C6   ld (hl),c
12C7   pop hl
12C8   ret
12C9 * push bc
12CA * push hl
12CB * inc hl
12CC * inc hl
12CD * ld d,h
12CE * ld e,l
12CF * inc hl
12D0 * ld c,(hl)
12D1 * inc hl
12D2 * ld b,(hl)
12D3 * inc hl
12D4 * ld a,(hl)
12D5 * ld (de),a
12D6 * inc de
12D7 * ld hl,01bech
12DA * ld a,(hl)
12DB * ld (de),a
12DC * cp c
12DD * jr nc,$+10
12DF * inc hl
12E0 * ld a,(hl)
12E1 * dec hl
12E2 * cp b
12E3 * jr nc,$+4
12E5 * ld b,a
12E6 * ld c,(hl)
12E7 * inc hl
12E8 * inc de
12E9 * ld a,(hl)
12EA * ld (de),a
12EB * inc de
12EC * pop hl
12ED * ld (hl),c
12EE * inc hl
12EF * ld (hl),b
12F0 * ex de,hl
12F1 * pop bc
12F2 * ld (hl),c
12F3 * pop hl
12F4 * ret
12F5   ld hl,(0282ch)
12F8   add hl,bc
12F9   add hl,hl
12FA   nop
12FB   dec hl
12FC   ld a,(bc)
12FD   jr nc,$+2
12FF   inc hl
1300   ld (02961h),hl
1303   ld h,025h
1305   daa
1306   jr nc,$+100
1308   ld (bc),a
1309   ld h,e
130A   inc bc
130B   ld l,d
130C   ld b,074h
130E   rlca
130F   inc hl
1310   ld (02921h),hl
1313   ld h,025h
1315   inc h
1316   jr nc,$+57
1318   ld (hl),035h
131A   nop
131B   inc (hl)
131C   inc sp
131D   ld (09900h),a
1320   sbc a,d
1321   sub a
1322   sbc a,b
1323   ld a,a
1324   ld a,(hl)
1325   ld a,l
1326   nop
1327   ld e,b
1328   ld d,a
1329   ld d,(hl)
132A   nop
132B   ld b,c
132C   rla
132D   ld d,01ah
132F   inc d
1330   dec e
1331   ld e,040h
1333   dec d
1334   rra
1335   jr nz,$+27
1337   ld (de),a
1338   or d
1339   or d
133A   ld b,l
133B   inc de
133C   or h
133D   or l
133E   or e
133F   or c
1340   djnz $-125
1342   add a,c
1343   ld b,h
1344   ld de,08483h
1347   add a,d
1348   add a,b
1349   inc e
134A   dec de
134B   cp b
134C   or a
134D   rrca
134E   cp c
134F   or (hl)
1350   cp e
1351   jr z,$+11
1353   ld l,e
1354   ld l,c
1355   ld l,h
1356   ld c,0adh
1358   xor h
1359   xor a
135A   xor (hl)
135B   dec hl
135C   ld a,(bc)
135D   ld e,b
135E   jr z,$+83
1360   ld d,e
1361   ld d,a
1362   ld d,l
1363   ld d,h
1364   ld d,b
1365   ld d,d
1366   dec hl
1367   ld a,(bc)
1368   ld a,a
1369   dec hl
136A   ld a,b
136B   ld a,d
136C   ld a,(hl)
136D   ld a,h
136E   ld a,e
136F   ld (hl),a
1370   ld a,c
1371   jr z,$+11
1373   ld e,l
1374   inc de
1375   call m,001f2h
1378   ld l,l
1379   add a,h
137A   pop af
137B   ld l,l
137C   rst 30h
137D   ld (hl),b
137E   ld (bc),a
137F   add a,h
1380   ld (hl),b
1381   rst 30h
1382   ld (hl),c
1383   inc bc
1384   ld l,l
1385   ld l,l
1386   add a,h
1387   ld (hl),c
1388   call m,06af9h
138B   ld sp,iy
138D   ld l,e
138E   jp m,0f5fbh
1391   ld sp,hl
1392   ld h,c
1393   ld sp,iy
1395   ld h,l
1396   jp m,068f9h
1399   add a,b
139A   ld h,e
139B   add a,b
139C   ld l,c
139D   ei
139E   rst 28h
139F   rst 30h
13A0   ld (hl),c
13A1   ld (bc),a
13A2   ld l,l
13A3   ld l,l
13A4   ld (hl),c
13A5   ld sp,hl
13A6   ld h,c
13A7   ld sp,iy
13A9   ld h,l
13AA   jp m,066f9h
13AD   add a,b
13AE   ld h,a
13AF   rst 30h
13B0   ld (hl),b
13B1   ld (bc),a
13B2   ld (hl),b
13B3   rst 30h
13B4   ld (hl),c
13B5   ld l,l
13B6   ld l,l
13B7   add a,h
13B8   ld (hl),c
13B9   or 0f6h
13BB   push af
13BC   cp 0fch
13BE   ld sp,hl
13BF   ld h,d
13C0   add a,b
13C1   ld h,e
13C2   add a,b
13C3   ld h,h
13C4   ei
13C5   push af
13C6   call p,0fffah
13C9   ld l,b
13CA   inc de
13CB   call m,001f2h
13CE   ld l,l
13CF   add a,h
13D0   pop af
13D1   ld l,l
13D2   add a,h
13D3   jp (hl)
13D4   jp pe,0137ch
13D7   rlca
13D8   inc de
13D9   call pe,0157fh
13DC   pop af
13DD   ld l,(hl)
13DE   ld l,(hl)
13DF   ld bc,084ech
13E2   dec d
13E3   rst 38h
13E4   rst 30h
13E5   ld (de),a
13E6   call pe,015ach
13E9   pop af
13EA   ld l,(hl)
13EB   ld l,(hl)
13EC   ld bc,0a7ech
13EF   dec d
13F0   rst 38h
13F1   ei
13F2   ld (de),a
13F3   call pe,015a7h
13F6   push af
13F7   call pe,015ach
13FA   rst 38h
13FB   dec bc
13FC   inc de
13FD   call pe,01584h
1400   push af
1401   call pe,0157fh
1404   rst 38h
1405   ld h,(hl)
1406   rla
1407   rst 38h
1408   ld a,(hl)
1409   rla
140A   call pe,0143ch
140D   rst 30h
140E   ld (hl),b
140F   ld (bc),a
1410   add a,h
1411   ld (hl),b
1412   rst 30h
1413   ld (hl),c
1414   ld bc,07184h
1417   jp p,0016dh
141A   add a,h
141B   ld sp,hl
141C   ld h,c
141D   pop af
141E   ld bc,06d84h
1421   jp p,06d6dh
1424   ld (bc),a
1425   call pe,014deh
1428   push af
1429   or 0f7h
142B   ld l,(hl)
142C   ld l,l
142D   rst 30h
142E   ld l,l
142F   nop
1430   call pe,0175dh
1433   rst 38h
1434   and d
1435   rla
1436   call pe,01441h
1439   jp pe,0140dh
143C   ld a,(hl)
143D   rla
143E   jp pe,01452h
1441   and d
1442   rla
1443   jp pe,01452h
1446   cp l
1447   rla
1448   jp pe,01452h
144B   ld h,(hl)
144C   rla
144D   jp pe,01452h
1450   sub b
1451   rla
1452   rst 30h
1453   ld (hl),c
1454   ld (hl),c
1455   add a,d
1456   rst 38h
1457   rst 30h
1458   ld (hl),b
1459   ld l,(hl)
145A   ld l,(hl)
145B   ld (bc),a
145C   add a,h
145D   ld (hl),b
145E   call m,064f9h
1461   cp 0f9h
1463   ld l,c
1464   jp m,061f9h
1467   add a,c
1468   ld h,l
1469   add a,b
146A   ld h,d
146B   ei
146C   di
146D   defb 0fdh,0fch,0f9h	;illegal sequence
1470   ld h,(hl)
1471   cp 0f9h
1473   ld l,b
1474   jp m,061f9h
1477   add a,c
1478   ld h,a
1479   add a,b
147A   ld h,c
147B   add a,b
147C   ld h,d
147D   ei
147E   di
147F   call p,0f9fah
1482   ld h,(hl)
1483   cp 0f9h
1485   ld l,b
1486   jp m,061f9h
1489   add a,c
148A   ld h,a
148B   add a,b
148C   ld h,e
148D   rst 38h
148E   add a,a
148F   rla
1490   call pe,014e4h
1493   rst 30h
1494   ld (hl),c
1495   ld (bc),a
1496   add a,h
1497   ld (hl),c
1498   rst 30h
1499   ld (hl),b
149A   ld bc,07084h
149D   jp p,06d01h
14A0   add a,h
14A1   ld sp,hl
14A2   ld h,c
14A3   pop af
14A4   ld l,l
14A5   add a,h
14A6   ld bc,06df2h
14A9   ld l,l
14AA   ld (bc),a
14AB   call pe,014c2h
14AE   di
14AF   or 0f7h
14B1   ld l,(hl)
14B2   ld l,l
14B3   rst 30h
14B4   ld l,l
14B5   nop
14B6   call pe,01724h
14B9   rst 38h
14BA   xor e
14BB   rla
14BC   call pe,014e9h
14BF   jp pe,01493h
14C2   rst 30h
14C3   ld (de),a
14C4   rst 30h
14C5   ld (hl),c
14C6   ld l,l
14C7   ld l,l
14C8   add a,h
14C9   ld (hl),c
14CA   rst 30h
14CB   ld l,(hl)
14CC   ld bc,0fcfeh
14CF   ld sp,hl
14D0   ld h,c
14D1   ld sp,iy
14D3   ld h,d
14D4   jp m,06ef7h
14D7   ld bc,0fb6eh
14DA   push af
14DB   call p,0fffah
14DE   ei
14DF   ld (de),a
14E0   jp (hl)
14E1   jp pe,014c4h
14E4   add a,a
14E5   rla
14E6   jp pe,014fah
14E9   xor e
14EA   rla
14EB   jp pe,014fah
14EE   or h
14EF   rla
14F0   jp pe,014fah
14F3   ld l,a
14F4   rla
14F5   jp pe,014fah
14F8   sbc a,c
14F9   rla
14FA   jp (hl)
14FB   jp pe,01452h
14FE   ei
14FF   ld (de),a
1500   push af
1501   call pe,015ach
1504   di
1505   rst 30h
1506   ld l,(hl)
1507   nop
1508   call pe,015a7h
150B   rst 38h
150C   rst 30h
150D   ld (de),a
150E   di
150F   call pe,015a7h
1512   push af
1513   rst 30h
1514   ld l,(hl)
1515   nop
1516   call pe,015ach
1519   rst 38h
151A   sub b
151B   rla
151C   rst 30h
151D   ld l,l
151E   ld l,l
151F   ld l,(hl)
1520   rst 30h
1521   ld l,(hl)
1522   nop
1523   call pe,014f8h
1526   rst 38h
1527   rla
1528   inc de
1529   call pe,01534h
152C   rst 30h
152D   ld l,(hl)
152E   nop
152F   di
1530   call pe,01598h
1533   rst 38h
1534   rla
1535   inc de
1536   rst 30h
1537   ld l,l
1538   nop
1539   jp pe,01603h
153C   rla
153D   inc de
153E   call pe,01534h
1541   jp p,0846eh
1544   ld l,l
1545   pop af
1546   ld bc,06d6eh
1549   rst 30h
154A   ld l,(hl)
154B   nop
154C   call pe,01598h
154F   rst 38h
1550   rla
1551   inc de
1552   call pe,01534h
1555   jp p,0016dh
1558   pop af
1559   ld l,l
155A   rst 30h
155B   ld l,(hl)
155C   nop
155D   call pe,01598h
1560   rst 38h
1561   push af
1562   ld (de),a
1563   ld sp,hl
1564   ld h,c
1565   add a,b
1566   ld h,d
1567   rst 38h
1568   inc bc
1569   inc de
156A   rst 38h
156B   inc bc
156C   inc de
156D   jp pe,015e2h
1570   rst 38h
1571   ld (de),a
1572   jp pe,015c9h
1575   inc hl
1576   inc de
1577   jp pe,015c5h
157A   daa
157B   inc de
157C   jp pe,015aeh
157F   rlca
1580   inc de
1581   jp pe,015e6h
1584   dec bc
1585   inc de
1586   jp pe,015ffh
1589   rrca
158A   inc de
158B   jp pe,015c9h
158E   inc de
158F   inc de
1590   jp pe,015e2h
1593   rla
1594   inc de
