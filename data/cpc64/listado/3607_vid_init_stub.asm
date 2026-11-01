; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; vid_init_stub at 3607 (64K)   PC: 37AF   CPC 6128: 3AD1   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3607 * ld bc,08f00h
360A * ld a,c
360B * and 0f0h
360D * ld d,a
360E * ld a,c
360F * rrca
3610 * rrca
3611 * rrca
3612 * rrca
3613 * ld e,a
3614 * and c
3615 * and 00fh
3617 * or d
3618 * ld (bc),a
3619 * inc b
361A * ld a,e
361B * xor c
361C * and c
361D * and 00fh
361F * ld d,a
3620 * add a,a
3621 * add a,a
3622 * add a,a
3623 * add a,a
3624 * or d
3625 * ld (bc),a
3626 * inc b
3627 * ld a,c
3628 * and 00fh
362A * ld d,a
362B * ld a,e
362C * and c
362D * and 0f0h
362F * or d
3630 * ld (bc),a
3631 * inc b
3632 * ld a,e
3633 * xor c
3634 * and c
3635 * and 0f0h
3637 * ld d,a
3638 * srl a
363A * srl a
363C * srl a
363E * srl a
3640 * or d
3641 * ld (bc),a
3642 * dec b
3643 * dec b
3644 * dec b
3645 * inc c
3646 * jr nz,$-60
3648 * ret
