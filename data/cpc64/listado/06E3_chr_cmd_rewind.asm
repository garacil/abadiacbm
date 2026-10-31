; chr_cmd_rewind at 06E3 (64K)   PC: 0EC6   CPC 6128: 0A73   called 188 times by 06D5
; '*' = executed in the exploration sessions; the listing runs to the next known entry
06E3 * ld (iy+009h),000h
06E7 * ld (iy+00bh),000h
06EB * ret
06EC * xor a
06ED * ld (02907h),a
06F0 * push hl
06F1 * call chr_path_build_grid
06F4 * pop hl
06F5 * call chr_to_hbuf_coords
06F8 * ld (02905h),hl
06FB * jp chr_path_search_to_dest
