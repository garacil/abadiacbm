; obj_door_camera_adjust at 0AEC (64K)   PC: 134D   CPC 6128: 0E7C   called 9330 times by 0A47
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0AEC * ld hl,00b0dh
0AEF * ld a,003h
0AF1 * call iso_orient_relative
0AF4 * add a,a
0AF5 * add a,a
0AF6 * call util_add_bx_al
0AF9 * ld c,(hl)
0AFA * inc hl
0AFB * ld b,(hl)
