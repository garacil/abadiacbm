<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Plataforma-C64.md: se edita la plantilla, no esta página. -->
<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# La plataforma del Commodore 64

[Inicio](Inicio.md) · anterior: [El sonido](Sonido.md) · siguiente: [El Commodore 128](Commodore-128.md)

El juego nunca toca el hardware: cada acceso del original al hardware del CPC es una llamada a la capa de plataforma,
`src/c64/plataforma/`, con los valores del CPC.  Estas pocas rutinas son todo lo que convierte el juego del CPC en un
juego del C64.

| Fichero | Qué |
|---|---|
| `interrupcion.s` | la preparación de la máquina, la interrupción de 300 Hz, `DI` / `EI`, el byte aleatorio |
| `pantalla.s`, `tinta.s` | la dirección de pantalla del CPC en el bitmap; las tintas |
| `psg.s` | los registros del AY en el SID ([El sonido](Sonido.md)) |
| `teclado.s` | la matriz del teclado del CPC a partir del teclado y el joystick del C64 |
| `disco.s` | grabar y cargar una partida, y la carga del final, a través del KERNAL |
| `c128.s` | las partes propias del Commodore 128 ([El Commodore 128](Commodore-128.md)) |
| `interrupcion500.s`, `teclado500.s`, `tinta500.s`, `p500.s`, `io500.inc` | las mismas piezas para el P500 ([El Commodore P500](Commodore-P500.md)) |

## La preparación

`plat_inicio` convierte el C64 en la máquina que espera el juego: sin ROM (RAM en todas partes salvo la E/S), todas las
interrupciones apagadas salvo el temporizador A de la CIA 1 cada 3279 ciclos (los 300,48 Hz del CPC), los vectores en
RAM, el VIC-II en el banco 3 con el bitmap multicolor en `$E000` y la RAM de pantalla en `$C000`, todo negro y el SID
en reposo:

[`src/c64/plataforma/interrupcion.s`](../../../src/c64/plataforma/interrupcion.s#L57-L125), líneas 57–125:

```asm
.proc plat_inicio
        sei
        cld
        lda     #MEM_IO
        sta     MEMCFG
        lda     #$7F                    ; no interrupts from the CIAs
        sta     CIA1_ICR
        sta     CIA2_ICR
        lda     CIA1_ICR
        lda     CIA2_ICR
        lda     #0                      ; none from the VIC-II, no sprites
        sta     VIC_D01A
        sta     VIC_D015
        sta     VIC_BORDE
        sta     VIC_FONDO
        lda     #$FF
        sta     VIC_D019
        sta     CIA1_DDRA               ; the keyboard: columns out, rows in
        sta     CIA1_PRA
        lda     #0
        sta     CIA1_DDRB
        lda     #<plat_nmi              ; the vectors (RAM: the KERNAL is off)
        sta     $FFFA
        sta     $FFFC
        lda     #>plat_nmi
        sta     $FFFB
        sta     $FFFD
        lda     #<plat_irq
        sta     $FFFE
        lda     #>plat_irq
        sta     $FFFF
.ifdef C128
        jsr     c128_inicio             ; the common RAM, block 1's vectors (plataforma/c128.s)
.endif
        lda     CIA2_DDRA               ; VIC bank 3 ($C000-$FFFF): bits 0-1 = 00 (the serial bus bits kept)
        ora     #$03
        sta     CIA2_DDRA
        lda     CIA2_PRA
        and     #$FC
        sta     CIA2_PRA
        lda     #$08                    ; screen RAM $C000, bitmap $E000
        sta     VIC_D018
        lda     #$18                    ; multicolour, 40 columns
        sta     VIC_D016
        ldx     #0                      ; the screen RAM and the colour RAM black
        txa
:       sta     PANTALLA,x
        sta     PANTALLA+$100,x
        sta     PANTALLA+$200,x
        sta     PANTALLA+$2E8,x
        sta     COLOR_RAM,x
        sta     COLOR_RAM+$100,x
        sta     COLOR_RAM+$200,x
        sta     COLOR_RAM+$2E8,x
        inx
        bne     :-
        lda     #$3B                    ; bitmap mode, display on, 25 rows
        sta     VIC_D011
        jsr     psg_inicio
        lda     #<(CICLOS_TICK - 1)     ; CIA 1 timer A: the tick
        sta     CIA1_TAL
        lda     #>(CICLOS_TICK - 1)
        sta     CIA1_TAH
        lda     #$11                    ; load, start, continuous
        sta     $DC0E
        lda     #$81                    ; its interrupt on
        sta     CIA1_ICR
        rts
.endproc
```

## El teclado y el joystick

El juego lee el teclado del CPC como diez filas de ocho teclas (`sys_read_keyboard`).  Al leer la primera fila, el C64
explora todo su teclado y el joystick del puerto 2 y los traduce, tecla a tecla, a la matriz del CPC; las otras nueve
filas devuelven esa misma foto, coherente, como la exploración de unos cientos de microsegundos del CPC.  El reparto:

* **el joystick** del puerto 2 pasa a ser el joystick 0 del CPC (fila 9); los alias del propio juego hacen el resto,
  como en un CPC: arriba avanza, izquierda y derecha giran, abajo es ESPACIO y el disparo es cursor abajo (Adso);
* **cada tecla del C64** es una tecla del CPC, por su posición en la matriz: letras, signos, espacio, RETURN, SHIFT,
  CTRL → CONTROL, RUN/STOP → ESC, la flecha izquierda → TAB, INST/DEL → DEL, C= → COPY, y los cursores del C64 (con
  SHIFT para arriba y para la izquierda);
* **Q, A, O y P** hacen de cursores (A adelanta a Adso, O y P giran, Q avanza), salvo **Q con R pulsada**, que es la Q
  del CPC: la combinación Q + R del espejo se hace pulsando primero la R, porque Q sola haría subir a Guillermo un
  escalón;
* **las cifras** no son teclas del CPC (el juego no las lee): eligen la ranura de grabación.

[`src/c64/plataforma/teclado.s`](../../../src/c64/plataforma/teclado.s#L19-L37), líneas 19–37:

```asm
; plat_teclado_fila: A = CPC matrix row 0-9 -> A = the row, active low (bit b of row r = CPC key 8r + b).
; X kept, Y clobbered.  Needs the I/O visible ($01 = $35).
; The game reads the ten rows in order (sys_read_keyboard 2D50h, its only reader): reading row 0 scans the
; whole C64 matrix and the joystick into the ten rows, the other rows return that scan (one consistent picture,
; as the CPC's scan of a few hundred microseconds).
;   - joystick port 2 ($DC00 with no column selected): CPC row 9, the CPC's joystick 0: bits 0-3 up, down, left,
;     right as the C64's, fire -> bit 5 (fire 1).  The game's own aliases (2E2Eh-2E41h) then give, as on a
;     CPC: up = advance, left/right = turn, down = space, fire = cursor down.
;   - each C64 key -> one CPC key (tecla_cpc, by the C64 matrix position): letters, punctuation, space, return,
;     shift, CTRL -> CONTROL, RUN/STOP -> ESC, the left-arrow key -> TAB, INST/DEL -> DEL, C= -> COPY,
;     CRSR down / right -> cursor down / right, with SHIFT -> cursor up / left (the C64's own cursor keys).
;   - Q A O P as the cursors (the C64's cursors need SHIFT for up and left, so walking with
;     SHIFT + CRSR down and turning with CRSR right reads as left): A -> cursor down (Adso), O -> cursor left,
;     P -> cursor right, Q -> cursor up (walk) but when R is down too, then the CPC's Q (the mirror's Q + R:
;     press R first, or Guillermo walks up a step).
;   - the digit keys choose the save slot (the last character of the save file's name, disco.s), not CPC keys:
;     the game does not read them.
;   - rows that read low with no column selected (joystick port 1, or a key in a column joystick 2 pulls low)
;     are left out of the scan, so the joystick does not make phantom keys.
```

## Las tintas

Ver [Mapa de memoria](Mapa-de-memoria.md), «La pantalla»: una tinta del CPC se convierte en `$D021`, en un nibble de la
RAM de pantalla o de la RAM de color de las celdas del juego, y no se redibuja ningún píxel.  Las tablas de paletas del
juego ya tienen colores del C64, elegidos por su tono a partir de los del CPC (`src/c64/datos/paleta.tsv`).

## El disco y el KERNAL

El juego usa la página cero y las páginas 2 y 3, que necesita el KERNAL.  Para grabar o cargar una partida (CTRL + ← en
el juego) o para cargar el final, la plataforma aparta la parte del KERNAL de esas páginas, les da los valores con los
que arranca el KERNAL, conecta la ROM del KERNAL, la llama y lo vuelve a poner todo como estaba:

[`src/c64/plataforma/disco.s`](../../../src/c64/plataforma/disco.s#L18-L44), líneas 18–44:

```asm
; plat_disco_guarda: In: zhl = the block's first byte, zde = its length (the tape menu's saved game: 1500 bytes
;   from D64_STATE_BUFFER).  Saves it as the file "ABADIA64.BSn" (n = plat_ranura, the last digit key pressed,
;   "1" at first: teclado.s) on the drive plat_unidad, replacing it (the old one is scratched first).  Out:
;   C = 0, or C = 1 when the KERNAL reported an error (no drive...; the drive's own errors, such as a full disk,
;   are not read back).  A, X, Y clobbered; zbc..zp3 kept.
; plat_disco_carga: In: zhl = where, zde = the length.  Loads "ABADIA64.BSn" there.  Out: C = 0 when it was
;   loaded and had exactly that length, else C = 1 (no file, an error; a longer file would have been loaded
;   past the block: only this game writes these files).  A, X, Y clobbered.
;   Both are called with the interrupts off (the tape menu's DI) and return with them off; no tick is
;   delivered meanwhile (as during the CPC's tape operations).
; plat_final: the end of the game: loads the ending parchment ("FINAL", c64/pergamino/final.prg, a cc65
;   program at $0801) from plat_unidad and runs it ($080D); never returns.  The game's screen stays while it
;   loads; then the machine is set as after a reset (IOINIT, RAMTAS, the KERNAL's vectors, CINT) for that
;   program, which expects the KERNAL's interrupt chain.  A load error flashes the border and tries again.
;
; The game uses the zero page and $0200-$03FF (c64/MAPA.md), which the KERNAL needs.  Around a KERNAL call the
; KERNAL's part of them is put aside in $0100-$01AE (the bottom of the stack page: the stack is shallow at the
; tape menu, ~16 bytes, and the KERNAL's own use of it is measured below 60 bytes: c64/plataforma/README.md)
; and given the values the KERNAL starts with:
;   $90-$FF (the KERNAL's zero page: status, file and serial variables) -> 0;
;   $0259-$0276 (the file tables: OPEN writes entry 0) -> kept aside, untouched;
;   $02A1 (the RS-232 flags: the serial LISTEN waits while bits 0-1 are set) -> 0;
;   $0314-$0333 (the vectors) -> the KERNAL ROM's table (copied from $FD30: RESTOR would also write the RAM
;     under $FD30, a part of the bitmap), with the NMI (RESTORE key) -> an RTI and the IRQ -> an acknowledge.
; CIA 1's timer A interrupt is off during the call (the KERNAL's serial code reads CIA 1's flags itself), $01 =
; $36 (KERNAL and I/O; $A000-$BFFF stays RAM: the game's data is readable), the VIC bank and the screen as
; the game has them (the serial code keeps $DD00's bits 0-1).  Then everything goes back.
```

La partida grabada es el bloque de estado de 1500 bytes que el CPC grababa en la cinta (los personajes, los objetos,
las puertas, el reloj, las variables de los guiones), en un fichero `ABADIA64.BSn`, donde n es la última cifra
pulsada, así que se pueden guardar diez partidas.  En la edición de cinta el mismo menú graba y carga en la cinta con
las rutinas de cinta del KERNAL.

## El byte aleatorio

El original lee una sola vez el registro de refresco del Z80 (`LD A,R`): para elegir el número del espejo.  El C64
combina el temporizador de la CIA, que corre dentro del tick, con la línea del haz:

[`src/c64/plataforma/interrupcion.s`](../../../src/c64/plataforma/interrupcion.s#L230-L234), líneas 230–234:

```asm
.proc plat_aleatorio
        lda     CIA1_TAL
        eor     VIC_D012
        rts
.endproc
```
