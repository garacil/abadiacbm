; vid_fill_play_area at 16B2 (64K)   PC: 29F6   CPC 6128: 1A7D   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
16B2 * ld b,0a0h
16B4 * ld (016c0h),a
16B7 * ld hl,0c000h
16BA * push bc
16BB * push hl
16BC * ld d,h
16BD * ld e,l
16BE * inc de
16BF * ld (hl),000h
16C1 * ld bc,0003fh
16C4 * ldir
16C6 * pop hl
16C7 * call f_3558
16CA * pop bc
16CB * djnz $-17
16CD * ret
16CE   ld d,e
16CF   inc de
16D0   rst 30h
16D1   ld (hl),c
16D2   ld (bc),a
16D3   ld l,(hl)
16D4   ld l,(hl)
16D5   add a,h
16D6   ld (hl),c
16D7   rst 30h
16D8   ld (hl),b
16D9   ld bc,07084h
16DC   call m,0f8fch
16DF   ld l,c
16E0   cp 0f8h
16E2   ld l,d
16E3   jp m,0f4fbh
16E6   call m,061f8h
16E9   cp 0f8h
16EB   ld h,d
16EC   jp m,063f8h
16EF   ei
16F0   call p,0fcfdh
16F3   ret m
16F4   ld h,(hl)
16F5   cp 0f8h
16F7   ld h,h
16F8   jp m,065f8h
16FB   add a,b
16FC   ld h,e
16FD   ei
16FE   call p,0faf5h
1701   ret m
1702   ld h,(hl)
1703   cp 0f8h
1705   ld h,a
1706   jp m,068f8h
1709   ei
170A   rst 30h
170B   ld l,(hl)
170C   nop
170D   cp 0f5h
170F   or 0fch
1711   ld sp,hl
1712   ld l,c
1713   ld sp,iy
1715   ld l,d
1716   jp m,06ef7h
1719   ld bc,0fb6eh
171C   jp m,049ffh
171F   inc de
1720   jp (hl)
1721   jp pe,016d0h
1724   scf
1725   inc de
1726   rst 30h
1727   ld (hl),b
1728   ld (bc),a
1729   ld l,l
172A   ld l,l
172B   add a,h
172C   ld (hl),b
172D   rst 30h
172E   ld (hl),c
172F   ld bc,06e6eh
1732   add a,h
1733   ld (hl),c
1734   rst 28h
1735   defb 0fdh,0fch,0fch	;illegal sequence
1738   ld sp,hl
1739   ld h,c
173A   add a,b
173B   ld h,l
173C   ei
173D   di
173E   cp 0fch
1740   ld sp,hl
1741   ld h,d
1742   add a,b
1743   ld h,(hl)
1744   add a,b
1745   ld h,a
1746   ei
1747   call p,0faf3h
174A   ld sp,hl
174B   ld h,e
174C   add a,b
174D   ld l,b
174E   add a,b
174F   ld l,c
1750   ei
1751   call p,0f5f4h
1754   jp m,0f0f3h
1757   cp 0f9h
1759   ld h,h
175A   di
175B   jp m,040ffh
175E   inc de
175F   jp (hl)
1760   jp pe,01726h
1763   ld sp,03131h
1766   ex af,af'
1767   halt
1768   ld (hl),l
1769   jr z,$+43
176B   dec hl
176C   jr nc,$+12
176E   add hl,bc
176F   ex af,af'
1770   ld (hl),l
1771   halt
1772   dec hl
1773   jr nc,$+42
1775   add hl,hl
1776   add hl,bc
1777   ld a,(bc)
1778   inc b
1779   inc b
177A   inc b
177B   ld bc,04d4eh
177E   dec b
177F   ld c,a
1780   ld e,c
1781   jr z,$+43
1783   dec hl
1784   jr nc,$+12
1786   add hl,bc
1787   dec b
1788   ld e,c
1789   ld c,a
178A   dec hl
178B   jr nc,$+42
178D   add hl,hl
178E   add hl,bc
178F   ld a,(bc)
1790   add a,a
1791   adc a,b
1792   rst 8
1793   jr z,$+43
1795   dec hl
1796   jr nc,$+12
1798   add hl,bc
1799   add a,a
179A   rst 8
179B   adc a,b
179C   dec hl
179D   jr nc,$+42
179F   add hl,hl
17A0   add hl,bc
17A1   ld a,(bc)
17A2   ld sp,04445h
17A5   jr z,$+43
17A7   dec hl
17A8   jr nc,$+12
17AA   add hl,bc
17AB   ld sp,04544h
17AE   dec hl
17AF   jr nc,$+42
17B1   add hl,hl
17B2   add hl,bc
17B3   ld a,(bc)
17B4   out (09ch),a
17B6   call nc,0bad7h
17B9   ret c
17BA   ret
17BB   exx
17BC   or b
17BD   out (0d4h),a
17BF   sbc a,h
17C0   ret c
17C1   ret
17C2   rst 10h
17C3   cp d
17C4   or b
17C5   exx
17C6   ld h,e
17C7   rla
17C8   jp pe,01804h
17CB   and d
17CC   rla
17CD   jp pe,01804h
17D0   ld h,(hl)
17D1   rla
17D2   jp pe,01804h
17D5   ld a,b
17D6   rla
17D7   jp pe,01804h
17DA   ld a,e
17DB   rla
17DC   jp pe,01804h
17DF   ld a,(hl)
17E0   rla
17E1   jp pe,01804h
17E4   sub b
17E5   rla
17E6   jp pe,01804h
17E9   cp l
17EA   rla
17EB   jp pe,01804h
