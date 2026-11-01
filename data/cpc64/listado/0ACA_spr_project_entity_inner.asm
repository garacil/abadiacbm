; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_project_entity_inner at 0ACA (64K)   PC: 1326   CPC 6128: 0E5A   called 190360 times by 0AC1
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0ACA * call chr_project
0ACD * pop de
0ACE * ld (ix+000h),0feh
0AD2 * xor a
0AD3 * scf
0AD4 * jr $-14
