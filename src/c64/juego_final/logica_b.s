; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
; Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
; option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
; implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
; You should have received a copy of the GNU General Public License along with this program.  If not, see
; <https://www.gnu.org/licenses/>.

; abadia64ks, 6502 code of the game: group logica_b (Z80 4C46-60F2; C reference juego/f_logica_b.c).
;
; The objects picked up and dropped, the score bar's object slots, the mirror's reflections, the clock and the
; score bar (hour name, day numeral, obsequium), the manuscript's numeral, and the monks' scripts.  The scripts
; (51E7-60F2) are bytecode for logica_b_vm, a small interpreter of the Z80 script code: the same bytes (RST 08h /
; RST 10h with their inline expressions, JR NZ, JR, JP, JP NZ, CALL, RET) with 6502 operands
; (logica_b_guiones.inc, made by guiones64.py from the tape image).  The VM's expressions are evaluated by
; ai_script_eval 3926 (group estado_texto).
        .include "zp.inc"
        .include "mapa.inc"

        .export obj_pick_up_objects, hud_draw_guillermo_objects, hud_draw_objects, obj_update_key_permissions
        .export obj_drop_on_space, obj_drop_object, obj_front_position
        .export iso_mirror_update, iso_mirror_character, iso_mirror_reflect, iso_mirror_draw_callback
        .export hud_scroll_hour_name, ai_clock_init, ai_clock_redraw, ai_clock_load_duration, ai_clock_tick
        .export ai_clock_advance_hour, hud_set_and_draw_day, hud_draw_day_numeral, ai_timers_tick
.ifdef C128
        .export c128_ave_llamada
        .import c128_ave, cab_espejo
.ifdef C128
        .import far_numeral            ; (plataforma/c128.s: the texts in block 1)
.endif
.endif
        .export hud_obsequium_minus_2, hud_obsequium_sub, hud_fill_bar, obj_read_manuscript, obj_set_mirror_numeral
        .export logica_b_vm

        .import spr_mark_leaving, iso_floor_base, chr_to_hbuf_coords, iso_grid_cell_ptr, obj_redraw_one_object
        .import sys_key_down, sys_key_pressed, util_return_zero, chr_animate, spr_flip_graphics_h
        .import txt_draw_char, vid_palette_day, vid_palette_night, ai_lamp_tick, ai_night_end_tick
        .import hud_say, hud_say_now, game_set_c004_inline, ai_stay, ai_next_state_on_arrival, ai_guillermo_is_close
        .import plat_aleatorio, estado_texto_eval_y

; ---- zero page of logica_b ($E6-$F1) ----
lb_va   = $E8           ; VM: the Z80's A
lb_vf   = $E9           ; VM: the Z80's flags: N Z C as in a 6502 P (a P made from it takes the 6502's I flag)
lb_tgt  = $EA           ; VM: the native routine it calls (JMP (lb_tgt))
lb_ept  = $EC           ; VM: the address of a script variable (lb_var)
lb_t0   = $EE           ; the native routines' own variables
lb_t1   = $EF
lb_t2   = $F0
lb_t3   = $F1           ; ($E6-$E7: free)

.segment "CODE"

; ================================================================ the script VM

; logica_b_vm: a script function is `JSR logica_b_vm` followed by its bytecode.  Runs it until its RET (or a
; tail call of a native routine).  The instruction pointer is zhl + Y: Y (0-127 at each dispatch) moves along
; the instructions and is folded into zhl when it reaches 128, at a jump and at an expression (ai_script_eval
; leaves zhl at the expression's end, as the Z80's HL).  The Z80's A and flags live in lb_va / lb_vf (lb_vf: N Z C
; as in a 6502 P; a P built from it takes the 6502's own I flag), from the entry's (5FDD, 6016, 6040 switch on
; their caller's C and Z).  The bytecode (guiones64.py; v = 2 x the variable's number mod 256, the offset of its
; word in D64_AI_SCRIPT_VARS):
;   CF expr       test: A = C = the value, Z = (value = 0)       D7 v expr     assignment
;   20 e / 18 e   JR NZ / JR                                     C2 nn         JP NZ to bytecode
;   C3 nn         JP to bytecode                                 C3 k 00       JP to lb_tabla[k] (native)
;   CD nn         CALL a native routine                          CD k 00 b     CALL lb_tabla[k] with the inline b
;   CD 0A 00 w..0 the switch of util_jump_table_inline 3A5D      C9            RET
;   3E n          LD A,n                                         01            XOR A
;   F8+p a n e    the test `v n =` (n a literal; the variable at page p 0-7 and low byte a), A = C = 00h
;                 true / FFh false and the flags of AND A, and its jump (e from the next instruction) when false
;   E2 v n e      the same (v as above), the jump when true
;   E3 / E4 v n e `v n >` (v >= n), the jump when false / true          E5 / E6 v n e  `v n <`
;   E7 / E8 v w e `v w =` (two variables)                              E9 / EA v m n e  `v m * n =` (v AND m = n)
;   EB v e / EC v m e  the value [v] / [v] AND m, the jump when not 0 (only the last test of a chain)
;   F0+p a n e    F8+p leaving A, C and the flags as they were (nothing reads them before setting them again)
;   A0+p / A8+p / B0+p a n e  `v n >` the jump when false / `v n =` when true / `v n <` when false, the same
;                 A test is a chain of these (guiones64.py)
;   DB/DC/DD/DE v n  [v] := [v] OR / + / AND / - n
;   D8 v n        assignment of a literal                        D9 v n        the same and RET
;   DA v n w m    two D8 in a row
;   D0 b / D1 b   CALL hud_say / hud_say_now b                   D2 / D3       CALL ai_guillermo_is_close /
;   D4            JP ai_stay                                                   hud_obsequium_minus_2
; The expressions are evaluated by ai_script_eval 3926 (group estado_texto; its entry estado_texto_eval_y takes
; the expression at zhl + Y): out zhl -> the terminator (A), zbc (C) = X = the value, N/Z of it.

lb_jrf:                                 ; Y + 1 + e in 128-255: forward (e >= 0), zhl += A, or backward below zhl
        tax
        lda     (zhl),y
        bmi     lb_jrl
        txa
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       ldy     #0
        jmp     lb_disp
lb_jrl:                                 ; zhl += Y + 1 + e (e sign-extended), Y = 0
        sty     zt0
        lda     (zhl),y
        ldx     #0
        cmp     #$80
        bcc     :+
        dex
:       sec
        adc     zt0
        bcc     :+
        inx
:       clc
        adc     zhl
        sta     zhl
        txa
        adc     zhl+1
        sta     zhl+1
        ldy     #0
        jmp     lb_disp

lb_tstm:                                ; F8+p a n e: the test `v n =` of the variable at page p, low byte a; the
        and     #$07                    ; jump when false (Y -> the opcode)
        sta     lb_ldm+2
        iny
        lda     (zhl),y                 ; a
        tax
        iny
lb_ldm: lda     $FF00,x                 ; (self-modified page) E
        cmp     (zhl),y
        beq     lb_si
        lda     #$FF                    ; false: A = C = FFh, NZ (N set, C clear), and the jump
        sta     zbc
        sta     lb_va
        lda     #$80
        sta     lb_vf
        iny                             ; Y -> e
        bne     lb_jre                  ; (always)
lb_si:  lda     #0                      ; true: A = C = 0, Z (C clear), on to the next instruction
        sta     zbc
        sta     lb_va
        lda     #$02
        sta     lb_vf
        bne     lb_si0                  ; (always)

lb_tstp:                                ; F0-FF: the test `v n =`, the variable's address in the bytecode
        cmp     #$F8
        bcs     lb_tstm
lb_tst:                                 ; F0+p a n e: F8+p that leaves A, C and the Z80's flags as they were (the
        and     #$07                    ; code after it sets them before reading them)
        sta     lb_ld+2
        iny
        lda     (zhl),y                 ; a
        tax
        iny
lb_ld:  lda     $FF00,x                 ; (self-modified page) E
        cmp     (zhl),y
        beq     lb_si0
        iny                             ; false: Y -> e, the jump
lb_jre:                                 ; JR: ip := zhl + Y + 1 + e, e the signed byte at zhl + Y
        tya
        sec
        adc     (zhl),y
        bcs     lb_jrl
        bmi     lb_jrf
        tay                             ; forward, below zhl + 128: only Y moves
        bpl     lb_disp                 ; (always)
lb_si0: iny                             ; true: on to the next instruction
        iny
        bpl     lb_disp
        bmi     lb_norm
lb_ret: php                             ; C9 RET: A and the flags of the Z80 (the I flag kept); also called
        pla                             ; to set A and P for a native call
        and     #$04
        ora     lb_vf
        pha
        lda     lb_va
        plp
        rts
logica_b_vm:
        sta     lb_va
        php
        pla
        sta     lb_vf
        pla                             ; the JSR's return address + 1 is the first instruction: zhl + 1
        sta     zhl
        pla
        sta     zhl+1
        ldy     #1
lb_next:                                ; Y -> the next instruction, N = (Y >= 128) from its last INY
        bpl     lb_disp
lb_norm:                                ; zhl += Y, Y = 0
        tya
        clc
        adc     zhl
        sta     zhl
        bcc     :+
        inc     zhl+1
:       ldy     #0
lb_disp:
        lda     (zhl),y
lb_dispa:                               ; A = the opcode at zhl + Y
        cmp     #$F0
        bcs     lb_tstp
        cmp     #$C0
        bcc     lb_baja
        cmp     #$E0
        bcc     :+
        jmp     lb_tstx
:       cmp     #$D8
        bcs     lb_setn
        cmp     #$C9
        beq     lb_ret
        cmp     #$C2
        bne     :+
        jmp     lb_jpnz
:       cmp     #$CF
        bne     :+
        jmp     lb_test
:       jmp     lb_d2

lb_baja:                                ; below C0h: 18 20 3E 01 and the tests A0-B7
        cmp     #$A0
        bcs     lb_tq
        cmp     #$20
        bne     :+
        jmp     lb_jrnz
:       cmp     #$18
        bne     :+
        jmp     lb_jr
:       cmp     #$3E
        bne     :+
        jmp     lb_lda
:       lda     #0                      ; 01 XOR A
        sta     lb_va
        lda     #$02                    ; Z set, C and N clear
        sta     lb_vf
        iny
        jmp     lb_next

lb_tq:                                  ; A0+p / A8+p / B0+p a n e: `v n >` the jump when false, `v n =` the jump
        ldx     #$90                    ; when true, `v n <` the jump when false (the variable at page p, low byte
        cmp     #$A8                    ; a), leaving A, C and the flags as they were (nothing reads them before
        bcc     @br                     ; setting them again): the branch taken for the jump
        ldx     #$F0
        cmp     #$B0
        bcc     @br
        ldx     #$B0
@br:    stx     lb_brq
        and     #$07
        sta     lb_ldq+2
        iny
        lda     (zhl),y                 ; a
        tax
        iny
lb_ldq: lda     $FF00,x                 ; (self-modified page) E
        cmp     (zhl),y
lb_brq: bcc     @salto                  ; (self-modified: BCC '>', BEQ '=', BCS '<')
        iny
        iny
        jmp     lb_next
@salto: iny
        jmp     lb_jre

lb_setn:                                ; D8 v n: RST 10h v n, a literal; D9 v n: the same and RET; DA v n w m:
        cmp     #$DB                    ; D8 v n then D8 w m
        bcc     :+
        jmp     lb_rmw
:       sta     zt0
lb_set1:                                ; [v] := n: A and C := n, the flags of CP equal
        iny
        lda     (zhl),y                 ; v
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     D64_AI_SCRIPT_DEST_PTR
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     D64_AI_SCRIPT_DEST_PTR+1
        iny
        lda     (zhl),y                 ; n
        sta     zbc
        sta     lb_va
        ldx     #0
        sta     (D64_AI_SCRIPT_DEST_PTR,x)
        lda     #$02                    ; Z set, C and N clear
        sta     lb_vf
        lda     zt0
        cmp     #$D9
        beq     @ret
        bcs     @dos
        iny
        jmp     lb_next
@ret:   jmp     lb_ret
@dos:   lda     #$D8                    ; DA: then D8 w m
        sta     zt0
        bne     lb_set1
lb_test:                                ; CF expr: RST 08h
        iny
        jsr     estado_texto_eval_y
        php
        stx     lb_va
        tay
        pla
        and     #$FE                    ; AND A: Z and N of the value, C clear
        sta     lb_vf
        tya
        ldy     #0
        cmp     #$20
        beq     :+
        jmp     lb_dispa                ; the instruction after the expression; a JR NZ is done here:
:       txa
        bne     lb_jr                   ; NZ: the jump
        ldy     #2
        jmp     lb_disp

lb_jrnz:                                ; 20 e JR NZ
        lda     lb_vf
        and     #$02
        beq     lb_jr
        iny
        iny
        jmp     lb_next
lb_jr:  iny                             ; 18 e JR
        jmp     lb_jre

lb_tstx:                                ; E2-EC v .. e (Y -> the opcode); E2-EA: bit 0 of the opcode clear: the
        sta     zt0                     ; jump is taken when the test is true, set: when false
        cmp     #$EB
        bcs     lb_tstv
        tax
        lda     lb_brx-$E2,x            ; the branch taken when true
        sta     lb_brv
        iny
        lda     (zhl),y                 ; v
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     lb_ldx+1
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     lb_ldx+2
lb_ldx: lda     $FFFF                   ; (self-modified) E
        iny                             ; Y -> n / w / m
        ldx     zt0
        cpx     #$E7
        bcc     lb_cmpx                 ; E2-E6: E against the literal n
        cpx     #$E9
        bcs     @bit
        sta     zt0+1                   ; E7 E8: E against the variable w
        lda     (zhl),y
        jsr     lb_var
        cmp     zt0+1
        jmp     lb_brv
@bit:   and     (zhl),y                 ; E9 EA: E AND m against n
        iny
lb_cmpx:
        cmp     (zhl),y
lb_brv: beq     @si                     ; (self-modified: BEQ '=', BCS '>', BCC '<')
        lda     zt0                     ; false
        lsr     a
        bcc     @sigue                  ; the jump when true: on to the next test (which sets A, C and the flags)
        ldx     #$FF                    ; A = C = FFh, NZ (N set, C clear), and the jump
        lda     #$80
        bne     @m
@si:    lda     zt0                     ; true: A = C = 0, Z (C clear)
        ldx     #0
        lsr     a
        lda     #$02
        bcc     @m                      ; the jump when true
        sta     lb_vf                   ; the jump when false: on
        stx     zbc
        stx     lb_va
@sigue: iny
        iny
        jmp     lb_next
@m:     sta     lb_vf
        stx     zbc
        stx     lb_va
        iny
        jmp     lb_jre

lb_tstv:                                ; EB v e / EC v m e: the value [v] / [v] AND m (the last test of a chain):
        iny                             ; A = C = the value, its N and Z (C clear), the jump when it is not 0
        lda     (zhl),y
        jsr     lb_var
        iny
        ldx     zt0
        cpx     #$EC
        bcc     :+
        and     (zhl),y
        iny
:       sta     zbc
        sta     lb_va
        tax
        php
        pla
        and     #$82
        sta     lb_vf
        txa
        beq     :+
        jmp     lb_jre
:       iny
        jmp     lb_next

lb_var:                                 ; A = the script variable at offset A of D64_AI_SCRIPT_VARS (X = 0)
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     lb_ept
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     lb_ept+1
        ldx     #0
        lda     (lb_ept,x)
        rts

lb_rmw:                                 ; DB/DC/DD/DE v n: RST 10h v v n 26h/2Bh/2Ah/2Dh: [v] := [v] OR / + / AND / - n
        cmp     #$DE                    ; C: set for '-', clear for '+'
        tax
        lda     lb_alu-$DB,x
        sta     lb_op
        iny
        lda     (zhl),y                 ; v
        jsr     lb_dest
        iny
        ldx     #0
        lda     (D64_AI_SCRIPT_DEST_PTR,x)
lb_op:  ora     (zhl),y                 ; (self-modified: ORA, ADC, AND, SBC)
        sta     (D64_AI_SCRIPT_DEST_PTR,x)
lb_set2:                                ; A = C := the value, the flags of CP equal
        sta     zbc
        sta     lb_va
        lda     #$02
        sta     lb_vf
        iny
        jmp     lb_next

lb_d2:  cmp     #$D7
        beq     lb_set
        cmp     #$CD
        bne     :+
        jmp     lb_call
:       cmp     #$D0
        bcs     lb_corto
        bcc     lb_jp                   ; (always: C3)

lb_jpnz:                                ; C2 nn JP NZ
        lda     lb_vf
        and     #$02
        beq     lb_jp
        iny
        iny
        iny
        jmp     lb_next
lb_jp:  iny                             ; C3 nn JP to bytecode, C3 k 00 a tail call of lb_tabla[k]
        lda     (zhl),y
        tax
        iny
        lda     (zhl),y
        beq     lb_tail
        sta     zhl+1
        stx     zhl
        ldy     #0
        jmp     lb_disp
lb_tail:                                ; the tail call of lb_tabla[X] with the Z80's A and flags
        lda     lb_tabla,x
        sta     lb_tgt
        lda     lb_tabla+1,x
        sta     lb_tgt+1
        jsr     lb_ret
        jmp     (lb_tgt)

lb_lda: iny                             ; 3E n LD A,n
        lda     (zhl),y
        sta     lb_va
        iny
        jmp     lb_next

lb_set: iny                             ; D7 v expr: RST 10h
        lda     (zhl),y
        jsr     lb_dest
        iny
        jsr     estado_texto_eval_y
        stx     lb_va
        tay
        txa
        ldx     #0
        sta     (D64_AI_SCRIPT_DEST_PTR,x)
        lda     #$02                    ; the flags of CP equal
        sta     lb_vf
        tya
        ldy     #0
        jmp     lb_dispa

lb_corto:                               ; D0 b / D1 b: hud_say / hud_say_now b; D2 / D3: CALL
        cmp     #$D2                    ; ai_guillermo_is_close / hud_obsequium_minus_2; D4: JP ai_stay
        bcc     @dicho
        cmp     #$D4
        beq     @stay
        and     #$01
        asl     a
        adc     #10
        tax
        lda     lb_tabla,x
        sta     lb_tgt
        lda     lb_tabla+1,x
        sta     lb_tgt+1
        iny
        bne     lb_callgo
@dicho: and     #$01
        asl     a
        tax
        iny
        jsr     lb_tramp_x
        iny
        bne     lb_callgo
@stay:  ldx     #6
        bne     lb_tail

lb_call:                                ; CD nn CALL
        iny
        lda     (zhl),y
        tax
        iny
        lda     (zhl),y
        beq     lb_callt
        sta     lb_tgt+1
        stx     lb_tgt
        iny
lb_callgo:                              ; zhl + Y kept on the stack; the call with the Z80's A and flags
        tya
        clc
        adc     zhl
        tax
        lda     zhl+1
        adc     #0
        pha
        txa
        pha
        jsr     lb_ret
        jsr     lb_jind
        sta     lb_va
        php
        pla
        sta     lb_vf
        pla
        sta     zhl
        pla
        sta     zhl+1
        ldy     #0
        jmp     lb_disp
lb_callt:                               ; CD k 00: k = 0, 2, 4 a routine with an inline byte, 10 the switch
        cpx     #10
        beq     lb_switch
        iny
        jsr     lb_tramp_x
        iny
        bne     lb_callgo               ; (always)

lb_tramp_x:                             ; lb_tgt := the trampoline JSR lb_tabla[X] / .byte (zhl),Y / RTS
        lda     lb_tabla,x
        sta     lb_tramp+1
        lda     lb_tabla+1,x
        sta     lb_tramp+2
        lda     (zhl),y
        sta     lb_tramp+3
        lda     #<lb_tramp
        sta     lb_tgt
        lda     #>lb_tramp
        sta     lb_tgt+1
        rts

lb_switch:                              ; util_jump_table_inline 3A5D (Y -> the 00 of CD 0A 00): Z -> t0, else
        ldx     #1                      ; t[C]; past the 0 word when there is no such entry
        lda     lb_vf
        and     #$02
        bne     @tabla
        iny
        iny
        ldx     zbc
@tabla: iny
        lda     (zhl),y
        sta     lb_tgt
        iny
        lda     (zhl),y
        sta     lb_tgt+1
        ora     lb_tgt
        beq     @fin
        dex
        bne     @tabla
        lda     lb_tgt
        sta     zhl
        lda     lb_tgt+1
        sta     zhl+1
        ldy     #0
        jmp     lb_disp
@fin:   iny
        tya
        jmp     lb_next

lb_dest:                                ; ai_script_dest_ptr := the address of the variable at offset A (3910)
        tax
        lda     D64_AI_SCRIPT_VARS,x
        sta     D64_AI_SCRIPT_DEST_PTR
        lda     D64_AI_SCRIPT_VARS+1,x
        sta     D64_AI_SCRIPT_DEST_PTR+1
        rts

lb_jind:
        jmp     (lb_tgt)

; ================================================================ objects

; 4C46 obj_pick_up_objects: for each holder from IX to the FFh entry whose counter +6 runs out, the first object
; not taken this frame, not hidden, allowed by its masks and lying in front of it (its own position, or its
; holder's character's when held and the taker is not locked) is taken: from its old holder, spr_mark_leaving,
; record +0 := 81h, +2/+3 := the holder, holder +6 := 10h and its bit set.  The search stops when no allowed
; object is left (the Z80 goes on to the FFh record without effect).  Out: IX = the FFh entry.
lb_pu_next:                             ; the next holder
        lda     zix
        clc
        adc     #7
        sta     zix
        bcc     obj_pick_up_objects
        inc     zix+1
obj_pick_up_objects:
        ldy     #0
        lda     (zix),y
        cmp     #$FF
        bne     :+
        rts
:       jsr     lb_contador             ; the counter runs out: the search
        bne     lb_pu_next
        jsr     obj_front_position
        ldy     #4                      ; the mask: L = (+4 ^ +0) & +4, H = (+5 ^ +3) & +5
        lda     (zix),y
        ldy     #0
        eor     (zix),y
        ldy     #4
        and     (zix),y
        sta     zt0
        iny
        lda     (zix),y
        ldy     #3
        eor     (zix),y
        ldy     #5
        and     (zix),y
        sta     zt0+1
        ldy     #0
        lda     (zix),y
        and     #$01
        sta     D64_OBJ_HOLDER_LOCKED
        ldx     #0                      ; the record's offset (the sprite's: 4 times it)
@obj:   asl     zt0
        rol     zt0+1
        bcc     @skip
        lda     D64_OBJ_OBJECTS,x
        and     #$41                    ; taken this frame, hidden
        bne     @skip
        lda     D64_OBJ_OBJECTS+2,x     ; its position
        sta     zt0+2
        lda     D64_OBJ_OBJECTS+3,x
        sta     zt0+3
        lda     D64_OBJ_OBJECTS+4,x
        sta     zt0+4
        lda     D64_OBJ_OBJECTS,x
        bpl     @aqui
        lda     D64_OBJ_HOLDER_LOCKED   ; held: not by a locked taker; its holder's character's position
        bne     @skip
        lda     zt0+2
        sta     zp0+4
        lda     zt0+3
        sta     zp0+5
        ldy     #1
        lda     (zp0+4),y
        sta     zp0+6
        iny
        lda     (zp0+4),y
        sta     zp0+7
        ldy     #2
:       lda     (zp0+6),y
        sta     zt0+2,y
        dey
        bpl     :-
@aqui:  lda     zt0+4                   ; in front of the holder: height - front z < 5, x and y equal
        sec
        sbc     D64_OBJ_FRONT_Z
        cmp     #5
        bcs     @skip
        lda     zt0+2
        cmp     D64_OBJ_FRONT_X
        bne     @skip
        lda     zt0+3
        cmp     D64_OBJ_FRONT_Y
        beq     @toma
@skip:  txa                             ; the next object
        clc
        adc     #5
        tax
        lda     zt0
        ora     zt0+1
        beq     @next                   ; no allowed object left
        lda     D64_OBJ_OBJECTS,x
        cmp     #$FF
        bne     @obj
@next:  jmp     lb_pu_next
@toma:  txa                             ; n = X / 5: the object's bit HL' = 8000h >> n
        ldy     #0
        sty     lb_t2
        ldy     #$80
        sty     lb_t3
:       sec
        sbc     #5
        bcc     :+
        lsr     lb_t3
        ror     lb_t2
        jmp     :-
:       lda     D64_OBJ_OBJECTS,x
        bpl     @nuevo
        ldy     #0                      ; taken from its holder: its bit cleared
        lda     (zp0+4),y
        eor     lb_t2
        sta     (zp0+4),y
        ldy     #3
        lda     (zp0+4),y
        eor     lb_t3
        sta     (zp0+4),y
@nuevo: lda     zix                     ; the holder
        pha
        lda     zix+1
        pha
        txa
        pha
        txa                             ; IX := the object's sprite
        asl     a
        asl     a
        adc     #<D64_OBJ_SPRITES
        sta     zix
        lda     #>D64_OBJ_SPRITES
        adc     #0
        sta     zix+1
        jsr     spr_mark_leaving
        pla
        tax
        pla
        sta     zix+1
        sta     D64_OBJ_OBJECTS+3,x
        pla
        sta     zix
        sta     D64_OBJ_OBJECTS+2,x
        lda     #$81
        sta     D64_OBJ_OBJECTS,x
        ldy     #6
        lda     #$10
        sta     (zix),y
        ldy     #0
        lda     (zix),y
        ora     lb_t2
        sta     (zix),y
        ldy     #3
        lda     (zix),y
        ora     lb_t3
        sta     (zix),y
        jmp     lb_pu_next

; the holder IX's counter +6: decremented; when it reaches FFh it becomes 0 and Z is set (it ran out)
lb_contador:
        ldy     #6
        lda     (zix),y
        sec
        sbc     #1
        sta     (zix),y
        cmp     #$FF
        bne     :+
        lda     #0
        sta     (zix),y
:       rts

; 4EA5 obj_front_position: the cell in front of the character of holder IX: x + 2 dx, y + 2 dy (the step table
; 23A8h, 8 bytes an orientation) and its height, into obj_front_x/y/z.  Out: A = the height, C = x, B = y,
; DE -> the height, HL -> the step entry + 1.
obj_front_position:
        ldy     #1
        lda     (zix),y                 ; DE := [IX+1] - 1: the orientation
        sec
        sbc     #1
        sta     zde
        iny
        lda     (zix),y
        sbc     #0
        sta     zde+1
        ldy     #0
        lda     (zde),y                 ; HL := 23A8h + 8 orientation (8-bit product, 22E7)
        asl     a
        asl     a
        asl     a
        clc
        adc     #<D64_CHR_STEP_TABLE
        sta     zhl
        lda     #>D64_CHR_STEP_TABLE
        adc     #0
        sta     zhl+1
        lda     (zhl),y
        asl     a
        clc
        ldy     #1
        adc     (zde),y
        sta     D64_OBJ_FRONT_X
        sta     zbc
        lda     (zhl),y
        asl     a
        clc
        iny
        adc     (zde),y
        sta     D64_OBJ_FRONT_Y
        sta     zbc+1
        inc     zhl
        bne     :+
        inc     zhl+1
:       iny
        lda     zde
        clc
        adc     #3
        sta     zde
        bcc     :+
        inc     zde+1
:       ldy     #0
        lda     (zde),y
        sta     D64_OBJ_FRONT_Z
        rts

; 4D2A hud_draw_guillermo_objects: every slot (falls into 4D30).
hud_draw_guillermo_objects:
        lda     D64_GUILLERMO_OBJECTS
        sta     zbc
        lda     #$FF
; 4D30 hud_draw_objects: the score bar's object slots whose bit is set in A (bit 7 slot 0 .. bit 2 slot 5),
; from C591h, 5 bytes apart and one more after the third: an object held (its bit in C) from its sprite (+5
; width & 7Fh, +6 rows, +7 graphics: objects under the I/O), else cleared (4 x 12 of 00h).  Stops when no bit
; of A is left.
hud_draw_objects:
        sta     zde                     ; E: the slots to redraw
        lda     zbc
        sta     zde+1                   ; D: the objects held
        lda     #<$C591
        sta     zhl
        lda     #>$C591
        sta     zhl+1
        lda     #<D64_OBJ_SPRITES
        sta     lb_t2
        lda     #>D64_OBJ_SPRITES
        sta     lb_t3
        lda     #6
        sta     lb_t0
@slot:  asl     zde+1
        ror     lb_t1                   ; bit 7: held
        lda     zde
        beq     @fin
        asl     zde
        bcc     @sig
        bit     lb_t1
        bmi     @dibuja
        lda     #4                      ; cleared: 4 x 12 of CPC 00h (nibble 5)
        sta     zt0+2
        lda     #12
        sta     zt0+3
        lda     #$85
        sta     zt0+4
        jsr     lb_blit
        jmp     @sig
@dibuja:
        ldy     #5
        lda     (lb_t2),y
        and     #$7F
        sta     zt0+2
        iny
        lda     (lb_t2),y
        sta     zt0+3
        iny
        lda     (lb_t2),y
        sta     zp0
        iny
        lda     (lb_t2),y
        sta     zp0+1
        lda     #0
        sta     zt0+4
        lda     #MEM_RAM                    ; the objects' graphics are under the I/O
        sta     MEMCFG
        jsr     lb_blit
        lda     #MEM_IO
        sta     MEMCFG
@sig:   lda     zhl
        clc
        adc     #5
        sta     zhl
        bcc     :+
        inc     zhl+1
:       lda     lb_t2
        clc
        adc     #$14
        sta     lb_t2
        bcc     :+
        inc     lb_t3
:       lda     lb_t0
        cmp     #4
        bne     :+
        inc     zhl
:       dec     lb_t0
        bne     @slot
@fin:   rts

; 4D97 obj_update_key_permissions: Adso's key 3 (bit 1 of his objects) -> bit 4 of his doors (292Dh);
; Guillermo's key 1 (bit 3) -> bit 0, key 2 (bit 2) -> bit 2 of his (292Ah).  Out: A = his new byte.
obj_update_key_permissions:
        lda     D64_OBJ_ADSO_OBJECTS
        and     #$02
        asl     a
        asl     a
        asl     a
        sta     zbc
        lda     D64_OBJ_DOOR_PERMISSIONS_ADSO
        and     #$EF
        ora     zbc
        sta     D64_OBJ_DOOR_PERMISSIONS_ADSO
        lda     D64_GUILLERMO_OBJECTS
        and     #$08
        lsr     a
        lsr     a
        lsr     a
        sta     zbc
        lda     D64_GUILLERMO_OBJECTS
        and     #$04
        ora     zbc
        sta     zbc
        lda     D64_OBJ_DOOR_PERMISSIONS
        and     #$FA
        ora     zbc
        sta     D64_OBJ_DOOR_PERMISSIONS
        rts

.ifdef COMPLETO
; lb_espejado (abadia128ks): C = 1 when the graphic of selector A (orienta128.inc) is mirrored from its load: 1
; Guillermo's frames (his flip state), 2 Adso's, 3 the door leaf (obj_door_gfx_flipped clear: the PC's leaf is loaded
; with it set), 4 + k face block k (cabezas128.s par_c[k]); 0 none.  X, Y kept
lb_espejado:
        cmp     #1
        beq     @g
        cmp     #2
        beq     @a
        cmp     #3
        beq     @p
        bcc     @no                     ; (0)
        stx     lb_t3                   ; (a face block: its parity)
        sbc     #4
        tax
        lda     par_c,x
        ldx     lb_t3
        lsr     a
        rts
@g:     lda     D64_CHR_GUILLERMO+6
        lsr     a
        rts
@a:     lda     D64_CHR_ADSO+6
        lsr     a
        rts
@p:     lda     D64_OBJ_DOOR_GFX_FLIPPED
        cmp     #1                      ; (C = 1 when not 0)
        rol     a
        eor     #1                      ; (bit 0 = C of the CMP, inverted)
        lsr     a
        rts
@no:    clc
        rts
        .import par_c
.segment "RODATA"
        .include "orienta128.inc"
.segment "CODE"
.endif

; 4DC3 obj_drop_on_space: the space bar (CPC key 2Fh) down: Guillermo drops an object (into 4DCD).
obj_drop_on_space:
        lda     #$2F
        jsr     sys_key_down
        bne     :+
        rts
:       lda     #<D64_OBJ_CHAR_OBJECTS
        sta     zix
        lda     #>D64_OBJ_CHAR_OBJECTS
        sta     zix+1
; 4DCD obj_drop_object: holder IX drops its first object (the highest bit of +3) when its counter +6 runs out:
; in front of it if that cell of the height buffer (on the floor shown) is free, below 0Dh, at most 4 above the
; floor level and level with its three neighbours (else nothing); at its character's position when the floor
; or the buffer do not allow the test.  Then its record (bit 7 cleared, +4 height, +1 an orientation read
; where the original reads it, +2/+3 x/y) and obj_redraw_one_object.
obj_drop_object:
        ldy     #3
        lda     (zix),y
        ldx     #0
@busca: inx
        asl     a
        bcs     @hay
        cpx     #8
        bne     @busca
        rts
@hay:   stx     D64_OBJ_DROP_INDEX
        jsr     lb_contador
        beq     :+
        rts
:       jsr     obj_front_position      ; A = z, C = x, B = y
        ldx     zbc
        stx     lb_t0
        ldx     zbc+1
        stx     lb_t1
        jsr     iso_floor_base          ; B = the floor's base
        sec
        sbc     zbc+1
        sta     D64_OBJ_DROP_LEVEL
        lda     D64_CHR_SHOWN_FLOOR
        cmp     zbc+1
        bne     @aqui
        lda     zix                     ; the holder, kept
        pha
        lda     zix+1
        pha
        lda     lb_t0
        sta     zhl
        lda     lb_t1
        sta     zhl+1
        jsr     chr_to_hbuf_coords      ; C: outside the buffer
        bcs     @fuera
        jsr     iso_grid_cell_ptr       ; IX = the cell
        lda     zix
        sec
        sbc     #$19
        sta     zp0
        lda     zix+1
        sbc     #0
        sta     zp0+1
        ldy     #$19
        lda     (zp0),y
        and     #$F0
        bne     @falla
        lda     (zp0),y
        and     #$0F
        cmp     #$0D
        bcs     @falla
        sec
        sbc     D64_OBJ_DROP_LEVEL
        cmp     #5
        bcs     @falla
        lda     (zp0),y
        and     #$0F
        ldy     #$18                    ; [IX-1]
        cmp     (zp0),y
        bne     @falla
        ldy     #1                      ; [IX-18h]
        cmp     (zp0),y
        bne     @falla
        dey                             ; [IX-19h]
        cmp     (zp0),y
        bne     @falla
        clc
        adc     D64_CHR_SHOWN_FLOOR
        tax
        pla
        sta     zix+1
        pla
        sta     zix
        txa
        jmp     @pon
@falla: pla
        pla
        rts
@fuera: pla
        sta     zix+1
        pla
        sta     zix
@aqui:  ldy     #1                      ; at the character's position
        lda     (zix),y
        sta     zp0
        iny
        lda     (zix),y
        sta     zp0+1
        ldy     #0
        lda     (zp0),y
        sta     lb_t0
        iny
        lda     (zp0),y
        sta     lb_t1
        iny
        lda     (zp0),y
@pon:   sta     lb_t2                   ; the height
        ldy     #1                      ; the orientation: the byte at (height << 8) | the low byte of the CPC
        lda     (zix),y                 ; address of the character's orientation (2B88h - 055Ch: + 2Ch)
        clc
        adc     #$2B
        tax
        ldy     lb_t2
.ifdef COMPLETO
        ; abadia128ks, the full game: the byte the PC reads there, DS:hhF5 (Guillermo) / DS:hh22 (the abbot)
        ; (orienta128.inc, c64/certifica/pc/orienta128.py): as loaded, or mirrored when the graphic it lies in is
        cpx     #$88
        bne     @ab
        lda     lb_or128_guillermo_sel,y
        jsr     lb_espejado
        lda     lb_or128_guillermo_lo,y
        bcc     @o
        lda     lb_or128_guillermo_esp,y
        jmp     @o
@ab:    lda     lb_or128_abad_sel,y
        jsr     lb_espejado
        lda     lb_or128_abad_lo,y
        bcc     @o
        lda     lb_or128_abad_esp,y
        jmp     @o
.endif
        cpy     #1
        beq     @h1
        cpy     #2
        beq     @h2
        cpx     #$88
        beq     @g
        lda     lb_orient_abbot,y
        jmp     @o
@g:     lda     lb_orient_guillermo,y
        jmp     @o
@h1:    lda     D64_GAME_INITIAL_STATE-$03,x    ; CPC 0100h + L
        jmp     @o
@h2:    lda     D64_CHR_ROOM_LINKS-$3D,x        ; CPC 0200h + L
@o:     eor     #$02
        sta     lb_t3
        ldy     #6
        lda     #$10
        sta     (zix),y
        ldx     D64_OBJ_DROP_INDEX      ; its bit cleared: 80h >> (n - 1) of +3 (the low byte is 0)
        lda     #0
        sec
:       ror     a
        dex
        bne     :-
        eor     #$FF
        ldy     #3
        and     (zix),y
        sta     (zix),y
        lda     D64_OBJ_DROP_INDEX      ; IY := its record (+ 5 (n - 1)), IX := its sprite (+ 14h (n - 1))
        sec
        sbc     #1
        sta     zt0
        asl     a
        asl     a
        adc     zt0
        tax
        clc
        adc     #<D64_OBJ_OBJECTS
        sta     ziy
        lda     #>D64_OBJ_OBJECTS
        adc     #0
        sta     ziy+1
        txa
        asl     a
        asl     a
        adc     #<D64_OBJ_SPRITES
        sta     zix
        lda     #>D64_OBJ_SPRITES
        adc     #0
        sta     zix+1
        lda     D64_OBJ_OBJECTS,x       ; the record: bit 7 cleared, +4 height, +1 orientation, +2/+3 x/y
        and     #$7F
        sta     D64_OBJ_OBJECTS,x
        lda     lb_t2
        sta     D64_OBJ_OBJECTS+4,x
        lda     lb_t3
        sta     D64_OBJ_OBJECTS+1,x
        lda     lb_t0
        sta     D64_OBJ_OBJECTS+2,x
        lda     lb_t1
        sta     D64_OBJ_OBJECTS+3,x
        jmp     obj_redraw_one_object

; ================================================================ the mirror

; 4ECA iso_mirror_update: while the mirror is closed, the reflections of Guillermo and Adso (BC, DE, HL, IX, IY
; from lb_espejos; Adso's call is the Z80's fall into 4EF4).
iso_mirror_update:
        lda     D64_OBJ_MIRROR_CLOSED
        beq     @fin
        ldx     #0
        jsr     @uno
        ldx     #10
@uno:   ldy     #0
:       lda     lb_espejos,x
        sta     zbc,y
        inx
        iny
        cpy     #10
        bne     :-
        beq     iso_mirror_character
@fin:   rts

; 4EF4 iso_mirror_character: [state] := iso_mirror_reflect's L; not shown (FEh): bit 7 of the sprite's +0Bh
; cleared.  In: as 4F03.
iso_mirror_character:
        lda     zbc
        pha
        lda     zbc+1
        pha
        jsr     iso_mirror_reflect
        pla
        sta     zbc+1
        pla
        sta     zbc
        lda     zhl
        ldy     #0
        sta     (zbc),y
        cmp     #$FE
        bne     :+
        ldy     #$0B
        lda     (zix),y
        and     #$7F
        sta     (zix),y
:       rts

; 4F03 iso_mirror_reflect: the mirror image of character IY (sprite IX) when the height buffer is at the
; mirror's room (origin 1Ch, 5Ch) and the character stands on floor 16h (below +8), x 20h-29h, y 62h-6Bh:
; mirrored (x := 42h - x, one less with bit 7 of +5; orientation XOR 2 when even; +0 XOR 2), chr_cur_flip :=
; 4FC9, chr_cur_anim := DE, sprite +0Bh bit 7, chr_animate; the sprite's old position and size from the
; previous image when one was shown; the state words := the new ones; the character restored.  The operands
; 4FD9 (buffer), 4FA9 (state +0), 4F9A/4FA2 (state+1), 4F9E/4FA6 (state+3) are set first.
; In: HL = buffer, BC = state, DE = animation table, IX = sprite, IY = character.  Out: L = 00h or FEh.
iso_mirror_reflect:
        lda     zhl
        sta     D64_ISO_MIRROR_BUFFER
        lda     zhl+1
        sta     D64_ISO_MIRROR_BUFFER+1
        lda     #$FE
        sta     zhl
        lda     D64_CHR_HBUF_ORIGIN_X
        cmp     #$1C
        bne     @no
        lda     D64_CHR_HBUF_ORIGIN_Y
        cmp     #$5C
        bne     @no
        ldy     #0
        lda     (zbc),y
        sta     D64_ISO_MIRROR_SHOWN
        ldx     #6                      ; the operands (old pos, old size, new pos, new size in zero page):
:       txa                             ; state + 1, + 3, + 1, + 3
        and     #$02
        sec
        adc     zbc
        sta     D64_ISO_MIRROR_OLD_POS_OP,x
        lda     zbc+1
        adc     #0
        sta     D64_ISO_MIRROR_OLD_POS_OP+1,x
        dex
        dex
        bpl     :-
        .assert D64_ISO_MIRROR_OLD_SIZE_OP = D64_ISO_MIRROR_OLD_POS_OP + 2, error, "mirror operands"
        .assert D64_ISO_MIRROR_NEW_POS_OP = D64_ISO_MIRROR_OLD_POS_OP + 4, error, "mirror operands"
        .assert D64_ISO_MIRROR_NEW_SIZE_OP = D64_ISO_MIRROR_OLD_POS_OP + 6, error, "mirror operands"
        ldy     #4
        lda     (ziy),y
        jsr     iso_floor_base          ; B = the floor's base
        sec
        sbc     zbc+1
        cmp     #8
        bcs     @no
        lda     zbc+1
        cmp     #$16
        bne     @no
        ldy     #2
        lda     (ziy),y
        sta     zbc+1                   ; B = x
        sec
        sbc     #$20
        bcc     @no
        cmp     #$0A
        bcs     @no
        iny
        lda     (ziy),y
        sec
        sbc     #$62
        bcc     @no
        cmp     #$0A
        bcc     @si
@no:    rts
@si:    ldy     #1
        lda     (ziy),y
        sta     zbc                     ; C = the orientation
        dey
        lda     (ziy),y
        pha                             ; the flags, kept
        eor     #$02
        sta     (ziy),y
        lda     zbc+1
        pha
        lda     zbc
        pha
        lda     #$42                    ; x := 21h - (x - 21h)
        sec
        sbc     zbc+1
        ldy     #2
        sta     (ziy),y
        lda     zbc
        lsr     a
        lda     zbc
        bcs     :+
        eor     #$02
:       dey
        sta     (ziy),y
        ldy     #5
        lda     (ziy),y
        bpl     :+
        ldy     #2
        lda     (ziy),y
        sec
        sbc     #1
        sta     (ziy),y
:       lda     #<iso_mirror_draw_callback
        sta     D64_CHR_CUR_FLIP
        lda     #>iso_mirror_draw_callback
        sta     D64_CHR_CUR_FLIP+1
        lda     zde
        sta     D64_CHR_CUR_ANIM
        lda     zde+1
        sta     D64_CHR_CUR_ANIM+1
        ldy     #$0B
        lda     (zix),y
        ora     #$80
        sta     (zix),y
        ldy     #0
        lda     (zix),y
        jsr     chr_animate
        ldx     #3                      ; the state's words := the new position and size; the sprite's old
@pos:   ldy     lb_esp_nue,x            ; ones := the previous image's when one was shown (state +0 not
        lda     (zix),y                 ; FEh), else the new ones
        sta     zt0
        txa
        tay
        lda     (D64_ISO_MIRROR_OLD_POS_OP),y
        pha
        lda     zt0
        sta     (D64_ISO_MIRROR_OLD_POS_OP),y
        pla
        ldy     D64_ISO_MIRROR_SHOWN
        cpy     #$FE
        bne     :+
        lda     zt0
:       ldy     lb_esp_vie,x
        sta     (zix),y
        dex
        bpl     @pos
        pla                             ; the character restored
        ldy     #1
        sta     (ziy),y
        pla
        iny
        sta     (ziy),y
        pla
        ldy     #0
        sta     (ziy),y
        sty     zhl                     ; L = 00h: drawn
        rts

; 4FC9 iso_mirror_draw_callback: chr_animate's flip routine for a mirror image (IX = the sprite): its
; graphic (+7, +5 width in CPC bytes, +6 rows; ceil(w/2) bytes a row on the C64) copied to the buffer
; iso_mirror_buffer, +7 := the buffer, and spr_flip_graphics_h (HL = buffer, C = width, B = rows).
iso_mirror_draw_callback:
.ifdef C128
        jsr     cab_espejo              ; the C128: the frame copied noted for the reflection's head (cabezas128.s)
.endif
        ldy     #5
        lda     (zix),y
        sta     zbc                     ; C = the width
        clc
        adc     #1
        lsr     a
        sta     zt0                     ; bytes a row
        iny
        lda     (zix),y
        sta     zbc+1                   ; B = the rows
        iny
        lda     (zix),y
        sta     zp0
        lda     D64_ISO_MIRROR_BUFFER
        sta     zp0+2
        sta     zhl
        sta     (zix),y
        iny
        lda     (zix),y
        sta     zp0+1
        lda     D64_ISO_MIRROR_BUFFER+1
        sta     zp0+3
        sta     zhl+1
        sta     (zix),y
        ldx     zbc+1
@fila:  ldy     #0
:       lda     (zp0),y
        sta     (zp0+2),y
        iny
        cpy     zt0
        bne     :-
        tya
        clc
        adc     zp0
        sta     zp0
        bcc     :+
        inc     zp0+1
:       tya
        clc
        adc     zp0+2
        sta     zp0+2
        bcc     :+
        inc     zp0+3
:       dex
        bne     @fila
        jmp     spr_flip_graphics_h

; ================================================================ the clock and the score bar

; 4FEF hud_scroll_hour_name: once a frame while hud_hour_scroll_steps > 0: one step less; the 12-byte box of the
; hour name (8 lines at E583h) moves 2 CPC bytes (a C64 byte) left and txt_draw_char (cursor B40Dh) draws a
; space in the first two steps, then the next letter of the name.
hud_scroll_hour_name:
        lda     D64_HUD_HOUR_SCROLL_STEPS
        bne     :+
        rts
:       sec
        sbc     #1
        sta     D64_HUD_HOUR_SCROLL_STEPS
        cmp     #7
        lda     #$20
        bcs     :+
        lda     D64_HUD_HOUR_NAME_PTR
        sta     zp0
        lda     D64_HUD_HOUR_NAME_PTR+1
        sta     zp0+1
        ldy     #0
        lda     (zp0),y
        inc     D64_HUD_HOUR_NAME_PTR
        bne     :+
        inc     D64_HUD_HOUR_NAME_PTR+1
:       pha
        lda     #<D64_TXT_CURSOR_HOUR_NAME
        sta     D64_TXT_CURSOR
        lda     #>D64_TXT_CURSOR_HOUR_NAME
        sta     D64_TXT_CURSOR+1
        lda     #<$E581                 ; the bitmap byte of E581h: the C64 byte before the box's first
        sta     zhl                     ; (E583h is the low nibble of the next one)
        lda     #>$E581
        sta     zhl+1
        jsr     lb_scr
        lda     #8
        sta     zt0+3
@fila:  lda     zp0+2                   ; zp0+4: the next C64 byte (+8)
        clc
        adc     #8
        sta     zp0+4
        lda     zp0+3
        adc     #0
        sta     zp0+5
        ldy     #0                      ; the 7 bytes from the one before the box, left to right: each
        ldx     #0                      ; from the next, the first and last only in their box's nibbles
:       lda     (zp0+4),y
        eor     (zp0+2),y
        and     lb_masc,x
        eor     (zp0+2),y
        sta     (zp0+2),y
        tya
        clc
        adc     #8
        tay
        inx
        cpx     #7
        bne     :-
        jsr     lb_nextline
        dec     zt0+3
        bne     @fila
        pla
        jmp     txt_draw_char

; 5028 ai_clock_init: a new game: game_day := [BF4Fh], game_hour := [BF4Eh].  Out: A = the hour.
ai_clock_init:
        lda     D64_GAME_START_DAY
        sta     D64_GAME_DAY
        lda     D64_GAME_START_HOUR
        sta     D64_GAME_HOUR
        rts

; 5035 ai_clock_redraw: the clock after a start: the day palette for prima..visperas (hour - 1 < 5), else the
; night's; the day; game_hour := hour - 1, the name of the hour, and the hour entered again (5094).
ai_clock_redraw:
        lda     D64_GAME_HOUR
        sec
        sbc     #1
        pha
        cmp     #5
        bcs     :+
        jsr     vid_palette_day
        jmp     :++
:       jsr     vid_palette_night
:       lda     D64_GAME_DAY
        jsr     hud_set_and_draw_day
        pla
        sta     D64_GAME_HOUR
        clc                             ; hud_hour_name_ptr := 4B12h + 7 (hour - 1 + 1), 8-bit product
        adc     #1
        sta     zt0
        asl     a
        asl     a
        asl     a
        sec
        sbc     zt0
        clc
        adc     #<D64_HUD_HOUR_NAMES
        sta     D64_HUD_HOUR_NAME_PTR
        lda     #>D64_HUD_HOUR_NAMES
        adc     #0
        sta     D64_HUD_HOUR_NAME_PTR+1
        jmp     ai_clock_advance_hour

; 5060 ai_clock_load_duration: ai_hour_frames_left := ai_hour_durations[7 (day - 1) + hour] << 8.  Out: HL.
ai_clock_load_duration:
        lda     D64_GAME_DAY
        sec
        sbc     #1
        sta     zt0
        asl     a
        asl     a
        asl     a
        sec
        sbc     zt0                     ; 7 (day - 1), 8-bit
        clc
        adc     #<D64_AI_HOUR_DURATIONS
        sta     zp0
        lda     #>D64_AI_HOUR_DURATIONS
        adc     #0
        sta     zp0+1
        ldy     D64_GAME_HOUR
        lda     (zp0),y
        sta     zhl+1
        sta     D64_AI_HOUR_FRAMES_LEFT+1
        lda     #0
        sta     zhl
        sta     D64_AI_HOUR_FRAMES_LEFT
        rts

; 507D ai_clock_tick: once a frame: sys_key_pressed(6) and util_return_zero (the CPC's skip-the-hour test,
; always Z), then ai_hour_frames_left counts down when not 0; at 0 the hour advances.
ai_clock_tick:
        lda     #6
        jsr     sys_key_pressed
        jsr     util_return_zero
        bne     ai_clock_advance_hour
        lda     D64_AI_HOUR_FRAMES_LEFT
        ora     D64_AI_HOUR_FRAMES_LEFT+1
        bne     :+
        rts
:       lda     D64_AI_HOUR_FRAMES_LEFT
        bne     :+
        dec     D64_AI_HOUR_FRAMES_LEFT+1
:       dec     D64_AI_HOUR_FRAMES_LEFT
        lda     D64_AI_HOUR_FRAMES_LEFT
        ora     D64_AI_HOUR_FRAMES_LEFT+1
        beq     ai_clock_advance_hour
        rts

; 5094 ai_clock_advance_hour: hour + 1, the scroll of its name (9 steps) and its duration; after completas:
; the first name, day + 1 (8 -> 1) and hud_set_and_draw_day.
ai_clock_advance_hour:
        lda     D64_GAME_HOUR
        clc
        adc     #1
        cmp     #7
        bne     lb_hora
        lda     #<D64_HUD_HOUR_NAMES
        sta     D64_HUD_HOUR_NAME_PTR
        lda     #>D64_HUD_HOUR_NAMES
        sta     D64_HUD_HOUR_NAME_PTR+1
        lda     D64_GAME_DAY
        clc
        adc     #1
        sta     D64_GAME_DAY
        cmp     #8
        bcc     lb_dia
        lda     #1
; 50AF hud_set_and_draw_day: game_day := A and its three numeral glyphs (hud_roman_days + 3 (day - 1)) at
; ED09h; game_hour := 0, the scroll (9) and the duration.
hud_set_and_draw_day:
        sta     D64_GAME_DAY
lb_dia: sec
        sbc     #1
        sta     zt0
        asl     a
        clc
        adc     zt0
        clc
        adc     #<D64_HUD_ROMAN_DAYS
        sta     zde
        lda     #>D64_HUD_ROMAN_DAYS
        adc     #0
        sta     zde+1
        lda     #<$ED09
        sta     zhl
        lda     #>$ED09
        sta     zhl+1
        jsr     hud_draw_day_numeral
        jsr     hud_draw_day_numeral
        jsr     hud_draw_day_numeral
        lda     #0
lb_hora:
        sta     D64_GAME_HOUR
.ifdef C128
        cmp     #6                      ; the C128: completas, the PC version's Ave Maria (its 5AAF-5AB3;
        bne     :+                      ; plataforma/c128.s c128_ave; 3 NOPs when the menu's option 4 is off)
::c128_ave_llamada:
        jsr     c128_ave
:
.endif
        lda     #9
        sta     D64_HUD_HOUR_SCROLL_STEPS
        jmp     ai_clock_load_duration

; 50D9 hud_draw_day_numeral: one glyph of the day numeral, 2 CPC bytes x 8 lines at HL: [DE] = 2 'I', 1 'V',
; 0 the blank one (its row read again each line: the opcode at 50FEh DEC BC instead of INC BC).  The numerals
; are under the I/O.  Out: HL + 2, DE + 1.
hud_draw_day_numeral:
        lda     #$03                    ; INC BC
        sta     D64_HUD_DAY_GLYPH_STEP
        ldy     #0
        lda     (zde),y
        ldx     #<(G_ROMANOS+8)         ; 'I'
        ldy     #>(G_ROMANOS+8)
        cmp     #2
        beq     @dibuja
        ldx     #<G_ROMANOS             ; 'V'
        ldy     #>G_ROMANOS
        cmp     #0
        bne     @dibuja
        lda     #$0B                    ; DEC BC: the blank row (FF FF: nibbles 0)
        sta     D64_HUD_DAY_GLYPH_STEP
        lda     #$80
        bne     :+
@dibuja:
        stx     zp0
        sty     zp0+1
        lda     #0
:       sta     zt0+4
        lda     #2
        sta     zt0+2
        lda     #8
        sta     zt0+3
        lda     #MEM_RAM
        sta     MEMCFG
        jsr     lb_blit
        lda     #MEM_IO
        sta     MEMCFG
        lda     zhl
        clc
        adc     #2
        sta     zhl
        bcc     :+
        inc     zhl+1
:       inc     zde
        bne     :+
        inc     zde+1
:       rts

; 510C ai_timers_tick: once a frame: ai_clock_tick, ai_lamp_event := ai_lamp_tick (C), ai_night_ending :=
; ai_night_end_tick (C).  BC, DE, HL kept.  Out: A = ai_night_ending.
ai_timers_tick:
        ldx     #5
:       lda     zbc,x
        pha
        dex
        bpl     :-
        jsr     ai_clock_tick
        jsr     ai_lamp_tick
        lda     zbc
        sta     D64_AI_LAMP_EVENT
        jsr     ai_night_end_tick
        lda     zbc
        sta     D64_AI_NIGHT_ENDING
        tay
        ldx     #0
:       pla
        sta     zbc,x
        inx
        cpx     #6
        bne     :-
        tya
        rts

; 5124 hud_obsequium_minus_2: hud_obsequium_sub(2).
hud_obsequium_minus_2:
        jsr     hud_obsequium_sub
        .byte   $02
        rts

; 5129 hud_obsequium_sub: `JSR hud_obsequium_sub / .byte n`: hud_obsequium -= n; below 0 it becomes 0 and, unless
; the game is over, ai_abbot_state := 0Bh (the abbot expels Guillermo); the bar (CDB4h): obsequium / 4 bytes
; 0Fh, one byte FFh >> (obsequium & 3) (the CPC's tail table 5180h), the rest of the 8 bytes FFh.
hud_obsequium_sub:
        pla                             ; the inline byte, and the return past it
        clc
        adc     #1
        sta     zp0
        pla
        adc     #0
        sta     zp0+1
        pha
        lda     zp0
        pha
        ldy     #0
        lda     D64_HUD_OBSEQUIUM
        sec
        sbc     (zp0),y
        bcs     :+
        lda     D64_GAME_GUILLERMO_DEAD
        bne     @cero
        lda     #$0B
        sta     D64_AI_ABBOT_STATE
@cero:  lda     #0
:       sta     D64_HUD_OBSEQUIUM
        and     #$03
        tax
        lda     #$FF
        cpx     #0
        beq     @cola
:       lsr     a
        dex
        bne     :-
@cola:  sta     lb_t0                   ; the tail's CPC byte
        lda     #<$CDB4
        sta     zhl
        lda     #>$CDB4
        sta     zhl+1
        lda     D64_HUD_OBSEQUIUM
        lsr     a
        lsr     a
        sta     lb_t1
        ldx     #$0F
        stx     zde+1
        jsr     hud_fill_bar
        lda     lb_t0
        sta     zde+1
        lda     #1
        jsr     hud_fill_bar
        lda     #$FF
        sta     zde+1
        lda     #7
        sec
        sbc     lb_t1
; 5164 hud_fill_bar: the byte D in A consecutive screen bytes from HL, 6 lines each; HL + A.
hud_fill_bar:
        cmp     #0
        bne     :+
        rts
:       sta     zt0+2
        lda     #6
        sta     zt0+3
        lda     zde+1                   ; the CPC byte as a C64 nibble (the rule der: the right pixels)
        jsr     lb_der
        ora     #$80
        sta     zt0+4
        jsr     lb_blit
        lda     zhl
        clc
        adc     zt0+2
        sta     zhl
        bcc     :+
        inc     zhl+1
:       rts

; 5184 obj_read_manuscript: Guillermo holds the glasses and the parchment: the stair numeral, chosen once at
; random (the CPC's LD A,R: plat_aleatorio; & 3, 0 -> 1), set again, and phrase 00h.
obj_read_manuscript:
        lda     D64_OBJ_MIRROR_NUMERAL
        bne     :+
        jsr     plat_aleatorio
        and     #$03
        bne     :+
        lda     #1
:       jsr     obj_set_mirror_numeral
        jsr     hud_say
        .byte   $00
        rts

; 5199 obj_set_mirror_numeral: obj_mirror_numeral := A and its three letters (IXX, XIX, XXI at 5177h + 3 (n-1))
; over the dictionary word B59Eh.
obj_set_mirror_numeral:
        sta     D64_OBJ_MIRROR_NUMERAL
        sec
        sbc     #1
        sta     zt0
        asl     a
        clc
        adc     zt0
        tax
        ldy     #0
:       lda     D64_OBJ_MIRROR_NUMERALS,x
.ifdef C128
        jsr     far_numeral             ; (the words in block 1: plataforma/c128.s)
.else
        sta     D64_TXT_WORD_AAA,y
.endif
        inx
        iny
        cpy     #3
        bne     :-
        rts

; ---------------------------------------------------------------- the score bar's drawing

; lb_blit: a block of zt0+2 nibbles (CPC bytes) x zt0+3 lines (0 = 256) on the screen from the CPC screen
; address zhl, the lines as vid_next_line: from the graphic at zp0 (C64 format: ceil(w/2) bytes a row, the
; high nibble first) or, with bit 7 of zt0+4 set, the nibble zt0+4 & 0Fh everywhere.  zhl kept.
lb_blit:
        jsr     lb_scr
@fila:  lda     zp0+2
        sta     zp0+4
        lda     zp0+3
        sta     zp0+5
        lda     zt0+5
        sta     zt0+6
        ldx     zt0+2
        ldy     #0
        sty     zt0+1                   ; the source nibble: 0 high
@nib:   lda     zt0+4
        bmi     @pon
        lda     zt0+1
        inc     zt0+1
        lsr     a
        lda     (zp0),y
        bcs     @bajo
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        bpl     @pon
@bajo:  iny
@pon:   and     #$0F                    ; the nibble at the cursor
        sty     zt0
        ldy     #0
        bit     zt0+6
        bpl     @izq
        asl     a
        asl     a
        asl     a
        asl     a
        sta     zt0+7
        lda     (zp0+4),y
        and     #$0F
        ora     zt0+7
        sta     (zp0+4),y
        lsr     zt0+6                   ; next: the low nibble
        bpl     @sig
@izq:   sta     zt0+7
        lda     (zp0+4),y
        and     #$F0
        ora     zt0+7
        sta     (zp0+4),y
        lda     #$80                    ; next: the high nibble of the next C64 byte (+8: the next cell)
        sta     zt0+6
        lda     zp0+4
        clc
        adc     #8
        sta     zp0+4
        bcc     @sig
        inc     zp0+5
@sig:   ldy     zt0
        dex
        bne     @nib
        lda     zt0+4
        bmi     :+
        lda     zt0+1                   ; the graphic's next row: ceil(w/2) bytes
        lsr     a
        bcc     :+
        iny
:       tya
        clc
        adc     zp0
        sta     zp0
        bcc     :+
        inc     zp0+1
:       jsr     lb_nextline
        dec     zt0+3
        bne     @fila
        rts

; lb_scr: the CPC screen address zhl -> zp0+2 = its bitmap byte ($E000 + 320 row + 8 (xb / 2 + 4) + line),
; zt0+5 = 80h when the high nibble (xb even), else 0.
lb_scr: lda     zhl
        and     #1
        eor     #1
        lsr     a
        ror     a
        sta     zt0+5
        lda     zhl+1
        and     #$07
        sta     zt0+1
        lda     zhl
        asl     a
        rol     zt0+1
        asl     a
        rol     zt0+1                   ; the character row
        lda     zt0+1
        lsr     a
        lsr     a
        clc
        adc     zt0+1
        adc     #$E0
        sta     zp0+3                   ; $E0 + row + row / 4: the high byte of $E000 + 320 row
        lda     zt0+1
        ror     a
        ror     a
        ror     a
        and     #$C0
        sta     zp0+2                   ; 64 (row & 3)
        lda     zhl+1
        lsr     a
        lsr     a
        lsr     a
        and     #$07
        ora     #$20                    ; the line + 32 (cells 0-3)
        sta     zt0+1
        lda     zhl
        and     #$3E
        asl     a
        asl     a
        adc     zt0+1
        bcc     :+
        inc     zp0+3
        clc
:       adc     zp0+2
        sta     zp0+2
        bcc     :+
        inc     zp0+3
:       rts

; lb_nextline: zp0+2 one screen line down (vid_next_line): +1 in a cell, +320 - 7 from its last line
lb_nextline:
        lda     zp0+2
        and     #7
        cmp     #7
        beq     :+
        inc     zp0+2
        rts
:       lda     zp0+2
        clc
        adc     #<(320-7)
        sta     zp0+2
        lda     zp0+3
        adc     #>(320-7)
        sta     zp0+3
        rts

; lb_der: A = a CPC byte -> A = its C64 nibble by the rule der (the right pixel of each pair: pen bits
; b6/b2 and b4/b0; pens 3 0 1 2 -> 00 01 10 11: high bit lo ^ hi, low bit !lo)
lb_der: pha
        and     #$05
        asl     a
        asl     a
        asl     a
        asl     a
        sta     zt0
        pla
        and     #$50
        pha
        eor     zt0
        lsr     a
        lsr     a
        lsr     a
        sta     zt0
        pla
        eor     #$50
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        ora     zt0
        rts

; ================================================================ the scripts (bytecode)

; logica_b_guiones.s (guiones64.py): the script functions, their bytecode, the tables of obj_drop_object's
; orientation quirk (lb_orient_guillermo, lb_orient_abbot)
        .import lb_orient_guillermo, lb_orient_abbot


.segment "RODATA"
; iso_mirror_update: BC (state), DE (animation table), HL (image buffer), IX (sprite), IY (character)
lb_espejos:
        .word   D64_ISO_MIRROR_STATE_GUILLERMO, D64_CHR_ANIM_GUILLERMO, D64_ISO_MIRROR_BUF_GUILLERMO
        .word   D64_SPR_GUILLERMO, D64_CHR_GUILLERMO
        .word   D64_ISO_MIRROR_STATE_ADSO, D64_CHR_ANIM_ADSO, D64_ISO_MIRROR_BUF_ADSO, D64_SPR_ADSO, D64_CHR_ADSO
; iso_mirror_reflect: the sprite's new position and size (+1 +2 +5 +6) and where the drawn ones go (+3 +4 +9 +10)
lb_esp_nue:
        .byte   1, 2, 5, 6
lb_esp_vie:
        .byte   3, 4, 9, 10
; hud_scroll_hour_name: the bits each byte of a line takes from the next (the box starts and ends in nibbles)
lb_masc:
        .byte   $0F, $FF, $FF, $FF, $FF, $FF, $F0
; logica_b_vm's DB-DE: the operation (ORA, ADC, AND, SBC (zhl),y)
lb_alu: .byte   $11, $71, $31, $F1
; logica_b_vm's tests E2-EA: the branch taken when true (BEQ '=', BCS '>', BCC '<')
lb_brx: .byte   $F0, $B0, $B0, $90, $90, $F0, $F0, $F0, $F0
; logica_b_vm's native routines: CALL k 00 (with an inline byte) and JP k 00 (a tail call)
lb_tabla:
        .word   hud_say, hud_say_now, game_set_c004_inline, ai_stay, ai_next_state_on_arrival
        .word   ai_guillermo_is_close, hud_obsequium_minus_2

.segment "DATA"
; the VM's trampoline for the routines that read a byte after their call: JSR routine / .byte b / RTS
lb_tramp:
        .byte   $20, 0, 0, 0, $60
