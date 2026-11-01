; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_1D26 at 1D26 (64K)   PC: -   CPC 6128: -   called 19342 times by 1D21
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1D26 * call iso_put_tile
1D29 * dec h
1D2A * ret
1D2B * cp 081h
1D2D * jr nz,$+7
1D2F * call iso_put_tile
1D32 * jr $-33
1D34   push bc
1D35   call f_1E22
1D38   ld a,c
1D39   pop bc
1D3A   and a
1D3B   call nz,iso_put_tile_times
1D3E   ld a,(ix+000h)
1D41   cp 0c8h
1D43   ret nc
1D44   inc ix
1D46   jr $-53
