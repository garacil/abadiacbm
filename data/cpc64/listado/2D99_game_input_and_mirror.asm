; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; game_input_and_mirror at 2D99 (64K)   PC: 2DD8   CPC 6128: 3311   called 26973 times by 2180
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2D99 * call f_2D50
2D9C * ei
2D9D * ld a,(028ddh)
2DA0 * and a
2DA1 * ret z
2DA2 * call game_check_qr_mirror
2DA5 * ld a,e
2DA6 * and a
2DA7 * ret z
2DA8   ld a,(0290dh)
2DAB   cp 004h
2DAD   jr z,$+10
2DAF   ld hl,02910h
2DB2   set 2,(hl)
2DB4   cp e
2DB5   jr z,$+26
2DB7   ld a,001h
2DB9   ld (037e4h),a
2DBC   ld a,014h
2DBE   ld (023e4h),a
2DC1   ld a,06bh
2DC3   ld hl,(02ee5h)
2DC6   dec hl
2DC7   dec hl
2DC8   ld (hl),a
2DC9   call f_4B71
2DCC   ld (00e18h),hl
2DCF   di
2DD0   ld a,0ffh
2DD2   ld hl,(02edeh)
2DD5   ld (hl),a
2DD6   ld a,051h
2DD8   ld hl,(02ee5h)
2DDB   ld (hl),a
2DDC   ei
2DDD   xor a
2DDE   ld (028c6h),a
2DE1   ld (028ddh),a
2DE4   call snd_stub_mirror_open
2DE7   ret
2DE8   rst 38h
2DE9   rst 38h
2DEA   rst 38h
2DEB   rst 38h
2DEC   rst 38h
2DED   rst 38h
2DEE   rst 38h
2DEF   rst 38h
2DF0   rst 38h
2DF1   rst 38h
2DF2   rst 38h
2DF3   rst 38h
2DF4   rst 38h
2DF5   rst 38h
2DF6   rst 38h
2DF7   rst 38h
2DF8   rst 38h
2DF9   rst 38h
2DFA   rst 38h
2DFB   rst 38h
