; f_0F0B at 0F0B (64K)   PC: -   CPC 6128: -   called 39704 times by 0EEC
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0F0B * ld a,(ix+00ch)
0F0E * ld l,(ix+00ah)
0F11 * ld h,(ix+00bh)
0F14 * call f_0FB8
0F17 * ld a,(hl)
0F18 * cp 07fh
0F1A * jr nz,$+18
0F1C * ld a,0ffh
0F1E * ld (ix+012h),a
0F21 * ld (ix+010h),a
0F24 * ld (ix+00dh),a
0F27 * ld (ix+014h),000h
0F2B * ret
0F2C * cp 080h
0F2E * jr nz,$+8
0F30   xor a
0F31   ld (ix+00ch),a
0F34   jr $-41
0F36 * bit 7,a
0F38 * jr z,$+37
0F3A   and 00fh
0F3C   ld (00c0bh),a
0F3F   inc hl
0F40   ld a,(hl)
0F41   ld (00c09h),a
0F44   inc hl
0F45   ld a,(hl)
0F46   ld (00c0ah),a
0F49   inc hl
0F4A   ld a,(hl)
0F4B   ld (ix+012h),a
0F4E   ld (ix+00dh),001h
0F52   set 4,(ix+00eh)
0F56   ld a,(ix+00ch)
0F59   add a,004h
0F5B   jr $+23
0F5D * ld (ix+00dh),a
0F60 * inc hl
0F61 * ld a,(hl)
0F62 * ld (ix+014h),a
0F65 * inc hl
0F66 * ld a,(hl)
0F67 * ld (ix+010h),a
0F6A * ld (ix+012h),a
0F6D * ld a,(ix+00ch)
0F70 * add a,003h
0F72 * ld (ix+00ch),a
0F75 * ret
0F76   cp 08bh
0F78   rrca
0F79   defb 0fdh,09ah,00fh	;illegal sequence
0F7C   ei
0F7D   xor c
0F7E   rrca
0F7F   call m,00fb7h
0F82   jp m,00fb0h
0F85   ld sp,hl
0F86   adc a,b
0F87   rrca
0F88   ld d,b
0F89   ld e,c
0F8A   ret
0F8B * ld (00c28h),bc
0F8F * ld a,005h
0F91 * ld (00c36h),a
0F94 * ld a,001h
0F96 * ld (00c2ah),a
0F99 * ret
0F9A   ld (00c40h),bc
0F9E   ld a,005h
0FA0   ld (00c4eh),a
0FA3   ld a,001h
0FA5   ld (00c42h),a
0FA8   ret
0FA9 * ld (ix+005h),c
0FAC * ld (ix+006h),b
0FAF * ret
0FB0 * ld (ix+00ah),c
0FB3 * ld (ix+00bh),b
0FB6 * ret
0FB7   ret
