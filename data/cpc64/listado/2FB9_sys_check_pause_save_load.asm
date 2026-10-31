; sys_check_pause_save_load at 2FB9 (64K)   PC: 311E   CPC 6128: 359D   called 26973 times by 2183
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2FB9 * ld a,04fh
2FBB * call sys_key_pressed
2FBE * ret z
2FBF   di
2FC0   ld a,03fh
2FC2   ld (00c07h),a
2FC5   ld c,a
2FC6   ld a,007h
2FC8   call snd_stub_psg_write
2FCB   call f_2D50
2FCE   ld a,04fh
2FD0   call sys_key_pressed
2FD3   jr z,$-8
2FD5   ei
2FD6   ret
2FD7   di
2FD8   call 0307dh
2FDB   ex de,hl
2FDC   ldir
2FDE   ld hl,037d2h
2FE1   ld bc,000c8h
2FE4   ldir
2FE6   ld hl,03568h
2FE9   ld bc,000ffh
2FEC   ldir
2FEE   ret
2FEF   di
2FF0   ld a,(02b8dh)
2FF3   ld l,a
2FF4   ld a,(02b9ch)
2FF7   ld h,a
2FF8   push hl
2FF9   call spr_unflip_monk_faces
2FFC   call 0307dh
2FFF   ld bc,00320h
3002   push hl
3003   ldir
3005   ld hl,(02edeh)
3008   ld (hl),0f5h
300A   pop hl
300B   ld bc,00338h
300E   add hl,bc
300F   ld de,037d2h
3012   ld bc,00098h
3015   push hl
3016   ldir
3018   pop hl
3019   ld bc,000c8h
301C   add hl,bc
301D   ld de,03568h
3020   ld bc,000e0h
3023   ldir
3025   pop hl
3026   ld ix,02b8dh
302A   ld (ix+000h),l
302D   ld (ix+00fh),h
3030   xor a
3031   ld (ix+01eh),a
3034   ld (ix+02dh),a
3037   ld (ix+03ch),a
303A   ld (ix+04bh),a
303D   call obj_fix_owner_pointers
3040   xor a
3041   ld (03cadh),a
3044   ld a,(0290dh)
3047   and a
3048   call nz,05199h
304B   pop hl
304C   jp 02151h
