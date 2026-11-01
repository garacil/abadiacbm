; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; sys_tick at 2899 (64K)   PC: 281E   CPC 6128: 2D48   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2899 * di
289A * push af
289B * ld a,000h
289D * inc a
289E * jr z,$+5
28A0 * ld (0289ch),a
28A3 * call f_0CD0
28A6 * call txt_phrase_tick
28A9 * pop af
28AA * ei
28AB * reti
