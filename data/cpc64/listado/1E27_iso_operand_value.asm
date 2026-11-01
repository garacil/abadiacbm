; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_operand_value at 1E27 (64K)   PC: 2C88   CPC 6128: 2219   called 18257 times by 1C96 1CA1 1CAE
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1E27 * ld de,01bddh
1E2A * cp 060h
1E2C * jr c,$+27
1E2E * cp 082h
1E30 * jr nz,$+9
1E32 * ld a,(ix+000h)
1E35 * inc ix
1E37 * jr $+16
1E39 * cp 070h
1E3B * jr c,$+4
1E3D * xor 000h
1E3F * sub 061h
1E41 * add a,e
1E42 * ld e,a
1E43 * adc a,d
1E44 * sub e
1E45 * ld d,a
1E46 * ld a,(de)
1E47 * ld c,a
1E48 * and a
1E49 * ret
1E4A   nop
1E4B   di
1E4C   ld bc,07fc6h
1E4F   ld hl,(02edeh)
1E52   ld (hl),0ffh
1E54   ld bc,07fc0h
1E57   call snd_silence_if_idle
1E5A   ld sp,(02913h)
1E5E   ld a,0c9h
1E60   ld (00038h),a
1E63   call f_1E6E
1E66   ld bc,00228h
1E69   ld l,006h
1E6B   add hl,de
1E6C   rst 38h
1E6D   ret
