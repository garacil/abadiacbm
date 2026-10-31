; spr_place_light at 2265 (64K)   PC: 20A4   CPC 6128: 26A3   called 26960 times by 21CD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2265 * ld a,0feh
2267 * ld (02b20h),a
226A * ld a,(011dch)
226D * and a
226E * ret z
226F   ld a,(0297ch)
2272   cp 0feh
2274   jr z,$-55
2276   ld a,(0297dh)
2279   ld c,a
227A   and 003h
227C   ld (04756h),a
227F   neg
2281   add a,004h
2283   ld (04782h),a
2286   ld a,c
2287   ld ix,02b20h
228B   ld (ix+012h),0feh
228F   ld (ix+013h),0feh
2293   and 0fch
2295   sub 008h
2297   jr nc,$+3
2299   xor a
229A   ld (ix+001h),a
229D   ld (ix+003h),a
22A0   ld a,(0297eh)
22A3   ld c,a
22A4   and 007h
22A6   cp 004h
22A8   ld hl,000efh
22AB   ld de,0009fh
22AE   jr nc,$+3
22B0   ex de,hl
22B1   ld (04738h),hl
22B4   ld (0479eh),de
22B8   ld a,c
22B9   and 0f8h
22BB   sub 018h
22BD   jr nc,$+3
22BF   xor a
22C0   ld (ix+002h),a
22C3   ld (ix+004h),a
22C6   ld hl,02b9ch
22C9   xor a
22CA   bit 0,(hl)
22CC   jr z,$+4
22CE   ld a,029h
22D0   ld (0476dh),a
22D3   ret
