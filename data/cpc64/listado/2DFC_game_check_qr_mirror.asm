; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; game_check_qr_mirror at 2DFC (64K)   PC: 2EAB   CPC 6128: 33F1   called 26973 times by 2DA2
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2DFC * ld e,000h
2DFE * ld ix,02b87h
2E02 * ld a,(ix+002h)
2E05 * cp 022h
2E07 * ret nz
2E08   ld a,(ix+004h)
2E0B   cp 01ah
2E0D   ret nz
2E0E   ld a,043h
2E10   call sys_key_down
2E13   ret z
2E14   ld a,032h
2E16   call sys_key_down
2E19   ret z
2E1A   ld a,(ix+003h)
2E1D   inc e
2E1E   cp 06dh
2E20   ret z
2E21   inc e
2E22   cp 069h
2E24   ret z
2E25   inc e
2E26   cp 065h
2E28   ret z
2E29   ld e,000h
2E2B   ret
2E2C   nop
2E2D   rst 38h
2E2E   ex af,af'
2E2F   dec h
2E30   ld c,d
2E31   rst 38h
2E32   cpl
2E33   cpl
2E34   ld c,c
2E35   rst 38h
2E36   nop
2E37   ld b,l
2E38   ld c,b
2E39   rst 38h
2E3A   ld bc,04b24h
2E3D   rst 38h
2E3E   ld (bc),a
2E3F   ld b,a
2E40   ld c,l
2E41   rst 38h
