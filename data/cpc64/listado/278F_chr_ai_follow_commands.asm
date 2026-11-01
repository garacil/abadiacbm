; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_ai_follow_commands at 278F (64K)   PC: 26D6   CPC 6128: 2C3A   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
278F * bit 7,(iy+009h)
2793 * ret nz
2794 * call chr_step_table
2797 * ld de,00006h
279A * add hl,de
279B * push hl
279C * call chr_backup_args
279F * ldir
27A1 * call chr_read_command
27A4 * pop hl
27A5 * ld a,c
27A6 * ld c,001h
27A8 * cp 003h
27AA * jp z,chr_turn
27AD * ld c,0ffh
27AF * cp 002h
27B1 * jp z,chr_turn
27B4 * bit 7,(iy+005h)
27B8 * jr nz,$+20
27BA * cp 001h
27BC * jr nz,$+6
27BE * xor a
27BF * jp 027f5h
27C2 * cp 005h
27C4 * ld a,0ffh
27C6 * jr z,$+47
27C8 * ld a,001h
27CA * jr $+43
27CC * and a
27CD * jr nz,$+18
27CF * bit 5,(iy+005h)
27D3 * jr z,$+6
27D5 * xor a
27D6 * ld c,a
27D7 * jr $+30
27D9 * ld c,002h
27DB * ld a,001h
27DD * jr $+24
27DF * cp 001h
27E1 * jr nz,$+8
27E3   ld c,0feh
27E5   ld a,0ffh
27E7   jr $+14
27E9 * cp 004h
27EB * jr nz,$+7
27ED * ld c,001h
27EF * ld a,c
27F0 * jr $+5
27F2 * ld c,0ffh
27F4 * ld a,c
27F5 * ld b,a
27F6 * xor a
27F7 * ld (02912h),a
27FA * ld a,b
27FB * call chr_probe_ahead
27FE * call chr_try_advance
2801 * ld a,(02912h)
2804 * and a
2805 * ret nz
2806 * call chr_backup_args
2809 * ex de,hl
280A * ldir
280C * ret
