; spr_mark_leaving at 2623 (64K)   PC: 2545   CPC 6128: 2ACE   called 2 times by 4CDF
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2623 * ld a,(ix+000h)
2626 * cp 0feh
2628 * ret z
2629 * ld (ix+000h),080h
262D * set 7,(ix+005h)
2631 * ret
