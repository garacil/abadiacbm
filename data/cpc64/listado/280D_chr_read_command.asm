; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_read_command at 280D (64K)   PC: 277A   CPC 6128: 2CB8   called 30221 times by 27A1
; '*' = executed in the exploration sessions; the listing runs to the next known entry
280D * bit 7,(iy+005h)
2811 * jr z,$+15
2813 * call chr_command_bit
2816 * jr nc,$+13
2818 * call chr_command_bit
281B * ld c,000h
281D * rl c
281F * ret
2820 * call chr_command_bit
2823 * ld c,001h
2825 * ret c
2826 * call chr_command_bit
2829 * jr nc,$+8
282B * call chr_command_bit
282E * rl c
2830 * ret
2831 * rl c
2833 * call chr_command_bit
2836 * jr c,$-11
2838 * call chr_command_bit
283B * jr c,$+19
283D   ld c,000h
283F   bit 7,(iy+005h)
2843   ret nz
2844   ld (iy+00bh),000h
2848   ld (iy+009h),000h
284C   jr $-63
284E * set 7,(iy+009h)
2852 * pop hl
2853 * pop hl
2854 * ret
