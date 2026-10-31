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

; abadia64ks, 6502 code of the game: group logica_a, part 2 (Z80 3F92-441E; C reference juego/f_logica_a.c):
; the path searches (the room's height buffer and the floor's screen map), Adso's steps, the movement command
; writers.
;
; The searches keep their queue where the Z80 kept it, below 877Eh (D64_PATH_QUEUE on the C64), growing down,
; and leave the same bytes there: the Z80 used its stack as the queue, so the words just below the queue's top
; hold the return addresses of its CALLs and the registers it pushed (the queue word's address, the word);
; those words are written here too (Z80 constants, the address as the CPC's), so that the shadow check sees the
; same memory.  They are never read.  la_q = the queue's top - 6: [top] = (la_q),6, [top-2] = (la_q),4, ...
        .include "logica_a.inc"

        .export chr_path_room_to_marked, chr_path_room_search, chr_path_floor_to_screen, chr_path_floor_search
        .export chr_path_floor_cell_ptr
        .export chr_adso_step_guillermo_dir, chr_adso_step_prepare, chr_adso_step_aside, chr_adso_step_restore
        .export chr_cmd_write_one_step, chr_cmd_turn_and_step, chr_cmd_write_path, chr_cmd_write_step
        .export chr_cmd_write_turn, chr_cmd_generate

        .import iso_grid_cell_ptr, plat_di, plat_ei
        .import chr_mark_hbuf, ai_update_adso, chr_cmd_write_bits, chr_probe_ahead, chr_apply_step
        .import chr_orientation_parity, chr_to_hbuf_coords

.segment "CODE"

; ---- shared pieces of the searches ----

; la_q -= 2 (one word pushed)
.proc la_baja
        lda     la_q
        sec
        sbc     #2
        sta     la_q
        bcs     :+
        dec     la_q+1
:       rts
.endproc

; push the word XA (A low, X high): [top - 2] := XA, top -= 2
.proc la_mete
        pha
        jsr     la_baja
        pla
        ldy     #6
        sta     (la_q),y
        iny
        txa
        sta     (la_q),y
        rts
.endproc







; 40DE: the end of a search: chr_path_result := A, EI.  Out: A = the result.
.proc la_fin_busqueda
        sta     D64_CHR_PATH_RESULT
        jsr     plat_ei
        lda     D64_CHR_PATH_RESULT
        rts
.endproc

; 4080 chr_path_check_square: can a character stand on the 2x2 square whose top-right cell is (la_c),Y (cells
; Y, Y-1, Y-24, Y-25: Y >= 25)?  With c = A & 3Fh and h = chr_path_height: |h - c| <= 1, the square flat or one
; slope.  Valid: the cell |= 80h and CF = 1.  X kept.
.proc la_cuadro
        and     #$3F
        sta     zt0                     ; c
        sty     zt0+4
        lda     D64_CHR_PATH_HEIGHT
        jsr     d1
        cmp     #3
        bcs     no
        dey                             ; the cell - 1
        jsr     rel
        cmp     #1
        beq     llano
        cmp     #3
        bcs     no
        sta     zt0+1                   ; b
        jsr     y24                     ; the cell - 24: level with c
        cmp     #1
        bne     no
        beq     ultimo
llano:  jsr     y24
        cmp     #3
        bcs     no
        sta     zt0+1
ultimo: dey                             ; the cell - 25: c + b - 1
        jsr     rel
        cmp     zt0+1
        bne     no
        ldy     zt0+4
        lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        sec
        rts
no:     clc
        rts
y24:    lda     zt0+4
        sec
        sbc     #24
        tay
rel:    lda     (la_c),y                ; the cell's height - c + 1
        and     #$3F
d1:     sec
        sbc     zt0
        clc
        adc     #1
        rts
.endproc

; ---- the searches (3F92, 3F9E, 3FD3-40E6 the room's height buffer; 438F, 4399, 4404 the floor's map) ----

; 3F92 chr_path_room_to_marked: the cell of chr_path_dest gets bit 6 and the search runs (callers may have
; marked more cells).  Out: HL = the queue word expanded at the hit or the separator that ended it, A =
; chr_path_result; EI.
.proc chr_path_room_to_marked
        jsr     la_destino
        jsr     iso_grid_cell_ptr
        ldy     #0
        lda     (zix),y
        ora     #$40
        sta     (zix),y
        jmp     la_sala
.endproc

; HL := chr_path_dest
.proc la_destino
        lda     D64_CHR_PATH_DEST
        sta     zhl
        lda     D64_CHR_PATH_DEST+1
        sta     zhl+1
        rts
.endproc

; 3F9E chr_path_room_search: the search to chr_path_dest: its cell must be lower than 0Eh and a valid square
; (checked only), then it gets bit 6 and the search runs.  The early exits (result 0) leave HL as
; iso_grid_cell_ptr left it.  Out: HL, A = chr_path_result; EI.
.proc chr_path_room_search
        jsr     la_destino
        jsr     iso_grid_cell_ptr
        ldy     #0
        lda     (zix),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
        cmp     #$0E
        bcs     cero
        pha
        lda     #$C9
        sta     D64_CHR_PATH_SMC_RET
        lda     #25
        jsr     la_c_ix
        pla
        ldy     #25
        jsr     la_cuadro
        lda     #0
        sta     D64_CHR_PATH_SMC_RET
        ldy     #25
        lda     (la_c),y
        bpl     cero
        and     #$7F
        ora     #$40
        sta     (la_c),y
        jmp     la_sala
cero:   lda     #0
        jmp     la_fin_busqueda
.endproc

; la_c := IX - A
.proc la_c_ix
        sta     zt0
        lda     zix
        sec
        sbc     zt0
        sta     la_c
        lda     zix+1
        sbc     #0
        sta     la_c+1
        rts
.endproc

; 3FD3: the room search: the border of the height buffer marked (bit 7), chr_path_length := 1, then the queue
.proc la_sala
        lda     D64_CHR_HBUF_PTR        ; rows 0 and 23 ...
        sta     la_c
        clc
        adc     #<$228
        sta     la_s
        lda     D64_CHR_HBUF_PTR+1
        sta     la_c+1
        adc     #>$228
        sta     la_s+1
        ldy     #23
:       lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        lda     (la_s),y
        ora     #$80
        sta     (la_s),y
        dey
        bpl     :-
        ldx     #24                     ; ... columns 0 and 23
:       ldy     #0
        jsr     marca
        ldy     #23
        jsr     marca
        lda     la_c
        clc
        adc     #24
        sta     la_c
        bcc     :+
        inc     la_c+1
:       dex
        bne     :--
        lda     #1
        sta     D64_CHR_PATH_LENGTH
        lda     #0
        beq     la_busca                ; (always)
marca:  lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        rts
.endproc

; 441E chr_path_floor_cell_ptr: the cell of screen (x = L, y = H) in the floor map: [3F73] + ((y << 4 | x) & FFh).
; Out: IX, DE = the index (D = 0), A = its low byte.
.proc chr_path_floor_cell_ptr
        lda     zhl+1
        asl
        asl
        asl
        asl
        ora     zhl
        sta     zde
        ldx     #0
        stx     zde+1
        clc
        adc     D64_CHR_PATH_ROOM_LINKS_PTR
        sta     zix
        lda     D64_CHR_PATH_ROOM_LINKS_PTR+1
        adc     #0
        sta     zix+1
        lda     zde
        rts
.endproc

; 438F chr_path_floor_to_screen: screen chr_path_dest marked with bit 6, then falls into chr_path_floor_search.
.proc chr_path_floor_to_screen
        jsr     la_destino
        jsr     chr_path_floor_cell_ptr
        ldy     #0
        lda     (zix),y
        ora     #$40
        sta     (zix),y
        ; falls into chr_path_floor_search
.endproc

; 4399 chr_path_floor_search: the search between the screens of a floor (map [3F73], 16 columns) from
; chr_path_origin; the target is the bit tested by the self-modified BIT n,(IX+0) (opcode byte at 440Dh).  Out:
; chr_path_result, chr_path_orientation, HL as the room search, DE = the screen reached (y << 8 | x) or the
; separator that ended an empty queue, A = the result; EI.
.proc chr_path_floor_search
        lda     D64_CHR_PATH_FLOOR_TARGET_TEST
        lsr
        lsr
        lsr
        and     #7
        tax
        lda     #1
:       dex
        bmi     :+
        asl
        bne     :-
:       sta     la_s                    ; the target bit
        lda     #4
        ; falls into la_busca
.endproc

; the queue of both searches (A = 0 the room, 4 the floor): the origin queued and marked, then the queue words
; expanded in order: a separator ends a level (queued again; the room's chr_path_length + 1) or the search (empty
; queue: result 0); a cell tries its neighbours x+1, y-1, x-1, y+1 (back orientations 2, 3, 0, 1; the room's
; cell first sets chr_path_height).  The ends: HL = la_p, result FFh (found) or 0; EI.
.proc la_busca
        sta     la_t+3                  ; the mode: 0 room, 4 floor
        lda     #<(D64_PATH_QUEUE - 6)
        sta     la_q
        lda     #>(D64_PATH_QUEUE - 6)
        sta     la_q+1
        lda     D64_CHR_PATH_ORIGIN
        ldx     D64_CHR_PATH_ORIGIN+1
        jsr     la_mete
        lda     la_t+3                  ; CALL 0944 at 400E / CALL 441E at 43A6
        lsr
        tax
        ldy     #4
        lda     ret_ini,x
        sta     (la_q),y
        iny
        lda     ret_ini+1,x
        sta     (la_q),y
        lda     #<D64_PATH_QUEUE
        sta     la_p
        lda     #>D64_PATH_QUEUE
        sta     la_p+1
        lda     D64_CHR_PATH_ORIGIN
        sta     zhl
        lda     D64_CHR_PATH_ORIGIN+1
        sta     zhl+1
        jsr     celda
        ldy     #0
        lda     (zix),y
        ora     #$80
        sta     (zix),y
        lda     #$FF
        tax
        jsr     la_mete
sig:    lda     la_p                    ; the next queue word: la_p -= 2, DE = [la_p]
        sec
        sbc     #2
        sta     la_p
        bcs     :+
        dec     la_p+1
:       ldy     #1
        lda     (la_p),y
        sta     zde+1
        dey
        lda     (la_p),y
        sta     zde
        bpl     celda1
        lda     la_q                    ; a separator: the queue empty when la_p = the top (la_q + 6)?
        clc
        adc     #6
        tax
        lda     la_q+1
        adc     #0
        cmp     la_p+1
        bne     :+
        cpx     la_p
        bne     :+
        lda     #0
        jmp     fin
:       lda     zde
        ldx     zde+1
        jsr     la_mete
        lda     la_t+3
        bne     sig
        inc     D64_CHR_PATH_LENGTH
        jmp     sig
celda1: lda     la_t+3                  ; the words the Z80 pushed: [top-2] = la_p (the CPC's address), [top-4]
        lsr                             ; = the word, [top-6] = the CALL's return address (403F / 43D0)
        tax
        ldy     #0
        lda     ret_exp,x
        sta     (la_q),y
        iny
        lda     ret_exp+1,x
        sta     (la_q),y
        iny
        lda     zde
        sta     (la_q),y
        sta     zhl
        sta     la_t                    ; x
        iny
        lda     zde+1
        sta     (la_q),y
        sta     zhl+1
        sta     la_t+1                  ; y
        iny
        lda     la_p
        sec
        sbc     #<LA_ESCRATCH
        sta     (la_q),y
        iny
        lda     la_p+1
        sbc     #>LA_ESCRATCH
        sta     (la_q),y
        jsr     celda
        lda     la_t+3
        bne     :+
        tay
        lda     (zix),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
:       lda     #49                     ; la_c = the cell - 49 (room) / - 16 (floor): the neighbours at 8-bit
        ldx     la_t+3                  ; offsets
        beq     :+
        lda     #16
:       jsr     la_c_ix
vec:    lda     la_t                    ; the next neighbour: x, y
        clc
        adc     paso_x,x
        sta     la_t
        sta     zde
        lda     la_t+1
        clc
        adc     paso_y,x
        sta     la_t+1
        sta     zde+1
        jsr     vecino
        bcs     hallado
        inx
        txa
        and     #3
        bne     vec
        jmp     sig
hallado:
        lda     #$FF
fin:    ldx     la_p
        stx     zhl
        ldx     la_p+1
        stx     zhl+1
        jmp     la_fin_busqueda
celda:  lda     la_t+3
        bne     :+
        jmp     iso_grid_cell_ptr
:       jmp     chr_path_floor_cell_ptr

; one neighbour X (la_c = the cell, la_t = its position): the Z80's CALL return address below the queue's top
; (4077 room / 4404 floor).  Room: chr_path_orientation := back; a visited cell (bit 7) skipped, else the square
; check; a valid square ends here with 40C2 = RET; in search mode bit 7 is cleared, bit 6 (the target) ends the
; search (CF = 1), else bit 7 set again and the position queued.  Floor: blocked when [cell] & the side mask; the
; target bit ends the search (chr_path_orientation := back, CF = 1); visited: skipped; else bit 7 set and queued.
; X kept.
vecino: ldy     #4
        lda     ret_lo,x
        sta     (la_q),y
        iny
        lda     ret_hi,x
        sta     (la_q),y
        ldy     despl,x
        sty     zt0+5
        cpx     #4
        bcs     planta
        lda     atras,x
        sta     D64_CHR_PATH_ORIENTATION
        lda     (la_c),y
        bmi     nada
        jsr     la_cuadro
        bcc     nada
        lda     D64_CHR_PATH_SMC_RET
        cmp     #$C9
        beq     nada
        ldy     zt0+5
        lda     (la_c),y
        and     #$7F
        sta     (la_c),y
        and     #$40
        bne     meta
        beq     encola                  ; (always)
planta: lda     (la_c),y
        and     mascara-4,x
        bne     nada
        lda     (la_c),y
        and     la_s
        bne     meta_p
        lda     (la_c),y
        bmi     nada
encola: ldy     zt0+5                   ; bit 7 set, the position where the return address was, the return
        lda     (la_c),y                ; address one word lower
        ora     #$80
        sta     (la_c),y
        ldy     #4
        lda     la_t
        sta     (la_q),y
        iny
        lda     la_t+1
        sta     (la_q),y
        ldy     #2
        lda     ret_lo,x
        sta     (la_q),y
        iny
        lda     ret_hi,x
        sta     (la_q),y
        jsr     la_baja
nada:   clc
        rts
meta_p: lda     atras,x
        sta     D64_CHR_PATH_ORIENTATION
meta:   sec
        rts

ret_ini: .word  $4011, $43A9
ret_exp: .word  $403F, $43D0
despl:  .byte   49 + 1, 49 - 24, 49 - 1, 49 + 24, 16 + 1, 16 - 16, 16 - 1, 16 + 16
paso_x: .byte   1, <-1, <-1, 1, 1, <-1, <-1, 1
paso_y: .byte   0, <-1, 1, 1, 0, <-1, 1, 1
atras:  .byte   2, 3, 0, 1, 2, 3, 0, 1
ret_lo: .byte   $51, $5D, $69, $75, $DB, $E8, $F5, $02
ret_hi: .byte   $40, $40, $40, $40, $43, $43, $43, $44
mascara: .byte  $04, $08, $01, $02
.endproc

; ---- Adso's steps (40EB-417F) ----

; 40FA chr_adso_step_prepare: the character's marks taken out of the height buffer (chr_mark_hbuf with mark 0,
; which leaves its cell in IX), 40C2 := RET (the square check only checks), chr_path_height := the cell's height.
; In: IY = chr, IX.  Out: IX = the cell, A = the height, C = 0.
.proc chr_adso_step_prepare
        lda     #0
        sta     zbc
        jsr     chr_mark_hbuf
        lda     #$C9
        sta     D64_CHR_PATH_SMC_RET
        ldy     #0
        sty     zbc
        lda     (zix),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
        rts
.endproc

; 4164 chr_adso_step_restore: 40C2 := NOP again and the character's mark (+0Eh) back into the height buffer.
.proc chr_adso_step_restore
        lda     #0
        sta     D64_CHR_PATH_SMC_RET
        ldy     #$0E
        lda     (ziy),y
        sta     zbc
        jmp     chr_mark_hbuf
.endproc

; 40EB chr_adso_step_guillermo_dir: Adso (IY) tries to step in Guillermo's orientation or the next ones (entry =
; Guillermo's orientation + 1, 3 -> 7); when he steps, Adso's driver runs again (JMP ai_update_adso).
.proc chr_adso_step_guillermo_dir
        jsr     chr_adso_step_prepare
        lda     D64_CHR_GUILLERMO+1
        clc
        adc     #1
        cmp     #3
        bne     la_adso_prueba
        lda     #7
        bne     la_adso_prueba          ; (always)
.endproc

; 410D chr_adso_step_aside: entry = the octant of Adso relative to Guillermo (bit 2 Adso has the smaller x, bit 1
; the smaller y, bit 0 |dy| < |dx|).  As 40EB.
.proc chr_adso_step_aside
        jsr     chr_adso_step_prepare
        ldx     #0
        lda     D64_CHR_ADSO+2
        sec
        sbc     D64_CHR_GUILLERMO+2
        bcs     :+
        eor     #$FF
        adc     #1
        ldx     #4
:       sta     zt0
        lda     D64_CHR_ADSO+3
        sec
        sbc     D64_CHR_GUILLERMO+3
        bcs     :+
        eor     #$FF
        adc     #1
        inx
        inx
:       cmp     zt0
        bcs     :+
        inx
:       txa
        ; falls into la_adso_prueba
.endproc

; 4130-417F: the first 3 orientations of entry A of chr_adso_dir_choices from the cell IX: the square one step away
; gets bit 7 cleared and is checked; the first valid one gets a step command, the marks come back and Adso's
; driver runs again (JMP ai_update_adso); none: the marks come back (4164) and RTS.
.proc la_adso_prueba
        asl
        asl
        clc
        adc     #<D64_CHR_ADSO_DIR_CHOICES
        sta     la_s
        lda     #>D64_CHR_ADSO_DIR_CHOICES
        adc     #0
        sta     la_s+1
        lda     #3
        sta     la_t+3
sig:    ldy     #0
        lda     (la_s),y
        sta     la_t+2                  ; the orientation
        asl
        tay
        lda     D64_CHR_DIR_BUFFER_STEP,y       ; the cell one step away: la_c = IX - 49, Y = 49 + the step
        clc
        adc     #49
        sta     zt0+5
        lda     #49
        jsr     la_c_ix
        ldy     zt0+5
        lda     (la_c),y
        and     #$7F
        sta     (la_c),y
        jsr     la_cuadro
        ldy     zt0+5
        lda     (la_c),y
        bmi     libre
        inc     la_s
        bne     :+
        inc     la_s+1
:       dec     la_t+3
        bne     sig
        jmp     chr_adso_step_restore
libre:  and     #$7F
        sta     (la_c),y
        lda     la_t+2
        sta     zbc
        jsr     chr_cmd_write_one_step
        jsr     chr_adso_step_restore
        jmp     ai_update_adso
.endproc

; ---- the command writers (41A8-438E) ----

; 41A8 chr_cmd_write_one_step: one step of the character IY in orientation C: chr_cmd_generator := 41B8 (the
; one-step generator), chr_cmd_generate with HL = 41B8h (the Z80's value, which the generator may pass on),
; chr_cmd_generator := 41C9 again.  Out: HL = 41C9h.
.proc chr_cmd_write_one_step
        lda     #<chr_cmd_turn_and_step
        sta     D64_CHR_CMD_GENERATOR
        lda     #>chr_cmd_turn_and_step
        sta     D64_CHR_CMD_GENERATOR+1
        lda     #$B8
        sta     zhl
        lda     #$41
        sta     zhl+1
        jsr     chr_cmd_generate
        lda     #<chr_cmd_write_path
        sta     D64_CHR_CMD_GENERATOR
        lda     #>chr_cmd_write_path
        sta     D64_CHR_CMD_GENERATOR+1
        lda     #$C9
        sta     zhl
        lda     #$41
        sta     zhl+1
        rts
.endproc

; 434F chr_cmd_generate: the movement commands of character IY: its x, y, orientation, height and +5 saved, its
; command buffer emptied (+9 = +0Bh = 0), the generator in chr_cmd_generator called (C, HL passed on), +5 back,
; the end command 1000h (12 bits) written, the rest restored, +9 = +0Bh = 0.  Out: HL = the saved y << 8 | x.
.proc chr_cmd_generate
        ldy     #2
        lda     (ziy),y
        pha                             ; x
        iny
        lda     (ziy),y
        pha                             ; y
        ldy     #1
        lda     (ziy),y
        pha                             ; orientation
        ldy     #4
        lda     (ziy),y
        pha                             ; height
        lda     #0
        ldy     #9
        sta     (ziy),y
        ldy     #$0B
        sta     (ziy),y
        ldy     #5
        lda     (ziy),y
        pha
        jsr     llama
        pla
        ldy     #5
        sta     (ziy),y
        lda     #$00
        sta     zhl
        lda     #$10
        sta     zhl+1
        lda     #$0C
        sta     zbc+1
        jsr     chr_cmd_write_bits
        pla
        ldy     #4
        sta     (ziy),y
        pla
        ldy     #1
        sta     (ziy),y
        pla
        sta     zhl+1
        ldy     #3
        sta     (ziy),y
        pla
        sta     zhl
        dey
        sta     (ziy),y
        lda     #0
        ldy     #9
        sta     (ziy),y
        ldy     #$0B
        sta     (ziy),y
        rts
llama:  jmp     (D64_CHR_CMD_GENERATOR)
.endproc

; 41B8 chr_cmd_turn_and_step: the one-step generator: the new orientation C into +1 (a turn command when it
; changed), the heights ahead (chr_probe_ahead) and one step command.  In: C, HL, IY.  Out: A as
; chr_cmd_write_bits leaves it.
.proc chr_cmd_turn_and_step
        ldy     #1
        lda     (ziy),y
        tax
        lda     zbc
        sta     (ziy),y
        txa
        cmp     zbc
        beq     :+
        jsr     chr_cmd_write_turn
:       jsr     chr_probe_ahead
        jmp     chr_cmd_write_step
.endproc

; 432C chr_cmd_write_turn: the turn command from orientation A to C: d = A - C, if negative (-d) XOR 2 (0 ->
; 2); chr_cmd_turn_len[d] bits of the word chr_cmd_turn_bits[d] (high byte first) written by chr_cmd_write_bits.
; In: A, C, IY.  Out: C = d, A, B, HL as chr_cmd_write_bits leaves them, DE = the word's address + 1 (or the
; command byte it stored).
.proc chr_cmd_write_turn
        sec
        sbc     zbc
        bcs     :+
        eor     #$FF
        adc     #1
        eor     #2
        bne     :+
        lda     #2
:       sta     zbc
        tax
        lda     D64_CHR_CMD_TURN_LEN,x
        sta     zbc+1
        txa
        asl
        tax
        lda     D64_CHR_CMD_TURN_BITS,x
        sta     zhl+1
        lda     D64_CHR_CMD_TURN_BITS+1,x
        sta     zhl
        txa
        clc
        adc     #<(D64_CHR_CMD_TURN_BITS + 1)
        sta     zde
        lda     #>(D64_CHR_CMD_TURN_BITS + 1)
        adc     #0
        sta     zde+1
        jmp     chr_cmd_write_bits
.endproc

; 4292 chr_cmd_write_step: the command of one step and the simulated move.  A, C = the heights of the two cells
; ahead (chr_probe_ahead), HL = the step (dx, dy) for chr_apply_step.  +5 bit 4 cleared.  1-cell character
; (+5 bit 7): turned on the slope (bit 5): plain step (3F83); else height + 1, and unless A = 1 table 3F89,
; bit 4 and height - 2; A = C: it becomes a 4-cell character (entry + 3, +5 &= 10h, one or two advances: two
; when chr_orientation_parity gives ZF); else one advance.  4-cell: A = 1 climbs (height + 1, +5 = 80h, 3F86),
; A = FFh descends (height - 1, +5 = 90h, 3F8C), both one or two advances (two when not ZF); else one advance
; (3F8F).  The 3 bytes of the entry (bits high, low, count) go to chr_cmd_write_bits, which the Z80 calls in the
; shadow bank.  Out: HL = the step after the advances, A as chr_cmd_write_bits leaves it; BC, DE kept.
.proc chr_cmd_write_step
        sta     la_t                    ; a
        ldy     #5
        lda     (ziy),y
        and     #$EF
        sta     (ziy),y
        bpl     cuatro
        and     #$20
        beq     :+
        lda     #0
        beq     avanza                  ; (always)
:       ldy     #4
        lda     (ziy),y
        clc
        adc     #1
        sta     (ziy),y
        ldx     #0
        lda     la_t
        cmp     #1
        beq     :+
        ldx     #6
        lda     (ziy),y
        sec
        sbc     #2
        sta     (ziy),y
        ldy     #5
        lda     (ziy),y
        ora     #$10
        sta     (ziy),y
:       stx     la_t+1
        lda     la_t
        cmp     zbc
        bne     avanza1
        txa
        clc
        adc     #3
        sta     la_t+1
        ldy     #5
        lda     (ziy),y
        and     #$10
        sta     (ziy),y
        jsr     paso_fijo
        jsr     chr_orientation_parity
        bne     escribe
        beq     paso                    ; (always)
cuatro: lda     la_t
        cmp     #1
        beq     sube
        cmp     #$FF
        beq     baja
        lda     #12
        bne     avanza                  ; (always)
sube:                                   ; A = 1: height + 1, +5 = 80h, 3F86
baja:   ldy     #4                      ; A = FFh: height - 1, +5 = 90h, 3F8C
        clc
        adc     (ziy),y
        sta     (ziy),y
        ldx     #3
        lda     #$80
        ldy     la_t
        dey
        beq     :+
        ldx     #9
        lda     #$90
:       stx     la_t+1
        ldy     #5
        sta     (ziy),y
        jsr     paso_fijo
        jsr     chr_orientation_parity
        beq     escribe
        bne     paso                    ; (always)
avanza: sta     la_t+1
avanza1:
paso:   jsr     chr_apply_step
escribe:
        ldx     #5                      ; the main bank kept: BC, DE, HL
:       lda     zbc,x
        pha
        dex
        bpl     :-
        ldx     la_t+1
        lda     D64_CHR_CMD_STEP_TABLE,x
        sta     zhl+1
        lda     D64_CHR_CMD_STEP_TABLE+1,x
        sta     zhl
        lda     D64_CHR_CMD_STEP_TABLE+2,x
        sta     zbc+1
        txa
        clc
        adc     #<(D64_CHR_CMD_STEP_TABLE + 2)
        sta     zde
        lda     #>(D64_CHR_CMD_STEP_TABLE + 2)
        adc     #0
        sta     zde+1
        jsr     chr_cmd_write_bits
        sta     la_t
        ldx     #0
:       pla
        sta     zbc,x
        inx
        cpx     #6
        bne     :-
        lda     la_t
        rts
paso_fijo:                              ; chr_apply_step with HL kept
        lda     zhl
        pha
        lda     zhl+1
        pha
        jsr     chr_apply_step
        pla
        sta     zhl+1
        pla
        sta     zhl
        rts
.endproc

; 41C9 chr_cmd_write_path: the default generator: rebuilds the path the room search found and writes its
; commands.  DI, sys_ticks := FFh; from chr_path_solution (the queue word that reached the target) the queue is
; read towards older entries and 3-byte records (x, y, orientation) are written at the sprite buffer after an
; FFh: the target with chr_path_orientation XOR 2, then for each earlier level the first queued cell next to the
; current one along one axis (chr_path_dy_tmp, chr_path_candidate), until chr_path_origin; EI.  Then from the last
; record back to the FFh: a turn (a 1-cell character turning to the other axis toggles +5 bit 5),
; chr_cmd_write_turn, chr_probe_ahead and chr_cmd_write_step; records whose position the simulated character
; already passed are skipped.  In: IY.  Out: IX = the FFh record, A = FFh.
.proc chr_cmd_write_path
        jsr     plat_di
        lda     #$FF
        sta     D64_SYS_TICKS
        lda     D64_CHR_PATH_SOLUTION
        sta     la_s
        lda     D64_CHR_PATH_SOLUTION+1
        sta     la_s+1
        jsr     saca
        lda     zbc
        sta     zde
        lda     zbc+1
        sta     zde+1
        lda     #<D64_SPR_BUFFER
        sta     la_p
        lda     #>D64_SPR_BUFFER
        sta     la_p+1
        ldy     #0
        lda     #$FF
        sta     (la_p),y
        lda     D64_CHR_PATH_DEST
        jsr     pon
        lda     D64_CHR_PATH_DEST+1
        jsr     pon
        lda     D64_CHR_PATH_ORIENTATION
        eor     #2
        jsr     pon
        lda     D64_CHR_PATH_LENGTH
        cmp     #1
        beq     hecho
nivel:  jsr     saca                    ; to the next separator
        lda     zbc+1
        bpl     nivel
        lda     zde
        jsr     pon
        lda     zde+1
        jsr     pon
prueba: jsr     saca
        lda     zbc+1
        sec
        sbc     zde+1
        clc
        adc     #1
        cmp     #3
        bcs     prueba
        sta     D64_CHR_PATH_DY_TMP
        lda     zbc
        sec
        sbc     zde
        clc
        adc     #1
        cmp     #3
        bcs     prueba
        asl
        asl
        clc
        adc     D64_CHR_PATH_DY_TMP
        tax
        lda     zbc
        sta     D64_CHR_PATH_CANDIDATE
        lda     zbc+1
        sta     D64_CHR_PATH_CANDIDATE+1
        ldy     #0
        cpx     #1
        beq     :+
        iny
        cpx     #6
        beq     :+
        iny
        cpx     #9
        beq     :+
        iny
        cpx     #4
        bne     prueba
:       sty     zbc+1                   ; B
        lda     D64_CHR_PATH_CANDIDATE
        sta     zde
        lda     D64_CHR_PATH_CANDIDATE+1
        sta     zde+1
        tya
        jsr     pon
        lda     D64_CHR_PATH_ORIGIN
        cmp     zde
        bne     nivel
        lda     D64_CHR_PATH_ORIGIN+1
        cmp     zde+1
        bne     nivel
hecho:  jsr     plat_ei
        lda     la_p                    ; HL = IX = the last record (its orientation byte)
        sta     zhl
        lda     la_p+1
        sta     zhl+1
orden:  ldy     #1
        lda     (ziy),y
        sta     zbc+1                   ; b = the orientation now
        ldy     #0
        lda     (la_p),y
        sta     zbc                     ; c = the record's
        ldy     #5
        lda     (ziy),y
        bpl     :+
        lda     zbc+1
        eor     zbc
        and     #1
        beq     :+
        lda     (ziy),y
        eor     #$20
        sta     (ziy),y
:       ldy     #1
        lda     zbc
        sta     (ziy),y
        lda     zbc+1
        cmp     zbc
        beq     :+
        jsr     chr_cmd_write_turn
:       jsr     chr_probe_ahead
        jsr     chr_cmd_write_step
salta:  lda     la_p
        sec
        sbc     #3
        sta     la_p
        bcs     :+
        dec     la_p+1
:       ldy     #0
        lda     (la_p),y
        cmp     #$FF
        beq     fin
        ldy     #2
        lda     (ziy),y
        sta     zhl
        iny
        lda     (ziy),y
        sta     zhl+1
        jsr     chr_to_hbuf_coords
        ldy     #1
        lda     (la_p),y
        sta     zde
        iny
        lda     (la_p),y
        sta     zde+1
        lda     zhl
        sec
        sbc     zde
        sta     zhl
        lda     zhl+1
        sbc     zde+1
        sta     zhl+1
        ora     zhl
        bne     salta
        jmp     orden
fin:    lda     la_p
        sta     zix
        lda     la_p+1
        sta     zix+1
        lda     #$FF
        rts
pon:    inc     la_p                    ; the next record byte
        bne     :+
        inc     la_p+1
:       ldy     #0
        sta     (la_p),y
        rts
saca:   ldy     #0                      ; BC = the queue word at la_s (POP BC)
        lda     (la_s),y
        sta     zbc
        iny
        lda     (la_s),y
        sta     zbc+1
        lda     la_s
        clc
        adc     #2
        sta     la_s
        bcc     :+
        inc     la_s+1
:       rts
.endproc
