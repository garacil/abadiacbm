; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_path_clear_grid_marks at 081E (64K)   PC: 102B   CPC 6128: 0BAE   called 28587 times by 05AB 07AB 07E0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
081E * ld bc,00240h
0821 * ld hl,(028dbh)
0824 * ld a,(hl)
0825 * and 03fh
0827 * ld (hl),a
0828 * inc hl
0829 * dec bc
082A * ld a,b
082B * or c
082C * jr nz,$-8
082E * ret
