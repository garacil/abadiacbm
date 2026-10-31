; chr_path_add_targets_around at 042D (64K)   PC: 0BAF   CPC 6128: 07BD   called 64419 times by 0416
; '*' = executed in the exploration sessions; the listing runs to the next known entry
042D * push hl
042E * pop ix
0430 * push de
0431 * pop iy
0433 * ld b,(ix+001h)
0436 * call chr_path_add_target_beside
0439 * inc b
043A * call chr_path_add_target_beside
043D * inc b
043E * call chr_path_add_target_beside
0441 * inc b
