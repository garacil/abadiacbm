; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_41C9 at 41C9 (64K)   PC: -   CPC 6128: -   called 2144 times by 4369
; '*' = executed in the exploration sessions; the listing runs to the next known entry
41C9 * ld (02901h),sp
41CD * di
41CE * ld a,0ffh
41D0 * ld (0289ch),a
41D3 * ld sp,00000h
41D6 * pop de
41D7 * ld hl,07f80h
41DA * ld (hl),0ffh
41DC * inc hl
41DD * ld bc,(02905h)
41E1 * ld (hl),c
41E2 * inc hl
41E3 * ld (hl),b
41E4 * inc hl
41E5 * ld a,(03f81h)
41E8 * xor 002h
41EA * ld (hl),a
41EB * ld a,(03f82h)
41EE * cp 001h
41F0 * jr z,$+76
41F2 * pop bc
41F3 * ld a,b
41F4 * and 080h
41F6 * jr z,$-4
41F8 * inc hl
41F9 * ld (hl),e
41FA * inc hl
41FB * ld (hl),d
41FC * pop bc
41FD * ld a,b
41FE * sub d
41FF * inc a
4200 * cp 003h
4202 * jr nc,$-6
4204 * ld (04211h),a
4207 * ld a,c
4208 * sub e
4209 * inc a
420A * cp 003h
420C * jr nc,$-16
420E * add a,a
420F * add a,a
4210 * add a,000h
4212 * ld (0422ch),bc
4216 * ld b,000h
4218 * cp 001h
421A * jr z,$+17
421C * inc b
421D * cp 006h
421F * jr z,$+12
4221 * inc b
4222 * cp 009h
4224 * jr z,$+7
4226 * inc b
4227 * cp 004h
4229 * jr nz,$-45
422B * ld de,00000h
422E * inc hl
422F * ld (hl),b
4230 * ld a,(02903h)
4233 * cp e
4234 * jr nz,$-66
4236 * ld a,(02904h)
4239 * cp d
423A * jr nz,$-72
423C * ld sp,(02901h)
4240 * ei
4241 * push hl
4242 * pop ix
4244 * ld b,(iy+001h)
4247 * ld c,(ix+000h)
424A * bit 7,(iy+005h)
424E * jr z,$+16
4250 * ld a,b
4251 * xor c
4252 * and 001h
4254 * jr z,$+10
4256 * ld a,(iy+005h)
4259 * xor 020h
425B * ld (iy+005h),a
425E * ld a,b
425F * ld (iy+001h),c
4262 * cp c
4263 * call nz,f_432C
4266 * push ix
4268 * call chr_probe_ahead
426B * call f_4292
426E * pop ix
4270 * dec ix
4272 * dec ix
4274 * dec ix
4276 * ld a,(ix+000h)
4279 * cp 0ffh
427B * ret z
427C * ld l,(iy+002h)
427F * ld h,(iy+003h)
4282 * call chr_to_hbuf_coords
4285 * ld e,(ix+001h)
4288 * ld d,(ix+002h)
428B * and a
428C * sbc hl,de
428E * jr z,$-74
4290 * jr $-32
