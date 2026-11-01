; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_path_clear_room_marks at 0713 (64K)   PC: 0F02   CPC 6128: 0AA3   called 3583 times by 0740
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0713 * ld hl,0023dh
0716 * ld bc,00130h
0719 * ld a,(hl)
071A * and 03fh
071C * ld (hl),a
071D * inc hl
071E * dec bc
071F * ld a,b
0720 * or c
0721 * jr nz,$-8
0723 * ret
