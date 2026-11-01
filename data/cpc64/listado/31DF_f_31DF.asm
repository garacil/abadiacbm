; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_31DF at 31DF (64K)   PC: -   CPC 6128: -   called 26973 times by 2186
; '*' = executed in the exploration sessions; the listing runs to the next known entry
31DF * ld a,044h
31E1 * call sys_key_pressed
31E4 * ret z
31E5   ld a,017h
31E7   call sys_key_down
31EA   ret z
31EB   di
31EC   ld a,03fh
31EE   ld (00c07h),a
31F1   ld c,a
31F2   ld a,007h
31F4   call snd_stub_psg_write
31F7   call 0329ah
31FA   call 03276h
31FD   ld a,001h
31FF   call 031c1h
3202   call 03276h
3205   ld a,001h
3207   call 031c1h
320A   call f_2D50
320D   ld a,042h
320F   call sys_key_down
3212   jr z,$+7
3214   call 03293h
3217   jr $+36
3219   ld a,03ch
321B   call sys_key_down
321E   jr nz,$+34
3220   ld a,024h
3222   call sys_key_down
3225   jr z,$-43
3227   ld hl,0855bh
322A   ld de,005dch
322D   ld a,00ch
322F   call 032abh
3232   jr c,$+9
3234   call 03254h
3237   cp (hl)
3238   jp z,02fefh
323B   call 02151h
323E   ei
323F   ret
3240   call 02fd7h
3243   call 03254h
3246   ld (hl),a
3247   ld hl,0855bh
324A   ld de,005dch
324D   ld a,00ch
324F   call 032cbh
3252   jr $-23
3254   ld hl,07f80h
3257   ld bc,006d9h
325A   xor a
325B   add a,(hl)
325C   inc hl
325D   dec bc
325E   inc b
325F   djnz $-4
3261   ret
3262   ld bc,07f10h
3265   out (c),c
3267   ld c,054h
3269   out (c),c
326B   call f_2D50
326E   ld a,042h
3270   call sys_key_down
3273   jr nz,$-8
3275   ret
3276   ld hl,0c000h
3279   ld de,0328bh
327C   ld b,008h
327E   ld c,(hl)
327F   ld a,(de)
3280   ld (hl),a
3281   ld a,c
3282   ld (de),a
3283   inc de
3284   ld a,h
3285   add a,008h
3287   ld h,a
3288   djnz $-10
328A   ret
328B   nop
328C   nop
328D   rrca
328E   rrca
328F   ret p
3290   ret p
3291   rst 38h
3292   rst 38h
3293   ld bc,0f600h
3296   out (c),c
3298   and a
3299   ret
329A   ld bc,0f610h
329D   out (c),c
329F   ld a,002h
32A1   jp 031c1h
32A4   pop hl
32A5   pop hl
32A6   call 03293h
32A9   scf
32AA   ret
32AB   call 0330ch
32AE   ld (032f1h),sp
32B2   ld sp,0c000h
32B5   call 0337bh
32B8   call 03328h
32BB   call 0bc77h
32BE   jr nc,$+49
32C0   ld hl,07f80h
32C3   call 0bc83h
32C6   call 0bc7ah
32C9   jr $+38
32CB   call 0330ch
32CE   ld (032f1h),sp
32D2   ld sp,0c000h
32D5   call 0337bh
32D8   call 03328h
32DB   call 0bc8ch
32DE   jr nc,$+17
32E0   ld hl,07f80h
32E3   ld de,005dch
32E6   xor a
32E7   ld b,a
32E8   ld c,a
32E9   call 0bc98h
32EC   call 0bc8fh
32EF   di
32F0   ld sp,00000h
32F3   ld a,006h
32F5   ld hl,0fcffh
32F8   ld de,0bfffh
32FB   ld bc,00500h
32FE   lddr
3300   dec h
3301   dec h
3302   dec h
3303   dec a
3304   jr nz,$-9
3306   ccf
3307   ld de,0003fh
330A   jr $+25
330C   di
330D   ld a,006h
330F   ld hl,0bfffh
3312   ld de,0fcffh
3315   ld bc,00500h
3318   lddr
331A   dec d
331B   dec d
331C   dec d
331D   dec a
331E   jr nz,$-9
3320   ld hl,0003fh
3323   ld c,040h
3325   lddr
3327   ret
3328   call 0bb06h
332B   cp 0fch
332D   jr nc,$-62
332F   cp 031h
3331   jr c,$-9
3333   cp 03ah
3335   jr nc,$-13
3337   ld h,a
3338   ld l,053h
333A   ld (03444h),hl
333D   ld hl,0343ah
3340   ld de,07f80h
3343   ld b,00ch
3345   ret
3346   di
3347   ld sp,0c000h
334A   call 0337bh
334D   ld hl,0314eh
3350   ld (03444h),hl
3353   ld hl,0343ah
3356   ld de,05fffh
3359   ld b,00ch
335B   call 0bc77h
335E   jr nc,$-11
3360   ld hl,05fffh
3363   push hl
3364   push bc
3365   call 0bc83h
3368   call 0bc7ah
336B   di
336C   pop bc
336D   pop hl
336E   add hl,bc
336F   dec hl
3370   ld de,08bffh
3373   call 033b9h
3376   call 06000h
3379   jr $-3
337B   pop hl
337C   ld (033b7h),hl
337F   ld hl,03ec9h
3382   ld de,0be80h
3385   ld bc,00021h
3388   ldir
338A   call 0be80h
338D   ld a,0c9h
338F   ld (0bdd9h),a
3392   call 0bb00h
3395   ld c,007h
3397   ld de,00040h
339A   ld hl,0abffh
339D   call 0bcceh
33A0   ld hl,00000h
33A3   ld (0a700h),hl
33A6   ld a,0ffh
33A8   ld (0be78h),a
33AB   call 0bc6bh
33AE   ld a,032h
33B0   ld hl,000a7h
33B3   call 0bc68h
33B6   jp 00000h
33B9   ld a,(hl)
33BA   dec hl
33BB   ld b,a
33BC   scf
33BD   rra
33BE   ld i,a
33C0   ld a,b
33C1   rra
33C2   jr c,$+15
33C4   ldd
33C6   ld a,i
33C8   ld b,a
33C9   rra
33CA   ld i,a
33CC   and a
33CD   jr nz,$-13
33CF   jr $-22
33D1   ld a,(hl)
33D2   dec hl
33D3   and a
33D4   ret z
33D5   bit 7,a
33D7   jr z,$+25
33D9   ld b,a
33DA   rrca
33DB   rrca
33DC   rrca
33DD   rrca
33DE   and 007h
33E0   add a,003h
33E2   ld c,a
33E3   ld a,b
33E4   and 00fh
33E6   ld b,a
33E7   ld a,(hl)
33E8   dec hl
33E9   push hl
33EA   ld l,a
33EB   ld h,b
33EC   ld b,000h
33EE   jr $+34
33F0   ld bc,00002h
33F3   bit 6,a
33F5   jr z,$+6
33F7   and 03fh
33F9   jr $+12
33FB   bit 5,a
33FD   jr z,$+26
33FF   and 01fh
3401   add a,c
3402   ld c,a
3403   ld a,(hl)
3404   dec hl
3405   push hl
3406   ld l,a
3407   ld h,b
3408   jr $+8
340A   xor a
340B   ld c,a
340C   inc b
340D   ld h,b
340E   ld l,c
340F   dec hl
3410   inc hl
3411   add hl,de
3412   lddr
3414   pop hl
3415   jr $-79
3417   bit 4,a
3419   jr z,$+16
341B   and 00fh
341D   ld b,(hl)
341E   dec hl
341F   ld c,(hl)
3420   dec hl
3421   push hl
3422   ld h,a
3423   ld l,b
3424   ld b,000h
3426   inc bc
3427   jr $-23
3429   cp 00fh
342B   jr nz,$+8
342D   ld c,(hl)
342E   dec hl
342F   push hl
3430   inc bc
3431   jr $-36
3433   push hl
3434   cp c
3435   jr c,$-43
3437   ld c,a
3438   jr $-43
343A   ld b,c
343B   ld b,d
343C   ld b,c
343D   ld b,h
343E   ld c,c
343F   ld b,c
3440   ld (hl),034h
3442   ld l,042h
3444   ld c,c
3445   ld c,(hl)
3446   ld l,0c0h
3448   cp a
3449   cp e
344A   cp l
344B   cp h
344C   nop
344D   nop
344E   nop
344F   nop
3450   nop
3451   nop
3452   nop
3453   nop
3454   sbc a,b
3455   ld a,e
