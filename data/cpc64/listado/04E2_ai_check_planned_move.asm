; ai_check_planned_move at 04E2 (64K)   PC: 0C6A   CPC 6128: 0872   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
04E2 * ld a,(02912h)
04E5 * cp 0ffh
04E7 * jp nz,chr_cmd_discard
04EA * ret
