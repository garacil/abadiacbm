; chr_room_distance_near at 08E5 (64K)   PC: 1111   CPC 6128: 0C75   called 12624 times by 083F 084B 086A 0875
; '*' = executed in the exploration sessions; the listing runs to the next known entry
08E5   srl c
08E7   srl c
08E9   srl c
08EB   srl c
08ED   srl a
08EF   srl a
08F1   srl a
08F3   srl a
08F5   sub c
08F6   inc a
08F7   cp 003h
08F9   ret
08FA   inc e
08FB   add hl,bc
08FC   ld d,00ch
08FE   ld a,(bc)
08FF   add hl,bc
0900   inc c
0901   ld (bc),a
0902   inc h
0903   add hl,bc
0904   ld (bc),a
0905   inc c
0906   add hl,hl
0907   add hl,bc
0908   inc c
0909   defb 016h
