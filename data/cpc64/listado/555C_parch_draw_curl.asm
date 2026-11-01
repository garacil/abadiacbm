; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; parch_draw_curl at 555C (64K)   PC: 0A86   CPC 6128: 6906   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
555C   dec b
555D   ret
555E   rst 10h
555F   sub b
5560   ld b,b
5561   defb 0fdh,0cfh,0a8h	;illegal sequence
5564   ld b,b
5565   add a,b
5566   ld hl,(08040h)
5569   dec a
556A   jr nz,$+14
556C   rst 8
556D   sub c
556E   ld b,03dh
5570   jr nz,$+5
5572   rst 10h
5573   sbc a,e
5574   ld bc,090d7h
5577   ld b,0c9h
5579   rst 8
557A   sub c
557B   inc bc
557C   dec a
557D   jr nz,$+9
557F   rst 10h
5580   sub d
5581   ld b,0cdh
5583   ret c
5584   dec sp
5585   ret
5586   rst 10h
5587   sub b
5588   inc bc
5589   ret
558A * rst 8
558B   adc a,b
558C   dec b
558D   dec a
558E * jr nz,$+22
5590   rst 8
5591   adc a,l
5592   ld (bc),a
5593   dec a
5594   adc a,(hl)
5595   inc b
5596   inc a
5597   ld h,020h
5599   inc bc
559A   jp 039a8h
559D   rst 10h
559E   sub d
559F   ld bc,090d7h
55A2   nop
55A3   ret
55A4 * rst 8
55A5   adc a,l
55A6   inc bc
55A7   inc a
55A8 * jp nz,05682h
55AB * rst 8
55AC   sub d
55AD   inc b
55AE   dec a
55AF * jr nz,$+35
55B1   rst 10h
55B2   sbc a,c
55B3   sbc a,c
55B4   ld bc,0cf2bh
55B7   sbc a,c
55B8   ld b,c
55B9   inc a
55BA   sbc a,d
55BB   ld b,b
55BC   ld b,b
55BD   dec a
55BE   ld h,020h
55C0   ld a,(bc)
55C1   rst 8
55C2   and h
55C3   djnz $+44
55C5   jr nz,$+5
55C7   rst 10h
55C8   sub d
55C9   nop
55CA   ret
55CB   rst 10h
55CC   sub d
55CD   dec b
55CE   call 03ee6h
55D1   ret
55D2 * rst 8
55D3   sub d
55D4   dec b
55D5   dec a
55D6 * jr nz,$+29
55D8   rst 10h
55D9   sub b
55DA   ld b,b
55DB   cp 0cfh
55DD   sub c
55DE   ld b,b
55DF   cp 03dh
55E1   jr nz,$+17
55E3   rst 10h
55E4   sbc a,c
55E5   ld b,b
55E6   ret
55E7   rst 10h
55E8   sub d
55E9   nop
55EA   rst 10h
55EB   and l
55EC   ld bc,0aed7h
55EF   xor (hl)
55F0   ld bc,0c926h
55F3 * rst 8
55F4   sub c
55F5   ld (bc),a
55F6   dec a
55F7 * jr nz,$+31
55F9 * call f_3F56
55FC * jr nz,$+26
55FE   rst 10h
55FF   sbc a,c
5600   nop
5601   rst 10h
5602   sub d
5603   inc b
5604   call ai_guillermo_is_close
5607   jr nz,$+8
5609   call f_4B7C
560C   inc b
560D   jr $+8
560F   rst 10h
5610   sub d
5611   dec b
5612   call 03ee6h
5615   ret
5616 * rst 8
5617   xor (hl)
5618   ld b,b
5619   ld b,b
561A   ld hl,(04040h)
561D   dec a
561E   add a,d
561F   dec c
5620   ld a,026h
5622 * jr nz,$+89
5624   rst 8
5625   xor (hl)
5626   djnz $+44
5628   jr nz,$+39
562A   rst 10h
562B   sub b
562C   ld b,b
562D   rst 38h
562E   call ai_guillermo_is_close
5631   jr nz,$+27
5633   rst 8
5634   adc a,c
5635   nop
5636   dec a
5637   jr nz,$+18
5639   rst 10h
563A   sub c
563B   ld b,b
563C   rst 38h
563D   call chr_cmd_discard
5640   rst 10h
5641   xor (hl)
5642   xor (hl)
5643   djnz $+40
5645   call f_4B7C
5648   dec (hl)
5649   jp 039a8h
564C   ret
564D   jr $+46
564F   rst 8
5650   xor (hl)
5651   ex af,af'
5652   ld hl,(02620h)
5655   rst 10h
5656   sub b
5657   ld (bc),a
5658   call ai_guillermo_is_close
565B   jr nz,$+20
565D   rst 8
565E   sub c
565F   ld (bc),a
5660   dec a
5661   adc a,c
5662   ld h,020h
5664   add hl,bc
5665   rst 10h
5666   xor (hl)
5667   xor (hl)
5668   ex af,af'
5669   ld h,0cdh
566B   ld a,h
566C   ld c,e
566D   ld (hl),0c9h
566F   rst 8
5670   sub c
5671   ld (bc),a
5672   dec a
5673   jr nz,$+8
5675   rst 10h
5676   xor (hl)
5677   xor (hl)
5678   ld b,b
5679   add a,b
567A   ld h,0d7h
567C   sub d
567D   nop
567E * rst 10h
567F   sub b
5680   ld (bc),a
5681 * ret
5682   rst 8
5683   sub d
5684   inc d
5685   dec a
5686   jr nz,$+14
5688   rst 8
5689   sub b
568A   sub c
568B   dec a
568C   jr nz,$+7
568E   rst 10h
568F   sub b
5690   or d
5691   inc bc
5692   ld hl,(0cfc9h)
5695   adc a,l
5696   inc b
5697   dec a
5698   jp nz,0571bh
569B   rst 8
569C   sub b
569D   ld b,b
569E   cp 03dh
56A0   and (hl)
56A1   djnz $+44
56A3   djnz $+63
56A5   ld h,020h
56A7   ld a,(bc)
56A8   rst 10h
56A9   sub d
56AA   inc d
56AB   rst 10h
56AC   sub b
56AD   ld bc,08cd7h
56B0   dec d
56B1   ret
56B2   rst 8
56B3   xor b
56B4   djnz $+44
56B6   djnz $+63
56B8   jr nz,$+13
56BA   rst 10h
56BB   sub b
56BC   ld b,b
56BD   cp 0cdh
56BF   and 03eh
56C1   rst 10h
56C2   or b
56C3   nop
56C4   ret
56C5   rst 8
56C6   or e
56C7   ld bc,0a63dh
56CA   djnz $+44
56CC   djnz $+63
56CE   ld hl,(00b8ch)
56D1   dec a
56D2   ld hl,(00720h)
56D5   rst 10h
56D6   sub b
56D7   ld (bc),a
56D8   rst 10h
56D9   sub d
56DA   inc d
56DB   ret
56DC   rst 10h
56DD   or e
56DE   nop
56DF   call 03ee6h
56E2   rst 8
56E3   and h
56E4   djnz $+44
56E6   djnz $+63
56E8   jr nz,$+47
56EA   rst 8
56EB   sub d
56EC   rlca
56ED   dec a
56EE   jr nz,$+26
56F0   rst 10h
56F1   sub b
56F2   ld b,b
56F3   rst 38h
56F4   call ai_guillermo_is_close
56F7   jr nz,$+15
56F9   rst 8
56FA   adc a,c
56FB   nop
56FC   dec a
56FD   jr nz,$+9
56FF   call f_4B7C
5702   dec b
5703   call f_5124
5706   jr $+15
5708   call ai_guillermo_is_close
570B   jr nz,$+6
570D   rst 10h
570E   sub b
570F   inc bc
5710   ret
5711   rst 10h
5712   sub d
5713   rlca
5714   ret
5715   jr $+6
5717   rst 10h
5718   sub b
5719   ld b,b
571A   defb 0fch,0c9h
