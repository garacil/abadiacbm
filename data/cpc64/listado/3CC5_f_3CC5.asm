; f_3CC5 at 3CC5 (64K)   PC: -   CPC 6128: -   called 26960 times by 3D15
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3CC5 * call f_51E7
3CC8 * call f_3CAE
3CCB * call f_3C8F
3CCE * ld a,000h
3CD0 * jr nz,$+38
3CD2 * ld a,(037e0h)
3CD5 * inc a
3CD6 * ld (037e0h),a
3CD9 * cp 032h
3CDB * ret c
3CDC * dec a
3CDD * ld (037e0h),a
3CE0 * ld a,(028f2h)
3CE3 * and a
3CE4 * call nz,f_3CFE
3CE7 * call z,03d01h
3CEA * call snd_play_music_if_idle
3CED * ld a,(037dch)
3CF0 * ld c,a
3CF1 * ld a,(037dfh)
3CF4 * cp c
3CF5 * ret z
3CF6 * ld (037dch),a
3CF9 * ld (037e0h),a
3CFC * and a
3CFD * ret nz
