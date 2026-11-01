; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_door_check_open_close at 0B1D (64K)   PC: 1374   CPC 6128: 0EAD   called 188720 times by 09EF
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0B1D * ld a,(iy+001h)
0B20 * bit 7,a
0B22 * ret nz
0B23 * ld e,(iy+002h)
0B26 * ld d,(iy+003h)
0B29 * dec e
0B2A * dec e
0B2B * dec d
0B2C * dec d
0B2D * and 01fh
0B2F * ld c,a
0B30 * ld hl,037f3h
0B33 * ld a,(hl)
0B34 * or 010h
0B36 * and c
0B37 * ld c,a
0B38 * ld a,(0292dh)
0B3B * ld hl,0292ah
0B3E * call obj_door_unpermitted_near
0B41 * jr c,$+117
0B43 * ld a,(0292ah)
0B46 * ld hl,0292dh
0B49 * call obj_door_unpermitted_near
0B4C * jr c,$+106
0B4E * ld hl,0292ah
0B51 * inc e
0B52 * inc d
0B53 * ld a,(hl)
0B54 * inc hl
0B55 * cp 0ffh
0B57 * jr z,$+95
0B59 * and c
0B5A * jr nz,$+6
0B5C * inc hl
0B5D * inc hl
0B5E * jr $-11
0B60 * call util_read_indirect_pair
0B63 * sub e
0B64 * cp 004h
0B66 * jr nc,$-19
0B68 * ld a,b
0B69 * sub d
0B6A * cp 004h
0B6C * jr nc,$-25
0B6E * bit 6,(iy+001h)
0B72 * ret nz
0B73 * ld c,(iy+000h)
0B76 * ld b,(iy+001h)
0B79 * exx
0B7A * set 6,(iy+001h)
0B7E * ld a,080h
0B80 * ld (00a6fh),a
0B83 * ld a,(iy+004h)
0B86 * call obj_door_mark_cells
0B89 * dec (iy+000h)
0B8C * bit 5,(iy+001h)
0B90 * jr nz,$+8
0B92 * inc (iy+000h)
0B95 * inc (iy+000h)
0B98 * call obj_door_cells
0B9B * add ix,bc
0B9D * add ix,bc
0B9F * exx
0BA0 * ld a,(ix+000h)
0BA3 * and 0f0h
0BA5 * ret z
0BA6 * ld (iy+000h),c
0BA9 * ld (iy+001h),b
0BAC * xor a
0BAD * ld (00a6fh),a
0BB0 * ld a,(iy+004h)
0BB3 * jp obj_door_mark_cells
0BB6 * bit 6,(iy+001h)
0BBA * ret z
0BBB * ld c,(iy+000h)
0BBE * ld b,(iy+001h)
0BC1 * exx
0BC2 * ld a,080h
0BC4 * ld (00a6fh),a
0BC7 * ld a,(iy+004h)
0BCA * call obj_door_mark_cells
0BCD * res 6,(iy+001h)
0BD1 * dec (iy+000h)
0BD4 * bit 5,(iy+001h)
0BD8 * jr z,$-64
0BDA * jr $-72
