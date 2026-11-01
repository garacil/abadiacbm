; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_0CD0 at 0CD0 (64K)   PC: -   CPC 6128: -   called 893376 times by 28A3
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0CD0 * di
0CD1 * push af
0CD2 * ld a,(00c1eh)
0CD5 * push bc
0CD6 * ld c,a
0CD7 * ld a,(00c36h)
0CDA * or c
0CDB * ld c,a
0CDC * ld a,(00c4eh)
0CDF * or c
0CE0 * and 001h
0CE2 * jr nz,$+7
0CE4 * pop bc
0CE5 * pop af
0CE6 * ei
0CE7 * reti
0CE9 * push hl
0CEA * push de
0CEB * push ix
0CED * ld a,(00c08h)
0CF0 * dec a
0CF1 * cp 0ffh
0CF3 * jr nz,$+4
0CF5 * ld a,006h
0CF7 * ld (00c08h),a
0CFA * ld a,03fh
0CFC * ld (00c06h),a
0CFF * ld ix,00c10h
0D03 * call f_0DBC
0D06 * ld ix,00c28h
0D0A * call f_0DBC
0D0D * ld ix,00c40h
0D11 * call f_0DBC
0D14 * ld ix,00c10h
0D18 * call f_0D40
0D1B * ld ix,00c28h
0D1F * call f_0D40
0D22 * ld ix,00c40h
0D26 * call f_0D40
0D29 * ld hl,(00c06h)
0D2C * ld a,l
0D2D * cp h
0D2E * jr z,$+11
0D30 * ld (00c07h),a
0D33 * ld c,a
0D34 * ld a,007h
0D36 * call snd_stub_psg_write
0D39 * pop ix
0D3B * pop de
0D3C * pop hl
0D3D * jp 00ce4h
