; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_rotate_cam3 at 20B8 (64K)   PC: 1EC5   CPC 6128: 2494   called 2775 times by 2655
; '*' = executed in the exploration sessions; the listing runs to the next known entry
20B8 * ld a,028h
20BA * sub l
20BB * ld l,h
20BC * ld h,a
20BD * ret
20BE * di
20BF * ld a,(000feh)
20C2 * cp 00dh
20C4 * call nz,f_3568
20C7 * di
20C8 * call f_1E6E
20CB   ld bc,00220h
20CE   dec hl
20CF   ld b,018h
20D1   rst 38h
20D2 * call snd_silence_if_idle
20D5 * call f_2D50
20D8 * ld a,02fh
20DA * call sys_key_down
20DD * jr nz,$-22
20DF * call game_init_new_game
20E2 * call f_22D4
20E5 * ld a,006h
20E7 * ld (00cf6h),a
20EA * ld a,0c3h
20EC * ld (00038h),a
20EF * ld (04afch),a
20F2 * ld (00008h),a
20F5 * ld (00010h),a
20F8 * ld hl,02899h
20FB * ld (00039h),hl
20FE * ld hl,0391eh
2101 * ld (00009h),hl
2104 * ld hl,038fch
2107 * ld (00011h),hl
210A * ld a,(0bf49h)
210D * ld (021dah),a
2110 * ld hl,(0bf50h)
2113 * ld (02b89h),hl
2116 * inc h
2117 * inc h
2118 * dec l
2119 * dec l
211A * ld (02b98h),hl
211D * ld a,(0bf52h)
2120 * ld (02b8bh),a
2123 * ld (02b9ah),a
2126 * ld hl,0ab59h
2129 * ld de,0ae2eh
212C * push de
212D * ld bc,002d5h
2130 * ldir
2132 * pop hl
2133 * ld bc,09105h
2136 * call spr_flip_graphics_h
2139 * call obj_init_mirror
213C * call f_5028
213F * ld a,010h
2141 * ld hl,03568h
2144 * ld de,0002dh
2147 * ld b,005h
2149 * ld (hl),a
214A * add hl,de
214B * djnz $-2
214D * xor a
214E * ld (0289ch),a
2151 * di
2152 * xor a
2153 * ld (028c6h),a
2156 * ld (023e4h),a
2159 * ld a,002h
215B * ld (02406h),a
215E * ld (02913h),sp
2162 * call f_22D4
2165 * call snd_silence_if_idle
2168 * call obj_close_mirror
216B * call f_4D2A
216E * call f_5035
2171 * call f_5129
2174   nop
2175 * call f_4B57
2178 * ei
2179 * nop
217A * ld a,(02b87h)
217D * ld (00600h),a
2180 * call game_input_and_mirror
2183 * call sys_check_pause_save_load
2186 * call f_31DF
2189 * ld a,007h
218B * call sys_key_down
218E * call nz,03557h
2191 * call f_510C
2194 * call f_4B43
2197 * call f_3E29
219A * call f_3DEE
219D * call f_4FEF
21A0 * call f_3A37
21A3 * call f_3D15
21A6 * call iso_update_camera_room
21A9 * ld a,(02909h)
21AC * and a
21AD * jr z,$+7
21AF * call iso_draw_room
21B2 * ld a,080h
21B4 * ld (00a6dh),a
21B7 * call f_4BEC
21BA * call obj_update_doors
21BD * ld hl,02703h
21C0 * call chr_update
21C3 * call game_run_npc_behaviours
21C6 * xor a
21C7 * ld (02909h),a
21CA * ld (028fah),a
21CD * call spr_place_light
21D0 * call obj_door_flip_graphics
21D3 * call f_4ECA
21D6 * ld a,(0289ch)
21D9 * cp 02ah
21DB * jr c,$-5
21DD * ld a,(02b87h)
21E0 * and 001h
21E2 * call nz,snd_play_footstep
21E5 * xor a
21E6 * ld (0289ch),a
21E9 * call spr_draw_or_darken
21EC * ld a,042h
21EE * call sys_key_down
21F1 * call f_3D05
21F4 * jp z,02179h
21F7   ld a,015h
21F9   call sys_key_down
21FC   jp z,01e4bh
21FF   ld a,017h
2201   call sys_key_down
2204   jp z,01e4bh
2207   ld bc,00008h
220A   ld de,00000h
220D   ld hl,0221eh
2210   ldir
2212   ld sp,(02913h)
2216   pop hl
2217   ld hl,00000h
221A   push hl
221B   jp 01e4bh
221E   ld bc,07f89h
2221   out (c),c
2223   jp 00591h
