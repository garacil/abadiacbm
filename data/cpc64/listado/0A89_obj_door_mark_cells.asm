; obj_door_mark_cells at 0A89 (64K)   PC: 12DE   CPC 6128: 0E19   called 20896 times by 08CC 0B86 0BCA
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0A89 * call obj_door_cells
0A8C * ret c
0A8D * ex af,af'
0A8E * ld (ix+000h),a
0A91 * add ix,bc
0A93 * ld (ix+000h),a
0A96 * add ix,bc
0A98 * ld (ix+000h),a
0A9B * ret
