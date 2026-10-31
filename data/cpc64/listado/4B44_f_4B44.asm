; f_4B44 at 4B44 (64K)   PC: -   CPC 6128: -   called 52 times by 3E44 3E5D 3E76 3E9A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4B44 * pop ix
4B46 * ld a,(ix+000h)
4B49 * inc ix
4B4B * push ix
4B4D * cp 0ffh
4B4F * ret z
4B50 * and 07fh
4B52 * call txt_draw_char_inverted
4B55 * jr $-17
