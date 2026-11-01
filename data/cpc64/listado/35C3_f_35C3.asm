; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_35C3 at 35C3 (64K)   PC: -   CPC 6128: -   called 8 times by 3592
; '*' = executed in the exploration sessions; the listing runs to the next known entry
35C3 * ld hl,09f60h
35C6 * call chr_hbuf_skip_list
35C9 * ld (02edeh),hl
35CC * ld b,072h
35CE * ld hl,06100h
35D1 * ld a,(hl)
35D2 * add a,l
35D3 * ld l,a
35D4 * adc a,h
35D5 * sub l
35D6 * ld h,a
35D7 * djnz $-6
35D9 * ld b,000h
35DB * ld a,(hl)
35DC * inc hl
35DD * cp 01fh
35DF * jr nz,$+22
35E1 * ld a,(hl)
35E2 * inc hl
35E3 * ld c,(hl)
35E4 * dec hl
35E5 * cp 0aah
35E7 * jr nz,$+14
35E9 * ld a,c
35EA * cp 051h
35EC * jr nz,$+9
35EE * inc hl
35EF * ld (hl),011h
35F1 * ld (02ee5h),hl
35F4 * ret
35F5 * djnz $-26
35F7   ret
