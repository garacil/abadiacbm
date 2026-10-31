; f_48EB at 48EB (64K)   PC: -   CPC 6128: -   called 110024 times by 455D 4638 4671 468C 4809
; '*' = executed in the exploration sessions; the listing runs to the next known entry
48EB * ld b,008h
48ED * ld de,00000h
48F0 * srl a
48F2 * jr nc,$+6
48F4 * push hl
48F5 * add hl,de
48F6 * ex de,hl
48F7 * pop hl
48F8 * add hl,hl
48F9 * djnz $-9
48FB * ret
