; obj_redraw_one_object at 0983 (64K)   PC: 11C1   CPC 6128: 0D13   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0983 * ld a,0c9h
0985 * ld (009d4h),a
0988 * ld hl,00a2bh
098B * call obj_for_each_visible
098E * xor a
098F * ld (009d4h),a
0992 * ret
