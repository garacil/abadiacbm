; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4B44 at 4B44 (64K)   PC: -   CPC 6128: -   called 52 times by 3E44 3E5D 3E76 3E9A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4B44 * pop ix
4B46 * ld a,(ix+000h)
4B49 * inc ix
4B4B * push ix
4B4D * cp 0ffh
4B4F * ret z
4B50 * and 07fh
4B52 * call txt_draw_char_inverted
4B55 * jr $-17
