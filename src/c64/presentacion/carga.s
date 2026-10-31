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

; carga_juego: the end of the first stage ("abadia": the presentation, presentacion.c's gameload), as the CPC
; tape's loader: the game's loader (cargador.s, assembled apart for DESTINO, its binary included here) copied to its
; place and started; it never returns.  The game is loaded where the first stage lives, so the loader runs from memory
; the game rebuilds at its start (c64/cinta/FLUJO.md).  Built with -D DESTINO=<the loader's address> (construye.sh
; reads it from cargador.lbl) and --bin-include-dir to cargador.bin.  (c64/pergamino/carga.s, the same code.)

        .export _carga_juego
        .importzp ptr1, ptr2

.segment "RODATA"
cargador:
        .incbin "cargador.bin"
cargador_fin:
LARGO = cargador_fin - cargador

.segment "CODE"

.proc _carga_juego
        sei
        lda     #<cargador
        sta     ptr1
        lda     #>cargador
        sta     ptr1+1
        lda     #<DESTINO
        sta     ptr2
        lda     #>DESTINO
        sta     ptr2+1
        ldx     #>LARGO                 ; whole pages
        ldy     #0
pagina: cpx     #0
        beq     resto
:       lda     (ptr1),y
        sta     (ptr2),y
        iny
        bne     :-
        inc     ptr1+1
        inc     ptr2+1
        dex
        jmp     pagina
resto:  cpy     #<LARGO
        beq     salta
        lda     (ptr1),y
        sta     (ptr2),y
        iny
        jmp     resto
salta:  jmp     DESTINO
.endproc
