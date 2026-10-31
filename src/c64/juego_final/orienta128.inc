; made by c64/certifica/pc/orienta128.py (do not edit): obj_drop_object's orientation quirk as the PC has
; it (abadia128ks, the full game): per height 00h-23h the byte at DS:hhF5 (Guillermo) / DS:hh22 (the abbot)
; as loaded (or the first frame's, selector 0), mirrored, and the selector (0 none, 1 Guillermo's frames,
; 2 Adso's, 3 the door leaf, 4 + k face block k); the 6502 picks the second value when the graphic is mirrored
lb_or128_guillermo_lo:
        .byte   $5A, $00, $50, $0F, $F0, $0A, $5F, $DF, $DF, $F7, $DB, $F6, $F6, $F6, $F6, $10, $10, $4A, $20, $FF, $54, $88, $55, $00, $0A, $22, $44, $FF, $00, $FF, $18, $55, $00, $00, $FF, $55
lb_or128_guillermo_esp:
        .byte   $5A, $00, $50, $0F, $F0, $0A, $5F, $DF, $DF, $F7, $DB, $F6, $F6, $F6, $F6, $10, $10, $4A, $20, $22, $15, $3F, $15, $05, $00, $15, $11, $FF, $00, $FF, $18, $55, $00, $FF, $FF, $55
lb_or128_guillermo_sel:
        .byte   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 3, 0, 0, 0, 0, 0, 0, 6, 8, 0
lb_or128_abad_lo:
        .byte   $00, $33, $33, $00, $00, $33, $88, $FF, $FF, $FF, $FF, $FF, $F6, $F6, $F6, $5B, $10, $FA, $43, $FF, $40, $C0, $42, $82, $4F, $FF, $FF, $05, $01, $55, $FF, $FF, $CA, $D5, $FF, $FF
lb_or128_abad_esp:
        .byte   $00, $33, $33, $00, $00, $33, $88, $FF, $FF, $FF, $FF, $FF, $F6, $F6, $F6, $5B, $10, $FA, $43, $FC, $C0, $03, $15, $82, $54, $54, $43, $15, $01, $55, $FF, $FF, $CA, $D5, $FF, $FF
lb_or128_abad_sel:
        .byte   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 0, 0, 0, 0, 0, 0, 6, 9
