; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_step_table at 22D8 (64K)   PC: 2189   CPC 6128: 2783   called 102661 times by 2343 2794
; '*' = executed in the exploration sessions; the listing runs to the next known entry
22D8 * ld hl,023a2h
22DB * bit 7,(iy+005h)
22DF * jr z,$+5
22E1 * ld hl,023c2h
22E4 * defb 0fdh,07eh,001h
