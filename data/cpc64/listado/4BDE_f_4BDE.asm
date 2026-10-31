; f_4BDE at 4BDE (64K)   PC: -   CPC 6128: -   called 10 times by 4C23
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4BDE * push af
4BDF * push bc
4BE0 * and c
4BE1 * push af
4BE2 * call z,snd_play_object_dropped
4BE5 * pop af
4BE6 * call nz,snd_play_object_taken
4BE9 * pop bc
4BEA * pop af
4BEB * ret
