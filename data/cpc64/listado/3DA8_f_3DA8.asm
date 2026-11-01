; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3DA8 at 3DA8 (64K)   PC: -   CPC 6128: -   called 13 times by 3E3B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3DA8 * ld a,(037f4h)
3DAB * and a
3DAC * jp z,03de7h
3DAF * ld a,(028d1h)
3DB2 * dec a
3DB3 * ld b,a
3DB4 * add a,a
3DB5 * ld c,a
3DB6 * add a,a
3DB7 * add a,b
3DB8 * add a,c
3DB9 * ld c,a
3DBA * ld a,(028d2h)
3DBD * add a,c
3DBE * ld hl,(0290fh)
3DC1 * ld b,010h
3DC3 * add hl,hl
3DC4 * jr nc,$+4
3DC6   add a,004h
3DC8 * djnz $-5
3DCA * cp 005h
3DCC * jr nc,$+3
3DCE * xor a
3DCF * ld bc,00000h
3DD2 * ld b,a
3DD3 * sub 00ah
3DD5 * jr c,$+5
3DD7   inc c
3DD8   jr $-6
3DDA * ld a,020h
3DDC * ld hl,03030h
3DDF * add hl,bc
3DE0 * ld (03e61h),a
3DE3 * ld (03e62h),hl
3DE6 * ret
3DE7   ld bc,00000h
3DEA   ld a,031h
3DEC   jr $-16
