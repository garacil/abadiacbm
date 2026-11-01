; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; ai_guillermo_is_close at 39AE (64K)   PC: 5CBC   CPC 6128: 3E61   called 37925 times by 5402 5B4D 5DC2 5DD9
; '*' = executed in the exploration sessions; the listing runs to the next known entry
39AE * ld a,(02b8bh)
39B1 * call iso_floor_base
39B4 * ld l,b
39B5 * ld a,(iy+004h)
39B8 * call iso_floor_base
39BB * ld a,b
39BC * cp l
39BD * ret nz
39BE * ld a,(iy+001h)
39C1 * add a,a
39C2 * add a,a
39C3 * ld hl,038ech
39C6 * call util_add_bx_al
39C9 * ld a,(02b89h)
39CC * add a,(hl)
39CD * inc hl
39CE * sub (iy+002h)
39D1 * cp (hl)
39D2 * jr nc,$+16
39D4 * inc hl
39D5 * ld a,(02b8ah)
39D8 * add a,(hl)
39D9 * inc hl
39DA * sub (iy+003h)
39DD * cp (hl)
39DE * jr nc,$+4
39E0 * xor a
39E1 * ret
39E2 * or 0ffh
39E4 * ret
39E5   ld a,(ix-001h)
39E8   cp (ix-003h)
39EB   ret nz
39EC   inc (ix-002h)
39EF   xor a
39F0   ret
