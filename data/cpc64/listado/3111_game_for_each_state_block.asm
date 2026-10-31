; game_for_each_state_block at 3111 (64K)   PC: 3367   CPC 6128: 37B9   called 21 times by 318B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3111 * ld (0312ah),hl
3114 * ld ix,03134h
3118 * ld hl,00103h
311B * ld e,(ix+000h)
311E * ld d,(ix+001h)
3121 * ld a,d
3122 * or e
3123 * ret z
3124 * ld c,(ix+002h)
3127 * ld b,000h
3129 * call game_state_block_save
312C * inc ix
312E * inc ix
3130 * inc ix
3132 * jr $-23
3134   di
3135   scf
3136   dec b
3137   inc de
3138   jr c,$+5
313A   inc (hl)
313B   jr c,$+5
313D   ld c,h
313E   jr c,$+5
3140   ld e,(hl)
3141   jr c,$+5
3143   ret nc
3144   jr z,$+16
3146   ld hl,(01029h)
3149   dec a
314A   add hl,hl
314B   inc hl
314C   dec (hl)
314D   dec hl
314E   jr nz,$+91
3150   dec hl
3151   inc hl
3152   adc a,c
3153   dec hl
3154   inc bc
3155   sbc a,b
3156   dec hl
3157   inc bc
3158   and a
3159   dec hl
315A   inc bc
315B   or (hl)
315C   dec hl
315D   inc bc
315E   push bc
315F   dec hl
3160   inc bc
3161   call nc,0032bh
3164   nop
3165   nop
