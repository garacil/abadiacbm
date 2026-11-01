; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_project at 2632 (64K)   PC: 2556   CPC 6128: 2ADD   called 241854 times by 0ACA 2082 261E
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2632 * ld a,(iy+002h)
2635 * sub 000h
2637 * ret c
2638 * cp 028h
263A * ret nc
263B * ld l,a
263C * ld a,(iy+003h)
263F * sub 000h
2641 * ret c
2642 * cp 028h
2644 * ret nc
2645 * ld h,a
2646 * ld a,(iy+004h)
2649 * call iso_floor_base
264C * ld a,b
264D * cp 000h
264F * ret nz
2650 * ld a,(iy+004h)
2653 * sub b
2654 * ld b,a
2655 * call iso_rotate_cam0
2658 * ld (ix+012h),l
265B * ld (ix+013h),h
265E * ld a,h
265F * add a,l
2660 * ld c,a
2661 * sub b
2662 * ret c
2663 * sub 006h
2665 * ret c
2666 * cp 008h
2668 * ret c
2669 * cp 03ah
266B * ret nc
266C * inc a
266D * add a,a
266E * add a,a
266F * ld b,a
2670 * ld a,l
2671 * sub h
2672 * add a,a
2673 * add a,050h
2675 * sub 028h
2677 * ret c
2678 * cp 050h
267A * ret nc
267B * ld l,a
267C * ld h,b
267D * pop de
267E * ld a,c
267F * sub 010h
2681 * jr nc,$+3
2683 * xor a
2684 * nop
2685 * ld c,a
2686 * ld b,000h
2688 * ld a,(iy+005h)
268B * bit 7,a
268D * jr nz,$+64
268F * bit 0,(iy+000h)
2693 * jr z,$+3
2695 * inc b
2696 * ld de,(028d5h)
269A * ld a,(iy+001h)
269D * call iso_orient_relative
26A0 * rrca
26A1 * rrca
26A2 * rrca
26A3 * rrca
26A4 * and 030h
26A6 * add a,b
26A7 * add a,b
26A8 * add a,e
26A9 * ld e,a
26AA * adc a,d
26AB * sub e
26AC * ld d,a
26AD * ld a,(de)
26AE * add a,l
26AF * add a,(iy+007h)
26B2 * ld l,a
26B3 * inc de
26B4 * ld a,(de)
26B5 * add a,h
26B6 * add a,(iy+008h)
26B9 * ld h,a
26BA * ld (ix+001h),l
26BD * ld (ix+002h),h
26C0 * ld a,(ix+000h)
26C3 * cp 0feh
26C5 * ret nz
26C6 * ld (ix+003h),l
26C9 * ld (ix+004h),h
26CC * ret
26CD * inc b
26CE * inc b
26CF * bit 5,(iy+005h)
26D3 * jr nz,$-68
26D5 * inc b
26D6 * inc b
26D7 * ld a,(iy+005h)
26DA * and 003h
26DC * jr nz,$+18
26DE * bit 0,(iy+000h)
26E2 * jr z,$-76
26E4 * inc b
26E5 * bit 4,(iy+005h)
26E9 * jr z,$-83
26EB * inc b
26EC * jr $-86
26EE   inc b
26EF   inc b
26F0   inc b
26F1   bit 6,(iy+005h)
26F5   jr nz,$+6
26F7   inc b
26F8   inc b
26F9   inc b
26FA   inc b
26FB   cp 001h
26FD   jr nz,$-24
26FF   inc b
2700   inc b
2701   jr $-28
2703   ld l,b
2704   add hl,hl
2705   add a,a
2706   dec hl
2707   jp po,04023h
270A   cpl
270B   ret p
270C   inc l
270D   ld a,h
270E   add hl,hl
270F   sub (hl)
2710   dec hl
2711   adc a,a
2712   daa
2713   rst 20h
2714   ld l,010h
2716   dec l
2717   sub b
2718   add hl,hl
2719   and l
271A   dec hl
271B   adc a,a
271C   daa
271D   nop
271E   cpl
271F   nop
2720   ret nz
2721   and h
2722   add hl,hl
2723   or h
2724   dec hl
2725   adc a,a
2726   daa
2727   djnz $+49
2729   ld (bc),a
272A   ret nz
272B   cp b
272C   add hl,hl
272D   jp 08f2bh
2730   daa
2731   jr nz,$+49
2733   inc b
2734   ret nz
2735   call z,0d229h
2738   dec hl
2739   adc a,a
273A   daa
273B   jr nc,$+49
273D   ld b,0c0h
273F   rst 38h
2740   rst 38h
2741   ld (hl),a
2742   inc h
2743   ld a,(hl)
2744   inc h
2745   and (hl)
2746   inc h
2747   xor (hl)
2748   dec h
2749   exx
274A   dec h
