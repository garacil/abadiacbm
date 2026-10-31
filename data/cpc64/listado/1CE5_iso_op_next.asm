; iso_op_next at 1CE5 (64K)   PC: 2B17   CPC 6128: 20D7   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1CE5 * pop bc
1CE6 * dec c
1CE7 * jr z,$+10
1CE9 * pop ix
1CEB * push ix
1CED * push bc
1CEE * jp 01c2ch
1CF1 * pop bc
1CF2 * jp 01c2ch
1CF5 * call iso_tile_run
1CF8   dec h
1CF9 * jp 01c2ch
1CFC   call iso_tile_run
1CFF   dec l
1D00   jp 01c2ch
1D03 * call iso_tile_run
1D06   inc l
1D07 * jp 01c2ch
