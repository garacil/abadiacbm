; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_reg_add at 1C95 (64K)   PC: 2AC0   CPC 6128: 2087   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1C95 * push bc
1C96 * call iso_operand_value
1C99 * ld a,c
1C9A * pop bc
1C9B * add a,c
1C9C * ld (de),a
1C9D * jr $-113
