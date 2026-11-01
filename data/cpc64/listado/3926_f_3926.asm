; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3926 at 3926 (64K)   PC: -   CPC 6128: -   called 2025799 times by 3907 391F
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3926 * call f_3994
3929 * ld a,(hl)
392A * cp 020h
392C * ret z
392D * cp 0d7h
392F * ret z
3930 * cp 0c2h
3932 * ret z
3933 * cp 0cdh
3935 * ret z
3936 * cp 0cfh
3938 * ret z
3939 * cp 0c9h
393B * ret z
393C * cp 0c3h
393E * ret z
393F * cp 018h
3941 * ret z
3942 * inc hl
3943 * pop de
3944 * cp 03dh
3946 * jr z,$+69
3948 * cp 03eh
394A * jr z,$+47
394C * cp 03ch
394E * jr z,$+52
3950 * cp 02ah
3952 * jr z,$+35
3954 * cp 026h
3956 * jr z,$+27
3958 * cp 02bh
395A * jr z,$+19
395C * cp 02dh
395E * jr z,$+10
3960 * push de
3961 * push bc
3962 * dec hl
3963 * call f_3994
3966 * jr $-61
3968   ld a,e
3969   sub c
396A * ld c,a
396B * jr $-66
396D * ld a,c
396E * add a,e
396F * jr $-5
3971 * ld a,c
3972 * or e
3973 * jr $-9
3975 * ld a,c
3976 * and e
3977 * jr $-13
3979 * ld a,e
397A * cp c
397B * ld c,000h
397D * jr nc,$-84
397F * dec c
3980 * jr $-87
3982 * ld a,e
3983 * cp c
3984 * ld c,000h
3986 * jr c,$-93
3988 * dec c
3989 * jr $-96
398B * ld a,c
398C * ld c,000h
398E * cp e
398F * jr z,$-102
3991 * dec c
3992 * jr $-105
