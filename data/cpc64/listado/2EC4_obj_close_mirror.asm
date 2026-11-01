; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_close_mirror at 2EC4 (64K)   PC: 2F90   CPC 6128: 34B9   called 21 times by 2168
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2EC4 * di
2EC5 * ld hl,02ee0h
2EC8 * ld de,(02edeh)
2ECC * ld bc,00005h
2ECF * ldir
2ED1 * ld a,011h
2ED3 * ld hl,(02ee5h)
2ED6 * ld (hl),a
2ED7 * dec hl
2ED8 * dec hl
2ED9 * ld a,01fh
2EDB * ld (hl),a
2EDC * ei
2EDD * ret
2EDE   nop
2EDF   nop
2EE0   push af
2EE1   jr nz,$+100
2EE3   dec bc
2EE4   rst 38h
2EE5   nop
2EE6   nop
