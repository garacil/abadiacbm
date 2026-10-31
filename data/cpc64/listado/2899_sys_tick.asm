; sys_tick at 2899 (64K)   PC: 281E   CPC 6128: 2D48   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2899 * di
289A * push af
289B * ld a,000h
289D * inc a
289E * jr z,$+5
28A0 * ld (0289ch),a
28A3 * call f_0CD0
28A6 * call txt_phrase_tick
28A9 * pop af
28AA * ei
28AB * reti
