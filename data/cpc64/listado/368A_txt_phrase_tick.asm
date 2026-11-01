; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; txt_phrase_tick at 368A (64K)   PC: 3820   CPC 6128: 3B54   called 893376 times by 28A6
; '*' = executed in the exploration sessions; the listing runs to the next known entry
368A * di
368B * ld a,(028ebh)
368E * inc a
368F * cp 02dh
3691 * ld (028ebh),a
3694 * ret nz
3695 * xor a
3696 * ld (028ebh),a
3699 * ld a,(028f3h)
369C * and a
369D * ret z
369E * push ix
36A0 * push hl
36A1 * ld hl,(028e8h)
36A4 * push hl
36A5 * push de
36A6 * push bc
36A7 * ex af,af'
36A8 * push af
36A9 * call snd_play_beep
36AC * ld a,(028f1h)
36AF * dec a
36B0 * jr z,$+93
36B2 * ld hl,(028edh)
36B5 * bit 7,(hl)
36B7 * jr z,$+7
36B9 * ld a,001h
36BB * ld (028f1h),a
36BE * ld a,(hl)
36BF * and 007h
36C1 * ld (00ff9h),a
36C4 * ld (00fffh),a
36C7 * neg
36C9 * ld (00ffch),a
36CC * ld a,(hl)
36CD * and 07fh
36CF * inc hl
36D0 * ld (028edh),hl
36D3 * push af
36D4 * ld hl,0e512h
36D7 * ld bc,0081eh
36DA * push hl
36DB * push bc
36DC * ld b,000h
36DE * ld d,h
36DF * ld e,l
36E0 * dec de
36E1 * dec de
36E2 * ldir
36E4 * pop bc
36E5 * pop hl
36E6 * call f_3558
36E9 * djnz $-15
36EB * ld hl,0a42eh
36EE * ld (028e8h),hl
36F1 * pop bc
36F2 * ld a,b
36F3 * cp 020h
36F5 * ld a,006h
36F7 * jr nz,$+3
36F9 * xor a
36FA * ld (01032h),a
36FD * ld a,b
36FE * call txt_draw_char_inverted
3701 * pop af
3702 * ex af,af'
3703 * pop bc
3704 * pop de
3705 * pop hl
3706 * ld (028e8h),hl
3709 * pop hl
370A * pop ix
370C * ret
370D * ld a,(028ech)
3710 * and a
3711 * jr z,$+17
3713 * dec a
3714 * ld (028ech),a
3717 * ld a,020h
3719 * jr nz,$-70
371B * xor a
371C * ld (028f3h),a
371F * jp 03701h
3722 * ld (028f1h),a
3725 * ld hl,(028efh)
3728 * ld a,(hl)
3729 * cp 0ffh
372B * jr nz,$+14
372D * ld a,011h
372F * ld (028ech),a
3732 * ld a,001h
3734 * ld (028f1h),a
3737 * jr $-42
3739 * cp 0fah
373B * jr nc,$+35
373D * inc hl
373E * cp 0f9h
3740 * ld c,020h
3742 * jr c,$+6
3744 * ld c,000h
3746 * ld a,(hl)
3747 * inc hl
3748 * ld (028efh),hl
374B * ld hl,0b580h
374E * ld b,a
374F * and a
3750 * call nz,txt_skip_words
3753 * ld (028edh),hl
3756 * ld a,c
3757 * and a
3758 * jp z,036ach
375B * jp 036d3h
375E * sub 0fah
3760 * inc hl
3761 * ld (028efh),hl
3764 * ld hl,03447h
3767 * call util_add_bx_al
376A * ld (028edh),hl
376D * jp 036ach
