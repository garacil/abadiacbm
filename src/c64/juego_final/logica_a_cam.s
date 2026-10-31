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
; same memory (la_busca's comment says when).  la_q = the queue's top - 6: [top] = (la_q),6, [top-2] = (la_q),4, ...
        .include "logica_a.inc"

        .export chr_path_room_to_marked, chr_path_room_search, chr_path_floor_to_screen, chr_path_floor_search
        .export chr_path_floor_cell_ptr
        .export chr_adso_step_guillermo_dir, chr_adso_step_prepare, chr_adso_step_aside, chr_adso_step_restore
        .export chr_cmd_write_one_step, chr_cmd_turn_and_step, chr_cmd_write_path, chr_cmd_write_step
        .export chr_cmd_write_turn, chr_cmd_generate

        .import iso_grid_cell_ptr, iso_mul24_lo, iso_mul24_hi, plat_di, plat_ei
        .import chr_mark_hbuf, ai_update_adso, chr_cmd_write_bits, chr_probe_ahead, chr_apply_step
        .import chr_orientation_parity, chr_to_hbuf_coords, chr_cmd_rewind
.ifdef VELOZ
        .import m_prep, m_anota                         ; (PCG) camino_limpia.s
.endif

.segment "CODE"

; ---- shared pieces of the searches ----

la_hb   = zp0 + 2                ; 2: the room's height buffer - 49 / the floor's map - 16, during a search
; the first page of la_q (V - 6) whose words below V can not reach the path grid's cells before the next page
LA_PAGINA = >(D64_CHR_PATH_GRID + 576 + 6 + 255)

; 40DE: the end of a search: chr_path_result := A, EI.  Out: A = the result.
.proc la_fin_busqueda
        sta     D64_CHR_PATH_RESULT
        jsr     plat_ei
        lda     D64_CHR_PATH_RESULT
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

; 3FD3: the room search: the border of the height buffer marked (bit 7), chr_path_length := 1, then the queue.
; The border is an OR of 80h, so its cells may be marked in any order and twice: rows 0 and 23, then the
; columns 23 and 0 as the adjacent cells 24 r - 1, 24 r for r = 1..23.
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
        ldx     #23                     ; ... columns 23 and 0: Y = 24 r - 1 and 24 r (never FFh and 0), la_c a page
        ldy     #23                     ; further when Y passes FFh
col:    lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        iny
        lda     (la_c),y
        ora     #$80
        sta     (la_c),y
        tya
        clc
        adc     #23
        tay
        bcc     :+
        inc     la_c+1
:       dex
        bne     col
        lda     #1
        sta     D64_CHR_PATH_LENGTH
        lda     #0
        beq     la_busca                ; (always)
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
;
; The queue is where the Z80 kept it (its stack): V = its top (the Z80's SP), la_q = V - 6.  The Z80 also wrote
; its CALL return addresses and pushed registers in the words just below V (each write to V-2, V-4 or V-6 of the V
; of the moment; V only goes down): an expansion [V-2] = the queue word's address, [V-4] = the word, [V-6] = the
; return address of its CALL 0944 / 441E (403F / 43D0); each neighbour tried [V-2] = the return address of its
; CALL 4077 / 4404 (ret_lo/hi); a neighbour queued [V-4] = that address (V -= 2 then: it is overwritten by the
; next neighbour or expansion before any read, and left out).  While the positions stay in 1..22 (the border is
; visited) the search reads only the buffer's cells, so while those words lie above the buffer they are left out
; too, and the end (fin) writes what the Z80 leaves there: [V-2] = the last neighbour's address; when the last
; expansion queued nothing, [V-4] = its word and [V-6] = 403F / 43D0; when it queued one, [V-4] = 403F / 43D0;
; else nothing.  An expansion keeps its word in HL and V's low byte at its start in la_t+2.  The exact mode
; (la_exacto), for a room search whose origin is outside 1..22 or whose queue comes within a page of the path
; grid's end (about 360 words; never in the sessions), writes the expansions' and the neighbours' words as the
; Z80 does (exacta, lazo: the cell from 0944 itself, la_c = the cell - 49): one branch patched for good (modo1;
; the later searches stay exact, and slower).  Entered from encola it takes effect at the next expansion: the
; words then lie a page above the grid's last cell, and the rest of the expansion queues 3 words at most.
; Outside the exact mode every position queued is in 1..22 (the origin is, and a neighbour on the border is
; visited), so the room's cell needs no range test: la_c = (the buffer - 49) & FF00h + 24 y + x, and the cells'
; offsets from it (49 + lo for the cell, lo = the buffer - 49 & FFh) are written into the code at the search's
; start (a buffer whose offsets would pass FFh, lo > B6h, is searched in the exact mode: the game's two have lo
; 28h and 90h).  The neighbours are tried by four copies of the test (o_n3 .. o_n0), the square check and the
; queueing in one routine (cuadro), as the Z80's 4077 / 4080.  The floor's cell is la_hb + (y << 4 | x) & FFh,
; la_hb = the map - 16; its map lies far from the queue.  (The return address of the origin's CALL 0944 / 441E at
; [V-2] is left out: the first expansion overwrites it, and only an origin whose cell is that word, some 64 rows
; off the grid, could read it.)
.ifdef VELOZ
.proc la_busca
        sta     la_t+3                  ; the mode: 0 room, 4 floor
        lda     #<(D64_PATH_QUEUE - 6)
        sta     la_q
        lda     #<D64_PATH_QUEUE
        sta     la_p
        lda     #>D64_PATH_QUEUE        ; (one page: asserted below)
        sta     la_q+1
        sta     la_p+1
        sta     sig1+2                  ; the room's queue reads: X = the word's low byte, its page in the operands
        sta     sig2+2
        lda     D64_CHR_PATH_ORIGIN     ; the origin queued, its cell (0944 / 441E) visited, the separator
        sta     zhl
        ldx     D64_CHR_PATH_ORIGIN+1
        stx     zhl+1
        jsr     mete
        lda     la_t+3
        bne     o_planta
        lda     D64_CHR_HBUF_PTR        ; the room: la_hb = the height buffer - 49
        sec
        sbc     #49
        sta     la_hb
        lda     D64_CHR_HBUF_PTR+1
        sbc     #0
        sta     la_hb+1
        lda     la_hb                   ; la_c = la_hb + 24 y + x = the cell - 49 (modo1 adds the low byte of
        cmp     #234                    ; la_hb to x first: x <= 22, so no carry can be lost while that byte is
        bcs     o_ex                    ; below 234; else the exact mode)
        lda     zhl+1                   ; an origin outside 1..22: the exact mode
        sec
        sbc     #1
        cmp     #22
        bcs     o_ex
        lda     zhl
        sbc     #0                      ; (C = 0) x - 1
        cmp     #22
        bcc     :+
o_ex:   jsr     la_exacto
:       jsr     iso_grid_cell_ptr
        bcc     :+                      ; (always: C = 0)
o_planta:
        lda     D64_CHR_PATH_ROOM_LINKS_PTR     ; the floor: la_hb = the map - 16
        sec
        sbc     #16
        sta     la_hb
        lda     D64_CHR_PATH_ROOM_LINKS_PTR+1
        sbc     #0
        sta     la_hb+1
        jsr     chr_path_floor_cell_ptr
:       ldy     #0
        lda     (zix),y
        ora     #$80
        sta     (zix),y
        lda     #$FF
        tax
        jsr     mete
        lda     la_t+3                  ; the room's queue loop (sig, X = la_p's low byte) or the floor's (sig_p)
        beq     :+
        jmp     sig_p
:       ldx     la_p
        jmp     sig
hallado:
        lda     atras,x                 ; found by neighbour X: chr_path_orientation, DE = its position
        sta     D64_CHR_PATH_ORIENTATION
        lda     zhl
        clc
        adc     dx,x
        sta     zde
        lda     zhl+1
        clc
        adc     dy,x
        sta     zde+1
        lda     #$FF
fin:    pha                             ; the result
        txa                             ; [V-2] = the last neighbour's return address
        clc
        adc     la_t+3
        tax
        jsr     la_tw
        lda     la_t+2                  ; 2 x the words the last expansion queued
        sec
        sbc     la_q
        beq     ninguna
        cmp     #2
        bne     hl                      ; two or more: nothing else
        ldy     #2                      ; one: [V-4] = 403F / 43D0
        jsr     la_rexp
        bne     hl                      ; (always)
ninguna:
        jsr     la_j0                   ; none: [V-4] = its word, [V-6] = 403F / 43D0
hl:     lda     la_p
        sta     zhl
        lda     la_p+1
        sta     zhl+1
        pla
        jmp     la_fin_busqueda
vacia:  lda     (la_p),y                ; empty: DE = the separator; the last neighbour tried was the 4th
        sta     zde
        iny
        lda     (la_p),y
        sta     zde+1
        ldx     #0
        lda     la_t+3
        bne     :+
        lda     #1                      ; (the room's tries all set chr_path_orientation: the 4th's back
        sta     D64_CHR_PATH_ORIENTATION ; orientation; the floor's only at a hit)
:       lda     #0
        beq     fin                     ; (always)
planta: lda     zhl+1                   ; the floor: la_c = la_hb + (y << 4 | x) & FFh = the cell (441E) - 16
        asl
        asl
        asl
        asl
        ora     zhl
        clc
        adc     la_hb
        sta     la_c
        lda     la_hb+1
        adc     #0
        sta     la_c+1
        ldx     #3
plan1:  ldy     despl+4,x               ; 4404: blocked by the side mask -> skipped; the target bit ends the
        lda     (la_c),y                ; search; visited -> skipped; else bit 7 set and queued
        and     mascara,x
        bne     plan2
        lda     (la_c),y
        and     la_s
        bne     hallado
        lda     (la_c),y
        bmi     plan2
        ora     #$80
        sta     (la_c),y
        clc
        jsr     encola
plan2:  dex
        bpl     plan1                   ; (falls into sig_p)
sig_p:  lda     la_p                    ; the floor's queue loop: the next queue word, la_p -= 2, HL = [la_p]
        sec
        sbc     #2
        sta     la_p
        bcs     :+
        dec     la_p+1
:       ldy     #0
        lda     (la_p),y
        bpl     :+
        jmp     separa_c
:       sta     zhl                     ; x
        iny
        lda     (la_p),y
        sta     zhl+1                   ; y
        ldx     la_q                    ; (for fin's words)
        stx     la_t+2
        jmp     planta

; ---- the room's expansion in the normal mode: the four neighbours inline ----
; One neighbour: T = (la_c),ofs (ofs = 49 + its offset from the cell); visited (bit 7) -> next; else cuadro's
; square check with the cells L = T-1, U = T-24, UL = T-25 (the slopes through pend_x / pend_y, which return C = 1
; to go on at ul); valid: T |= 80h, the target (bit 6) ends the search (meta_i, X = k for hallado), else the
; neighbour's position x+dx, y+dy is queued (C = 1 from the UL compare: ADC #0 adds 1, SBC #1 subtracts 1) and V -= 2.
; X (la_p's low byte) is kept.  `next` is the next neighbour's block (sig after the fourth).
.macro  VECINO  k, ofs, next
        .local  px, py, ul, meta_k, salto
        ldy     #ofs
        lda     (la_c),y
        bmi     next
        and     #$3F
        sta     zt0                     ; c
        cmp     D64_CHR_PATH_HEIGHT     ; c = h (flat, the common case) -> L
        beq     :+
        sec                             ; else |h - c| <= 1: c - h is 1 or FFh (the Z80's h - c + 1 < 3)
        sbc     D64_CHR_PATH_HEIGHT
        cmp     #2
        bcc     :+
        cmp     #$FF
        bne     next
:       dey                             ; L
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     px
        ldy     #ofs - 24               ; U
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     py
ul:     dey                             ; UL: must be c, or what the slope left in zt0
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     next
        ldy     #ofs                    ; T (C = 1)
        lda     (la_c),y                ; valid: marked
        ora     #$80
        sta     (la_c),y
        and     #$40                    ; the target
        bne     meta_k
        lda     zhl                     ; queued: [V-2] = the neighbour's position, V -= 2
        .if k = 3
        adc     #0                      ; x + 1 (C = 1)
        .elseif k = 1
        sbc     #1                      ; x - 1 (C = 1)
        .endif
        ldy     #4
        sta     (la_q),y
        lda     zhl+1
        .if k = 2
        sbc     #1                      ; y - 1 (C = 1)
        .elseif k = 0
        adc     #0                      ; y + 1 (C = 1)
        .endif
        iny
        sta     (la_q),y
        lda     la_q
        sec
        sbc     #2
        sta     la_q
        bcs     next
        dec     la_q+1
        lda     la_q+1                  ; a new page: the exact mode when the queue's words below V may reach
        cmp     #LA_PAGINA              ; the grid's cells within this expansion (never: see mete1)
        bcs     salto
        jsr     la_exacto
salto:
        jmp     next
meta_k: stx     la_p                    ; the target: la_p back from X, X = the neighbour
        ldx     #k
        jmp     meta_i
px:     jsr     pend_x                  ; l != c: |l - c| = 1, u = c, ul must be l
        bcs     ul
        bcc     next                    ; (always)
py:     jsr     pend_y                  ; l = c, u != c: |u - c| = 1, ul must be u
        bcs     ul
        bcc     next                    ; (always)
.endmacro

o_n3:   VECINO  3, 49 + 1, o_n2         ; 4077, the neighbours in order: x+1 (back orientation 2), y-1 (3),
o_n2:   VECINO  2, 49 - 24, o_n1        ; x-1 (0), y+1 (1)
o_n1:   VECINO  1, 49 - 1, o_n0
o_n0:   VECINO  0, 49 + 24, sig
sig:    dex                             ; the room's queue loop: the next queue word, la_p -= 2: X = its low byte
        beq     pagina                  ; (odd; it passes 1: the page below), HL = [la_p]
        dex
sig1:   lda     D64_PATH_QUEUE & $FF00,x        ; (the page: written at the search's start and at pagina)
        bmi     separa
        sta     zhl                     ; x
sig2:   lda     1 + (D64_PATH_QUEUE & $FF00),x
        ldy     la_q                    ; (for fin's words)
        sty     la_t+2
modo1:  sta     zhl+1                   ; y (the exact mode: these 3 bytes become JMP exacta, la_exacto)
        tay                             ; la_c = la_hb + 24 y + x = the cell - 49 (x, y in 1..22)
        lda     zhl
        clc
        adc     la_hb
        adc     iso_mul24_lo,y
        sta     la_c
        lda     iso_mul24_hi,y
        adc     la_hb+1
        sta     la_c+1
        ldy     #49                     ; the cell: chr_path_height
        lda     (la_c),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
        jmp     o_n3
pagina: dex                             ; X = FFh: the word is in the page below
        dec     sig1+2
        dec     sig2+2
        dec     la_p+1
        jmp     sig1
separa: stx     la_p                    ; a separator (the room: la_p's low byte back from X)
separa_c:
        ldy     #0
        lda     la_q                    ; the queue is empty when la_p = V
        clc
        adc     #6
        tax
        lda     la_q+1
        adc     #0
        cmp     la_p+1
        bne     :+
        cpx     la_p
        bne     :+
        jmp     vacia
:       iny
        lda     (la_p),y
        tax
        dey
        lda     (la_p),y
        jsr     mete
        lda     la_t+3
        beq     :+
        jmp     sig_p
:       inc     D64_CHR_PATH_LENGTH
        ldx     la_p
        jmp     sig
meta_i: lda     (la_c),y                ; the target (40D8), from the inline neighbours: bit 7 cleared again
        and     #$7F
        sta     (la_c),y
        jmp     hallado
exacta: sta     zhl+1                   ; y (A, from the patched modo1)
        stx     la_p
        jsr     la_xj                   ; the room in the exact mode: the expansion's words, the cell from 0944
        jsr     iso_grid_cell_ptr       ; itself (any position), la_c = the cell - 49, and [V-2] = the CALL 4077's
        lda     #49                     ; return address before each neighbour
        jsr     la_c_ix
        ldy     #0                      ; HL back
        lda     (la_p),y
        sta     zhl
        iny
        lda     (la_p),y
        sta     zhl+1
        ldy     #49
        lda     (la_c),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
        ldx     #3
lazo:   jsr     la_tw
        ldy     despl,x
        lda     (la_c),y
        bmi     :+
        jsr     cuadro
:       dex
        bpl     lazo
        ldx     la_p
        jmp     sig
mete:   ldy     #4                      ; the word XA queued
        sta     (la_q),y
        txa
        iny
        bne     mete1                   ; (always)

; 4080 chr_path_check_square (la_cuadro): can a character stand on the 2x2 square whose top-right cell T is
; (la_c),Y (cells T, L = T-1, U = T-24, UL = T-25: Y >= 25)?  With the values & 3Fh (c = T's, l, u, ul) and h =
; chr_path_height: |h - c| <= 1, and the square flat or one slope: l = c, |u - c| <= 1 and ul = u, or |l - c| = 1,
; u = c and ul = l (the Z80's tests d(v) = v - c + 1 < 3, d(l) = 1 or not, d(ul) = d(u) or d(l), reordered: they
; only read).  Valid: T |= 80h (40BE); then with 40C2 = RET (C9h: the check only, for chr_path_room_search and
; Adso's steps) RTS, else (the exact mode's neighbour X: 40C3-40DD) the target (bit 6) ends the search with its
; bit 7 cleared again, and any other cell is queued (encola).  In: A = T (bit 7 clear), Y.  X kept.  (40C2 holds
; only 00h, NOP, or C9h: bit 7 tells them apart.)  The normal room search has the same tests inline (VECINO).
cuadro: and     #$3F
        sta     zt0                     ; c
        sec                             ; |h - c| <= 1: c - h is 0, 1 or FFh (the Z80's h - c + 1 < 3)
        sbc     D64_CHR_PATH_HEIGHT
        cmp     #2
        bcc     :+
        cmp     #$FF
        bne     no
:       dey                             ; L
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     px
        tya                             ; U = L - 23 (C = 1)
        sbc     #23
        tay
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     py
ul:     dey                             ; UL: must be c, or what the slope left in zt0
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     no
        tya                             ; T = UL + 25 (C = 1)
        adc     #24
        tay
        lda     (la_c),y                ; valid: marked
        ora     #$80
        sta     (la_c),y
        bit     D64_CHR_PATH_SMC_RET    ; 40C2 = RET (C9h, bit 7): the check only
        bmi     solo
        and     #$40                    ; the target
        bne     meta
        ; falls into encola
encola: lda     zhl                     ; neighbour X's position queued: [V-2] = it, V -= 2 (C = 0 at the entry)
        adc     dx,x
        ldy     #4
        sta     (la_q),y
        lda     zhl+1
        clc
        adc     dy,x
        iny
mete1:  sta     (la_q),y
        lda     la_q
        sec
        sbc     #2
        sta     la_q
        bcs     :+
        dec     la_q+1
        lda     la_q+1                  ; a new page: the exact mode when the queue's words below V may reach
        cmp     #LA_PAGINA              ; the grid's cells within this expansion (a floor's queue, 256 cells at most,
        bcc     la_exacto               ; never gets there; if it did, the later room searches would be exact too)
:       rts
px:     jsr     pend_x
        bcs     ul
no:     rts
solo:   jmp     m_anota                 ; (the check only: the mark noted for the proportional clear, camino_limpia.s)
py:     jsr     pend_y
        bcs     ul
        rts
; the slopes (C = 1: go on at ul with zt0 = the value ul must have; C = 0: not a valid square).  Y kept (pend_y)
; or moved from L to U (pend_x).
pend_y: sta     zt0+1                   ; l = c, u != c: |u - c| = 1 (the SBC after the CMP: u - c when u > c, else
        sbc     zt0                     ; u - c - 1: 1, or FEh = NOT 1), and ul must be u
        bcs     :+
        eor     #$FF
:       cmp     #1
        beq     pend_si                 ; (C = 1)
        clc
        rts
pend_x: sta     zt0+1                   ; l != c: |l - c| = 1 (as pend_y), u = c, and ul must be l
        sbc     zt0
        bcs     :+
        eor     #$FF
:       cmp     #1
        bne     pend_no
        tya                             ; U = L - 23 (C = 1)
        sbc     #23
        tay
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     pend_no
pend_si:
        lda     zt0+1                   ; (C = 1)
        sta     zt0
        rts
pend_no:
        clc
        rts
meta:   lda     (la_c),y                ; the target (40D8): bit 7 cleared again, the search ends (the neighbour
        and     #$7F                    ; loop's return address dropped)
        sta     (la_c),y
        pla
        pla
        jmp     hallado
la_exacto:                              ; the exact mode, from now on (also for the later searches: it is exact
        lda     #$4C                    ; either way): the `sta zhl+1 ; tay` at modo1 becomes JMP exacta
        sta     modo1
        lda     #<exacta
        sta     modo1+1
        lda     #>exacta
        sta     modo1+2
        rts
la_tw:  ldy     #4                      ; [V-2] = the return address of neighbour X (ret_lo/hi)
        lda     ret_lo,x
        sta     (la_q),y
        iny
        lda     ret_hi,x
        sta     (la_q),y
        rts
la_xj:  ldy     #4                      ; an expansion's words: [V-2] = its queue word's address (the CPC's),
        lda     la_p                    ; then la_j0
        sec
        sbc     #<LA_ESCRATCH
        sta     (la_q),y
        iny
        lda     la_p+1
        sbc     #>LA_ESCRATCH
        sta     (la_q),y
la_j0:  ldy     #2                      ; [V-4] = the word, [V-6] = 403F / 43D0
        lda     zhl
        sta     (la_q),y
        iny
        lda     zhl+1
        sta     (la_q),y
        ldy     #0
la_rexp: lda    la_t+3                  ; [V-6 + Y] = the return address of CALL 0944 / 441E: 403F / 43D0
        lsr
        tax
        lda     ret_exp,x
        sta     (la_q),y
        iny
        lda     ret_exp+1,x
        sta     (la_q),y
        rts

; the neighbours, X = 3..0: x+1, y-1, x-1, y+1 (the room, then the floor)
ret_exp: .word  $403F, $43D0
despl:  .byte   49 + 24, 49 - 1, 49 - 24, 49 + 1, 16 + 16, 16 - 1, 16 - 16, 16 + 1
dx:     .byte   0, <-1, 0, 1
dy:     .byte   1, 0, <-1, 0
atras:  .byte   1, 0, 3, 2
ret_lo: .byte   $75, $69, $5D, $51, $02, $F5, $E8, $DB
ret_hi: .byte   $40, $40, $40, $40, $44, $43, $43, $43
mascara: .byte  $02, $01, $08, $04
        .assert >(D64_PATH_QUEUE - 6) >= LA_PAGINA, error, "the queue starts in the exact mode"
        .assert >(D64_PATH_QUEUE - 6) = >D64_PATH_QUEUE, error, "the queue's start: one page"
        .assert (D64_PATH_QUEUE & 1) = 1, error, "the queue read by X (the word's low byte): D64_PATH_QUEUE odd (mapa64.py cola_impar)"
.endproc
.else
.proc la_busca
        sta     la_t+3                  ; the mode: 0 room, 4 floor
        lda     #<(D64_PATH_QUEUE - 6)
        sta     la_q
        lda     #<D64_PATH_QUEUE
        sta     la_p
        lda     #>D64_PATH_QUEUE        ; (one page: asserted below)
        sta     la_q+1
        sta     la_p+1
        lda     D64_CHR_PATH_ORIGIN     ; the origin queued, its cell (0944 / 441E) visited, the separator
        sta     zhl
        ldx     D64_CHR_PATH_ORIGIN+1
        stx     zhl+1
        jsr     mete
        lda     la_t+3
        bne     o_planta
        lda     D64_CHR_HBUF_PTR        ; the room: la_hb = the height buffer - 49
        sec
        sbc     #49
        sta     la_hb
        lda     D64_CHR_HBUF_PTR+1
        sbc     #0
        sta     la_hb+1
        lda     la_hb                   ; la_c = (the buffer - 49) & FF00h + 24 y + x, the offsets from
        cmp     #$B7                    ; it + lo = (the buffer - 49) & FFh, written into the code (none passes FFh:
        bcs     o_ex                    ; else the exact mode)
        adc     #25                     ; (C = 0)
        sta     o_n2+1                  ; y-1
        adc     #48 - 25
        sta     o_n1+1                  ; x-1
        adc     #1
        sta     o_sala+1                ; the cell
        adc     #1
        sta     o_n3+1                  ; x+1
        adc     #73 - 50
        sta     o_n0+1                  ; y+1
        lda     zhl+1                   ; an origin outside 1..22: the exact mode
        sec
        sbc     #1
        cmp     #22
        bcs     o_ex
        lda     zhl
        sbc     #0                      ; (C = 0) x - 1
        cmp     #22
        bcc     :+
o_ex:   jsr     la_exacto
:       jsr     iso_grid_cell_ptr
        bcc     :+                      ; (always: C = 0)
o_planta:
        lda     D64_CHR_PATH_ROOM_LINKS_PTR     ; the floor: la_hb = the map - 16
        sec
        sbc     #16
        sta     la_hb
        lda     D64_CHR_PATH_ROOM_LINKS_PTR+1
        sbc     #0
        sta     la_hb+1
        jsr     chr_path_floor_cell_ptr
:       ldy     #0
        lda     (zix),y
        ora     #$80
        sta     (zix),y
        lda     #$FF
        tax
        jsr     mete
        jmp     sig
hallado:
        lda     atras,x                 ; found by neighbour X: chr_path_orientation, DE = its position
        sta     D64_CHR_PATH_ORIENTATION
        lda     zhl
        clc
        adc     dx,x
        sta     zde
        lda     zhl+1
        clc
        adc     dy,x
        sta     zde+1
        lda     #$FF
fin:    pha                             ; the result
        txa                             ; [V-2] = the last neighbour's return address
        clc
        adc     la_t+3
        tax
        jsr     la_tw
        lda     la_t+2                  ; 2 x the words the last expansion queued
        sec
        sbc     la_q
        beq     ninguna
        cmp     #2
        bne     hl                      ; two or more: nothing else
        ldy     #2                      ; one: [V-4] = 403F / 43D0
        jsr     la_rexp
        bne     hl                      ; (always)
ninguna:
        jsr     la_j0                   ; none: [V-4] = its word, [V-6] = 403F / 43D0
hl:     lda     la_p
        sta     zhl
        lda     la_p+1
        sta     zhl+1
        pla
        jmp     la_fin_busqueda
vacia:  lda     (la_p),y                ; empty: DE = the separator; the last neighbour tried was the 4th
        sta     zde
        iny
        lda     (la_p),y
        sta     zde+1
        ldx     #0
        lda     la_t+3
        bne     :+
        lda     #1                      ; (the room's tries all set chr_path_orientation: the 4th's back
        sta     D64_CHR_PATH_ORIENTATION ; orientation; the floor's only at a hit)
:       lda     #0
        beq     fin                     ; (always)
planta: lda     zhl+1                   ; the floor: la_c = la_hb + (y << 4 | x) & FFh = the cell (441E) - 16
        asl
        asl
        asl
        asl
        ora     zhl
        clc
        adc     la_hb
        sta     la_c
        lda     la_hb+1
        adc     #0
        sta     la_c+1
        ldx     #3
plan1:  ldy     despl+4,x               ; 4404: blocked by the side mask -> skipped; the target bit ends the
        lda     (la_c),y                ; search; visited -> skipped; else bit 7 set and queued
        and     mascara,x
        bne     plan2
        lda     (la_c),y
        and     la_s
        bne     hallado
        lda     (la_c),y
        bmi     plan2
        ora     #$80
        sta     (la_c),y
        clc
        jsr     encola
plan2:  dex
        bpl     plan1
        jmp     sig
separa: lda     la_q                    ; a separator: the queue is empty when la_p = V
        clc
        adc     #6
        tax
        lda     la_q+1
        adc     #0
        cmp     la_p+1
        bne     :+
        cpx     la_p
        beq     vacia
:       iny
        lda     (la_p),y
        tax
        dey
        lda     (la_p),y
        jsr     mete
        lda     la_t+3
        bne     sig
        inc     D64_CHR_PATH_LENGTH     ; (falls into sig)
sig:    lda     la_p                    ; the next queue word: la_p -= 2, HL = [la_p]
        sec
        sbc     #2
        sta     la_p
        bcs     :+
        dec     la_p+1
:       ldy     #0
        lda     (la_p),y
        bmi     separa
        sta     zhl                     ; x
        iny
        lda     (la_p),y
        sta     zhl+1                   ; y
        ldx     la_q
        stx     la_t+2
        ldx     la_t+3
        bne     planta
modo1:  bmi     exacta                  ; the room (N = 0; BPL in the exact mode)
        tay                             ; la_c = (the buffer - 49) & FF00h + 24 y + x (as 0944 for x, y in 1..22)
        lda     zhl
        clc
        adc     iso_mul24_lo,y
        sta     la_c
        lda     iso_mul24_hi,y
        adc     la_hb+1
        sta     la_c+1
o_sala: ldy     #49                     ; (+ lo: the offsets are written at the search's start)
        lda     (la_c),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
o_n3:   ldy     #49 + 1                 ; 4077, the neighbours in order: visited (bit 7) -> skipped; else the
        lda     (la_c),y                ; square check, and for a valid one the target or the queue (cuadro)
        bmi     :+
        ldx     #3                      ; x+1
        jsr     cuadro
:
o_n2:   ldy     #49 - 24
        lda     (la_c),y
        bmi     :+
        ldx     #2                      ; y-1
        jsr     cuadro
:
o_n1:   ldy     #49 - 1
        lda     (la_c),y
        bmi     :+
        ldx     #1                      ; x-1
        jsr     cuadro
:
o_n0:   ldy     #49 + 24
        lda     (la_c),y
        bmi     sig
        ldx     #0                      ; y+1
        jsr     cuadro
        jmp     sig
exacta: jsr     la_xj                   ; the room in the exact mode: the expansion's words, the cell from 0944
        jsr     iso_grid_cell_ptr       ; itself (any position), la_c = the cell - 49, and [V-2] = the CALL 4077's
        lda     #49                     ; return address before each neighbour
        jsr     la_c_ix
        ldy     #0                      ; HL back
        lda     (la_p),y
        sta     zhl
        iny
        lda     (la_p),y
        sta     zhl+1
        ldy     #49
        lda     (la_c),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
        ldx     #3
lazo:   jsr     la_tw
        ldy     despl,x
        lda     (la_c),y
        bmi     :+
        jsr     cuadro
:       dex
        bpl     lazo
        jmp     sig
mete:   ldy     #4                      ; the word XA queued
        sta     (la_q),y
        txa
        iny
        bne     mete1                   ; (always)

; 4080 chr_path_check_square (la_cuadro): can a character stand on the 2x2 square whose top-right cell T is
; (la_c),Y (cells T, L = T-1, U = T-24, UL = T-25: Y >= 25)?  With the values & 3Fh (c = T's, l, u, ul) and h =
; chr_path_height: |h - c| <= 1, and the square flat or one slope: l = c, |u - c| <= 1 and ul = u, or |l - c| = 1,
; u = c and ul = l (the Z80's tests d(v) = v - c + 1 < 3, d(l) = 1 or not, d(ul) = d(u) or d(l), reordered: they
; only read).  Valid: T |= 80h (40BE); then with 40C2 = RET (C9h: the check only, for chr_path_room_search and
; Adso's steps) RTS, else (the room search's neighbour X: 40C3-40DD) the target (bit 6) ends the search with its
; bit 7 cleared again, and any other cell is queued (encola).  In: A = T (bit 7 clear), Y.  X kept.  (40C2 holds
; only 00h, NOP, or C9h: bit 7 tells them apart.)
cuadro: and     #$3F
        sta     zt0                     ; c
        sec                             ; |h - c| <= 1: c - h is 0, 1 or FFh (the Z80's h - c + 1 < 3)
        sbc     D64_CHR_PATH_HEIGHT
        cmp     #2
        bcc     :+
        cmp     #$FF
        bne     no
:       dey                             ; L
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     pend_x
        tya                             ; U = L - 23 (C = 1)
        sbc     #23
        tay
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        bne     pend_y
        sta     zt0+1                   ; flat so far: ul must be c
ul:     dey                             ; UL
        lda     (la_c),y
        and     #$3F
        cmp     zt0+1
        bne     no
        tya                             ; T = UL + 25 (C = 1)
        adc     #24
        tay
        lda     (la_c),y                ; valid: marked
        ora     #$80
        sta     (la_c),y
        bit     D64_CHR_PATH_SMC_RET    ; 40C2 = RET (C9h, bit 7): the check only
        bmi     no
        and     #$40                    ; the target
        bne     meta
        ; falls into encola
encola: lda     zhl                     ; neighbour X's position queued: [V-2] = it, V -= 2 (C = 0 at the entry)
        adc     dx,x
        ldy     #4
        sta     (la_q),y
        lda     zhl+1
        clc
        adc     dy,x
        iny
mete1:  sta     (la_q),y
        lda     la_q
        sec
        sbc     #2
        sta     la_q
        bcs     :+
        dec     la_q+1
        lda     la_q+1                  ; a new page: the exact mode when the queue's words below V may reach
        cmp     #LA_PAGINA              ; the grid's cells within this expansion (a floor's queue, 256 cells at most,
        bcc     la_exacto               ; never gets there; if it did, the later room searches would be exact too)
:       rts
pend_y: sta     zt0+1                   ; l = c, u != c: |u - c| = 1 (the SBC after the CMP: u - c when u > c, else
        sbc     zt0                     ; u - c - 1: 1, or FEh = NOT 1), and ul must be u
        bcs     :+
        eor     #$FF
:       cmp     #1
        beq     ul
no:     rts
pend_x: sta     zt0+1                   ; l != c: |l - c| = 1 (as pend_y), u = c, and ul must be l
        sbc     zt0
        bcs     :+
        eor     #$FF
:       cmp     #1
        bne     no
        tya                             ; U = L - 23 (C = 1)
        sbc     #23
        tay
        lda     (la_c),y
        and     #$3F
        cmp     zt0
        beq     ul
        rts
meta:   lda     (la_c),y                ; the target (40D8): bit 7 cleared again, the search ends (the neighbour
        and     #$7F                    ; loop's return address dropped)
        sta     (la_c),y
        pla
        pla
        jmp     hallado
la_exacto:                              ; the exact mode, from now on (also for the later searches: it is exact
        lda     #$10                    ; either way): BPL at modo1, always taken there (N = 0)
        sta     modo1
        rts
la_tw:  ldy     #4                      ; [V-2] = the return address of neighbour X (ret_lo/hi)
        lda     ret_lo,x
        sta     (la_q),y
        iny
        lda     ret_hi,x
        sta     (la_q),y
        rts
la_xj:  ldy     #4                      ; an expansion's words: [V-2] = its queue word's address (the CPC's),
        lda     la_p                    ; then la_j0
        sec
        sbc     #<LA_ESCRATCH
        sta     (la_q),y
        iny
        lda     la_p+1
        sbc     #>LA_ESCRATCH
        sta     (la_q),y
la_j0:  ldy     #2                      ; [V-4] = the word, [V-6] = 403F / 43D0
        lda     zhl
        sta     (la_q),y
        iny
        lda     zhl+1
        sta     (la_q),y
        ldy     #0
la_rexp: lda    la_t+3                  ; [V-6 + Y] = the return address of CALL 0944 / 441E: 403F / 43D0
        lsr
        tax
        lda     ret_exp,x
        sta     (la_q),y
        iny
        lda     ret_exp+1,x
        sta     (la_q),y
        rts

; the neighbours, X = 3..0: x+1, y-1, x-1, y+1 (the room, then the floor)
ret_exp: .word  $403F, $43D0
despl:  .byte   49 + 24, 49 - 1, 49 - 24, 49 + 1, 16 + 16, 16 - 1, 16 - 16, 16 + 1
dx:     .byte   0, <-1, 0, 1
dy:     .byte   1, 0, <-1, 0
atras:  .byte   1, 0, 3, 2
ret_lo: .byte   $75, $69, $5D, $51, $02, $F5, $E8, $DB
ret_hi: .byte   $40, $40, $40, $40, $44, $43, $43, $43
mascara: .byte  $02, $01, $08, $04
        .assert >(D64_PATH_QUEUE - 6) >= LA_PAGINA, error, "the queue starts in the exact mode"
        .assert >(D64_PATH_QUEUE - 6) = >D64_PATH_QUEUE, error, "the queue's start: one page"
.endproc
.endif
la_cuadro = la_busca::cuadro

; ---- Adso's steps (40EB-417F) ----

; 40FA chr_adso_step_prepare: the character's marks taken out of the height buffer (chr_mark_hbuf with mark 0,
; which leaves its cell in IX), 40C2 := RET (the square check only checks), chr_path_height := the cell's height.
; In: IY = chr, IX.  Out: IX = the cell, A = the height, C = 0.
.ifdef VELOZ
.proc chr_adso_step_prepare
        lda     #0
        sta     zbc
        jsr     chr_mark_hbuf
        jsr     m_prep                  ; (PCG, camino_limpia.s: 40C2 := RET, and the next clear of Adso's a full one)
        ldy     #0
        sty     zbc
        lda     (zix),y
        and     #$0F
        sta     D64_CHR_PATH_HEIGHT
        rts
.endproc
.else
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
.endif

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
        tax                             ; X = the entry's choices (the table in one page; la_cuadro keeps X)
        lda     #49                     ; la_c = IX - 49
        jsr     la_c_ix
        lda     #3
        sta     la_t+3
sig:    lda     D64_CHR_ADSO_DIR_CHOICES,x
        sta     la_t+2                  ; the orientation
        asl
        tay
        lda     D64_CHR_DIR_BUFFER_STEP,y       ; the cell one step away: Y = 49 + the step
        clc
        adc     #49
        sta     zt0+5
        tay
        lda     (la_c),y
        and     #$7F
        sta     (la_c),y
        jsr     la_cuadro
        ldy     zt0+5
        lda     (la_c),y
        bmi     libre
        inx
        dec     la_t+3
        bne     sig
        jmp     chr_adso_step_restore
libre:  and     #$7F
        sta     (la_c),y
        lda     la_t+2
        sta     zbc
        jsr     chr_cmd_write_one_step
        jsr     chr_adso_step_restore
        jmp     ai_update_adso
        .assert >D64_CHR_ADSO_DIR_CHOICES = >(D64_CHR_ADSO_DIR_CHOICES + 31), error, "Adso's choices: one page"
.endproc

; ---- the command writers (41A8-438E) ----

; 41A8 chr_cmd_write_one_step: one step of the character IY in orientation C: chr_cmd_generator := 41B8 (the
; one-step generator), chr_cmd_generate with HL = 41B8h (the Z80's value, which the generator may pass on),
; chr_cmd_generator := 41C9 again.  Out: HL = 41C9h.
.proc chr_cmd_write_one_step
        lda     #<chr_cmd_turn_and_step
        ldx     #>chr_cmd_turn_and_step
        ldy     #$B8
        jsr     gen
        jsr     chr_cmd_generate
        lda     #<chr_cmd_write_path
        ldx     #>chr_cmd_write_path
        ldy     #$C9
gen:    sta     D64_CHR_CMD_GENERATOR   ; chr_cmd_generator := XA, HL := 41xxh (Y)
        stx     D64_CHR_CMD_GENERATOR+1
        sty     zhl
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
        jsr     chr_cmd_rewind          ; +9 = +0Bh = 0
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
        jmp     chr_cmd_rewind          ; +9 = +0Bh = 0, A = 0
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
; already passed are skipped.  In: IY.  Out: IX = the FFh record, A = FFh.  The DI ... EI are the checked build's
; only (the IFF the host compares): the Z80 needs them because its SP walks the queue; the 6502 reads it through
; la_s, and on the C64 the span took up to ~17000 cycles, five ticks of the music lost.
.proc chr_cmd_write_path
.ifdef PRUEBA
        jsr     plat_di
.endif
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
        ldy     eje,x                   ; 4 (dx + 1) + dy + 1 = 1, 6, 9, 4: orientation 0, 1, 2, 3; else the next
        bmi     prueba
        sty     zbc+1                   ; B
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
hecho:
.ifdef PRUEBA
        jsr     plat_ei
.endif
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
eje:    .byte   $FF, 0, $FF, $FF, 3, $FF, 1, $FF, $FF, 2, $FF
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
