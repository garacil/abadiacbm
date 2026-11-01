; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; game_update_camera_and_bonus at 42FA (64K)   PC: 3F72   CPC 6128: 5691   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
42FA * exx
42FB * jr $+12
42FD * dec (iy+004h)
4300 * ld a,090h
4302 * exx
4303 * ld hl,03f8ch
4306 * exx
4307 * ld (iy+005h),a
430A * push hl
430B * call chr_apply_step
430E * pop hl
430F * call chr_orientation_parity
4312 * call nz,chr_apply_step
4315 * jr $+11
4317 * sub c
4318 * inc a
4319 * cp 003h
431B * jr $+2
431D * call chr_apply_step
4320 * exx
4321 * ld d,(hl)
4322 * inc hl
4323 * ld e,(hl)
4324 * inc hl
4325 * ld b,(hl)
4326 * ex de,hl
4327 * call chr_cmd_write_bits
432A * exx
432B * ret
