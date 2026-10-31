; chr_probe_cells at 2320 (64K)   PC: 21F6   CPC 6128: 27CB   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2320 * ld (02374h),a
2323 * ex de,hl
2324 * ld h,(iy+003h)
2327 * ld l,(iy+002h)
232A * call chr_to_hbuf_coords
232D * ld a,b
232E * ex de,hl
232F * ret c
2330 * ex de,hl
2331 * ld a,l
2332 * ld l,h
2333 * ld h,000h
2335 * add hl,hl
2336 * add hl,hl
2337 * add hl,hl
2338 * ld d,h
2339 * add a,l
233A * ld e,a
233B * add hl,hl
233C * add hl,de
233D * ld de,(028dbh)
2341 * add hl,de
2342 * ex de,hl
2343 * call chr_step_table
2346 * ld a,(hl)
2347 * ld (02378h),a
234A * inc hl
234B * ld a,(hl)
234C * ld (02379h),a
234F * inc hl
2350 * ld a,(hl)
2351 * ld (0237fh),a
2354 * inc hl
2355 * ld a,(hl)
2356 * ld (02380h),a
2359 * inc hl
235A * ld a,(hl)
235B * inc hl
235C * push hl
235D * ld h,(hl)
235E * ld l,a
235F * add hl,de
2360 * ld de,02916h
2363 * ld b,004h
2365 * push bc
2366 * push hl
2367 * ld b,004h
2369 * push bc
236A * ld a,(hl)
236B * cp 010h
236D * jr c,$+6
236F * and 030h
2371 * jr $+4
2373 * sub 000h
2375 * ld (de),a
2376 * inc de
2377 * ld bc,00000h
237A * add hl,bc
237B * pop bc
237C * djnz $-19
237E * ld bc,00000h
2381 * pop hl
2382 * add hl,bc
2383 * pop bc
2384 * djnz $-31
2386 * pop hl
2387 * inc hl
2388 * bit 7,(iy+005h)
238C * jr z,$+10
238E * ld a,(02917h)
2391 * ld c,a
2392 * ld a,(0291bh)
2395 * ret
2396 * ld a,(02917h)
2399 * ld c,a
239A * ld a,(02918h)
239D * cp c
239E * ret z
239F * ld a,002h
23A1 * ret
23A2   jr $+2
23A4   rst 38h
23A5   rst 38h
23A6   pop de
23A7   rst 38h
23A8   ld bc,00100h
23AB   nop
23AC   jr $+2
23AE   adc a,0ffh
23B0   nop
23B1   rst 38h
23B2   ret pe
23B3   rst 38h
23B4   ld bc,01600h
23B7   nop
23B8   rst 38h
23B9   nop
23BA   rst 38h
23BB   rst 38h
23BC   ret pe
23BD   rst 38h
23BE   add hl,de
23BF   nop
23C0   nop
23C1   ld bc,00018h
23C4   rst 38h
23C5   rst 38h
23C6   jp pe,001ffh
23C9   nop
23CA   ld bc,01800h
23CD   nop
23CE   rst 8
23CF   rst 38h
23D0   nop
23D1   rst 38h
23D2   ret pe
23D3   rst 38h
23D4   ld bc,01600h
23D7   nop
23D8   rst 38h
23D9   nop
23DA   rst 38h
23DB   rst 38h
23DC   ret pe
23DD   rst 38h
23DE   ld sp,00000h
23E1   ld bc,03e00h
23E4   nop
23E5 * and a
23E6 * jr z,$+57
23E8   dec a
23E9   ret z
23EA   ld (023e4h),a
23ED   cp 013h
23EF   jr nz,$+15
23F1   ld a,(02406h)
23F4   cp 002h
23F6   jr nz,$+8
23F8   dec (iy+002h)
23FB   jp chr_animate
23FE   cp 001h
2400   jr z,$+26
2402   ld a,(ix+002h)
2405   add a,002h
2407   ld (ix+002h),a
240A   ld a,(ix+000h)
240D   and 03fh
240F   or 080h
2411   ld (ix+000h),a
2414   ld a,0ffh
2416   ld (02912h),a
2419   ret
241A   ld (ix+000h),0feh
241E   ret
241F * ld a,(037dch)
2422 * and a
2423 * ret nz
2424 * ld a,008h
2426 * call sys_key_pressed
2429 * ld c,001h
242B * jp nz,chr_turn
242E * ld a,001h
2430 * call sys_key_pressed
2433 * ld c,0ffh
2435 * jp nz,chr_turn
2438 * ld a,000h
243A * call sys_key_down
243D * ret z
243E * call chr_probe_ahead
2441 * jp chr_try_advance
