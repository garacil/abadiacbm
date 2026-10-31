; obj_for_each_visible at 09AB (64K)   PC: 11E8   CPC 6128: 0D3B   called 8 times by 098B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
09AB * ld (009bah),hl
09AE * ld a,(iy+000h)
09B1 * cp 0ffh
09B3 * ret z
09B4 * call spr_project_entity
09B7 * push ix
09B9 * call nc,obj_door_sprite_update
09BC * pop ix
09BE * ld a,(ix+001h)
09C1 * ld (ix+003h),a
09C4 * ld a,(ix+002h)
09C7 * ld (ix+004h),a
09CA * ld bc,00005h
09CD * add iy,bc
09CF * ld bc,00014h
09D2 * add ix,bc
09D4 * nop
09D5 * jr $-39
