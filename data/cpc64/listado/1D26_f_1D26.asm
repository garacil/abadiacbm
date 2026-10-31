; f_1D26 at 1D26 (64K)   PC: -   CPC 6128: -   called 19342 times by 1D21
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1D26 * call iso_put_tile
1D29 * dec h
1D2A * ret
1D2B * cp 081h
1D2D * jr nz,$+7
1D2F * call iso_put_tile
1D32 * jr $-33
1D34   push bc
1D35   call f_1E22
1D38   ld a,c
1D39   pop bc
1D3A   and a
1D3B   call nz,iso_put_tile_times
1D3E   ld a,(ix+000h)
1D41   cp 0c8h
1D43   ret nc
1D44   inc ix
1D46   jr $-53
