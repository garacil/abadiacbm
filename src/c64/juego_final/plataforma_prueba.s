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

; abadia64ks, 6502 code of the game: the platform calls in the build checked by the hybrid host (the C64's own
; are in c64/plataforma/).  Each keeps a mirror of the CPC hardware state (plataforma.inc) that the host compares
; with the Z80's port effects.  Interface (the same on the C64):
;   plat_tinta         A = pen 0-16 (16 = border), X = hardware colour        (Y clobbered)
;   plat_psg           A = AY register 0-15, X = value                         (Y clobbered)
;   plat_psg_tono      Y = a fine tone register, A = its value, X = the coarse register's value
;   plat_teclado_fila  A = matrix row 0-9 -> A = the row, active low            (Y clobbered)
;   plat_crtc          A = CRTC register 0-15, X = value                       (Y clobbered)
;   plat_modo          A = screen mode                                         (A clobbered)
;   plat_di, plat_ei   the Z80's DI / EI                                       (A, X, Y kept)
;   psg_paso           the C64's footstep voicing (objetos_sonido.s calls it only on the C64): nothing here
; and for the whole game (principal.s, -D PRUEBA; the host's --juego6502 runs it from principal_inicio):
;   plat_inicio        the C64's set-up: nothing here
;   plat_frame         the main loop's head (2179h): the host stops the 6502 there, a frame point
;   plat_espera        a pass of the frame wait (21D6h): the host delivers the ticks due (sys_tick)
;   plat_pausa         a pass of the waits 20C7h / 3EB8h: ticks as plat_espera, and a frame point
;   plat_disco_guarda, plat_disco_carga   C = 1 (no disk: the sessions never save)
;   plat_final         the ending: the host stops there
; The host recognises plat_frame, plat_espera, plat_pausa and plat_final by their addresses (juego.lbl).
        .include "plataforma.inc"
        .export plat_tinta, plat_psg, plat_psg_tono, plat_teclado_fila, plat_crtc, plat_modo, plat_di, plat_ei
        .export psg_paso
        .export plat_inicio, plat_frame, plat_espera, plat_pausa, plat_disco_guarda, plat_disco_carga, plat_final

.segment "CODE"

.proc plat_tinta
        tay
        txa
        and     #$1F
        sta     PLAT_TINTAS,y
        rts
.endproc

.proc plat_psg
        tay
        txa
        sta     PLAT_AY,y
        rts
.endproc

.proc plat_psg_tono                     ; Y = the fine tone register, A = its value, X = the coarse register's value
        sta     PLAT_AY,y
        txa
        sta     PLAT_AY+1,y
        rts
.endproc

.proc plat_teclado_fila
        tay
        lda     PLAT_TECLADO,y
        rts
.endproc

.proc plat_crtc
        tay
        txa
        sta     PLAT_CRTC,y
        rts
.endproc

.proc plat_modo
        and     #3
        sta     PLAT_MODO
        rts
.endproc

.proc plat_di
        pha
        lda     #0
        sta     PLAT_IFF
        pla
        rts
.endproc

.proc plat_ei
        pha
        lda     #1
        sta     PLAT_IFF
        pla
        rts
.endproc

psg_paso:
plat_inicio:
        rts
plat_frame:
        rts
plat_espera:
        rts
plat_pausa:
        rts
plat_disco_guarda:
plat_disco_carga:
        sec
        rts
plat_final:
        jmp     plat_final
