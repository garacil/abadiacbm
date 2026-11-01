; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_5B21 at 5B21 (64K)   PC: -   CPC 6128: -   called 26960 times by 039A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5B21 * rst 8
5B22   add a,b
5B23   ld h,b
5B24   inc a
5B25   adc a,b
5B26   ld bc,08d3dh
5B29   ld bc,02a3dh
5B2C   ld h,020h
5B2E   inc bc
5B2F   rst 10h
5B30   adc a,h
5B31   dec bc
5B32 * rst 8
5B33   adc a,b
5B34   ld bc,0823eh
5B37   ld d,03eh
5B39   ld h,020h
5B3B   rlca
5B3C   rst 10h
5B3D   adc a,e
5B3E   add hl,bc
5B3F   rst 10h
5B40   adc a,h
5B41   dec bc
5B42   ret
5B43 * rst 8
5B44   adc a,h
5B45   dec bc
5B46   dec a
5B47 * jr nz,$+32
5B49 * rst 10h
5B4A   adc a,e
5B4B   ld b,b
5B4C   rst 38h
5B4D * call ai_guillermo_is_close
5B50 * jr nz,$+22
5B52 * rst 8
5B53   sbc a,h
5B54   ld bc,0203dh
5B57   ld bc,0cfc9h
5B5A   adc a,c
5B5B   nop
5B5C   dec a
5B5D * jr nz,$+9
5B5F * call f_4B7C
5B62   ld c,0d7h
5B64   sbc a,h
5B65   ld bc,0cfc9h
5B68   sbc a,d
5B69   dec c
5B6A   dec a
5B6B   and a
5B6C   ld h,020h
5B6E   dec d
5B6F   call ai_guillermo_is_close
5B72   jr nz,$+14
5B74   call f_4B7C
5B77   add hl,hl
5B78   rst 10h
5B79   adc a,e
5B7A   ld b,b
5B7B   rst 38h
5B7C   rst 10h
5B7D   adc a,h
5B7E   dec bc
5B7F   ret
5B80   rst 10h
5B81   adc a,e
5B82   ld (bc),a
5B83   ret
5B84 * rst 8
5B85   adc a,e
5B86   adc a,d
5B87   dec a
5B88   adc a,d
5B89   ld (bc),a
5B8A   dec a
5B8B   ld h,0a6h
5B8D   djnz $+44
5B8F   djnz $+63
5B91   ld h,020h
5B93   ld d,0d7h
5B95   or e
5B96   ld bc,0fdcdh
5B99   dec sp
5B9A   rst 8
5B9B   adc a,h
5B9C   dec d
5B9D   dec a
5B9E   and (hl)
5B9F   djnz $+44
5BA1   ld h,020h
5BA3   ld b,0d7h
5BA5   sbc a,e
5BA6   ld bc,08cd7h
5BA9   djnz $-47
5BAB   adc a,h
5BAC   dec d
5BAD   dec a
5BAE * jr nz,$+6
5BB0   rst 10h
5BB1   adc a,e
5BB2   ld (bc),a
5BB3   ret
5BB4 * rst 8
5BB5   adc a,h
5BB6   ld b,b
5BB7   add a,b
5BB8   ld a,020h
5BBA   ld (de),a
5BBB * rst 8
5BBC   adc a,c
5BBD   nop
5BBE   dec a
5BBF * jr nz,$+9
5BC1 * rst 10h
5BC2   adc a,h
5BC3   adc a,h
5BC4   ld a,a
5BC5   ld hl,(00518h)
5BC8 * rst 10h
5BC9   adc a,e
5BCA   ld b,b
5BCB   rst 38h
5BCC * ret
5BCD * rst 8
5BCE   adc a,b
5BCF   dec b
5BD0   dec a
5BD1 * jr nz,$+25
5BD3   rst 10h
5BD4   adc a,h
5BD5   dec b
5BD6   call 03f15h
5BD9   rst 10h
5BDA   adc a,e
5BDB   nop
5BDC   rst 10h
5BDD   and d
5BDE   rla
5BDF   rst 8
5BE0   adc a,l
5BE1   ld bc,0cd2dh
5BE4   defb 0ddh,05fh,0cdh	;illegal sequence
5BE7   halt
5BE8   ld h,b
5BE9   ret
5BEA * rst 8
5BEB   adc a,b
5BEC   ld bc,0203dh
5BEF   rla
5BF0   rst 10h
5BF1   adc a,h
5BF2   ld c,0cdh
5BF4   dec d
5BF5   ccf
5BF6   rst 10h
5BF7   adc a,e
5BF8   nop
5BF9   rst 10h
5BFA   and d
5BFB   rla
5BFC   rst 8
5BFD   adc a,l
5BFE   ld (bc),a
5BFF   dec l
5C00   call 06016h
5C03   call 06076h
5C06   ret
5C07 * rst 8
5C08   adc a,b
5C09   inc bc
5C0A   dec a
5C0B * jr nz,$+28
5C0D   rst 10h
5C0E   adc a,e
5C0F   ld bc,022cdh
5C12   ccf
5C13   rst 10h
5C14   adc a,h
5C15   djnz $-39
5C17   and d
5C18   add hl,de
5C19   rst 10h
5C1A   and e
5C1B   ld bc,08dcfh
5C1E   ld (bc),a
5C1F   dec l
5C20   defb 0cdh
