; iso_tile_run at 1D0A (64K)   PC: 2B3E   CPC 6128: 20FC   called 44268 times by 1CF5 1D03
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1D0A * pop de
1D0B * ld a,(de)
1D0C * ld (01d29h),a
1D0F * inc de
1D10 * push de
1D11 * call f_1E22
1D14 * ld a,(ix+000h)
1D17 * cp 0c8h
1D19 * jr nc,$+13
1D1B * inc ix
1D1D * cp 080h
1D1F * jr nz,$+12
1D21 * call f_1D26
1D24 * jr $-19
