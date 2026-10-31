; f_0EA1 at 0EA1 (64K)   PC: -   CPC 6128: -   called 546064 times by 0E7B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0EA1 * ld a,(ix+009h)
0EA4 * ld l,(ix+005h)
0EA7 * ld h,(ix+006h)
0EAA * call f_0FB8
0EAD * ld a,(hl)
0EAE * cp 07fh
0EB0 * jr nz,$+18
0EB2 * ld a,0ffh
0EB4 * ld (ix+011h),a
0EB7 * ld (ix+00fh),a
0EBA * ld (ix+008h),a
0EBD * ld (ix+013h),000h
0EC1 * ret
0EC2 * cp 080h
0EC4 * jr nz,$+8
0EC6 * xor a
0EC7 * ld (ix+009h),a
0ECA * jr $-41
0ECC * ld (ix+008h),a
0ECF * inc hl
0ED0 * ld a,(hl)
0ED1 * ld (ix+013h),a
0ED4 * inc hl
0ED5 * ld a,(hl)
0ED6 * ld (ix+00fh),a
0ED9 * ld (ix+011h),a
0EDC * ld a,(ix+009h)
0EDF * add a,003h
0EE1 * ld (ix+009h),a
0EE4 * ret
