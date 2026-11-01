<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Commodore-P500.md: se edita la plantilla, no esta página. -->
# El Commodore P500

[Inicio](Inicio.md) · anterior: [El Commodore 128](Commodore-128.md) · siguiente: [La carga: cinta y discos](Carga.md)

El P500 es el CBM-II 510: un MOS 6509, el VIC-II y el SID del C64, 128 KiB de RAM y unidades de disco IEEE-488.
abadia128ks funciona en él como el juego completo del C128 (`-D C128`: los datos del segundo banco, las cabezas en alta
resolución, el Ave María) sobre una plataforma propia (`-D P500`: `src/c64/plataforma/p500.s`, `interrupcion500.s`,
`teclado500.s`, `tinta500.s`, `io500.inc`).  Cada dato de la máquina que uso sale del *700 Reference Guide* de
Commodore, de la ROM del KERNAL 901234-02 y del entorno cbm510 de cc65, y lo comprobé en el xcbm5x0 de VICE
(`doc/referencias/p500.md`).

## Los bancos del 6509

El 6509 direcciona 16 bancos de 64 KiB.  No tiene instrucciones propias: dos registros en `$0000` y `$0001` de cada
banco eligen el banco en el que corre el programa y el banco de las únicas dos instrucciones que leen o escriben en
otro banco, `LDA (zp),Y` y `STA (zp),Y`.  Cualquier otra instrucción con `(zp),Y` (un `CMP`, un `ADC`…) lee el banco en
el que se ejecuta: lo comprobé, y el teclado tuvo que leer con `LDA` y comparar después.  El juego corre en el banco 0
con `$01 = 0`; sus salas, sus textos, los trazos negros de las cabezas y el Ave María están en el banco 1; todos los
chips están en el banco 15:

[`src/c64/plataforma/io500.inc`](../../../src/c64/plataforma/io500.inc#L20-L24), líneas 20–24:

```asm
; The MOS 6509 has the 6502's instructions and no others; what it adds is two registers at $0000 and $0001 of every
; bank: the execution bank (where the program runs) and the indirect bank, used by two instructions only, LDA (zp),Y
; and STA (zp),Y, which read or write that bank (Commodore's 700 reference manual; cc65's cbm510 runtime works so).
; The game runs in bank 0 with $01 = 0, so its own (zp),Y accesses stay in bank 0; an I/O register is reached by
; $01 = 15, LDA/STA (pointer),Y, $01 = 0.
```

Lo que el C128 alcanza poniendo el bloque 1 con su MMU, el P500 lo alcanza byte a byte a través del registro del banco
indirecto; `far_lee` es el lector de la tabla de salas:

[`src/c64/plataforma/p500.s`](../../../src/c64/plataforma/p500.s#L113-L119), líneas 113–119:

```asm
.proc far_lee
        inc     P5_IND                  ; bank 1
        lda     (zhl),y
        dec     P5_IND                  ; bank 0
        ora     #0                      ; (N and Z of A)
        rts
.endproc
```

Un `LDA abs` normal siempre lee el banco en el que corre el programa: la copia de los trazos negros de una cabeza desde
el banco 1 también tuvo que pasar a ser una lectura indirecta (`cabezas128.s`, `neg_b1_copia`).

## Los chips del banco 15

El código que se comparte con el C64 y el C128 escribe en el VIC-II y en el SID a través de tres macros: en esas
máquinas cada una es la instrucción normal, los mismos bytes de antes; en el P500 es una llamada corta que pone
`$01 = 15` alrededor de un `STA (zp),Y`:

[`src/c64/plataforma/io500.inc`](../../../src/c64/plataforma/io500.inc#L66-L73), líneas 66–73:

```asm
.macro P5_STA rutina, reg               ; (the P500's STA: A to the register through the routine)
        php
        sei                             ; (before P5_A: an interrupt's own macros use it)
        sta     P5_A
        lda     #reg
        jsr     rutina
        plp
.endmacro
```

[`src/c64/plataforma/p500.s`](../../../src/c64/plataforma/p500.s#L249-L261), líneas 249–261:

```asm
p5_vic_k:
        sty     P5_Y
        tay
vic_cola:
        lda     #P5_SISTEMA
        sta     P5_IND
        lda     P5_A
        sta     (P5_PVIC),y
        lda     #0
        sta     P5_IND
        lda     P5_A
        ldy     P5_Y
        rts
```

Para que el VIC-II vea la pantalla del banco 0, las líneas CA y CB de la primera 6525 (la TPI 1, registro de control
`$DE06`, bits 4-7 = %1010) tienen que estar bajas; con el valor que dejaba el pergamino de 2016 ($03) la pantalla de
carga salía negra.

## La interrupción de 300 Hz

El tick del juego viene del temporizador A de la 6526, a través de la primera 6525 (la TPI 1), el controlador de
interrupciones del CBM-II.  El orden de la confirmación importa: si se termina la TPI 1 mientras la línea de la 6526
sigue baja, la interrupción vuelve enseguida, para siempre; si solo se lee la 6526 antes de la TPI 1, se pierde el tick
que cae entre las dos y ya no llega ningún tick más.  Así que la 6526, la TPI 1 y otra vez la 6526:

[`src/c64/plataforma/interrupcion500.s`](../../../src/c64/plataforma/interrupcion500.s#L176-L222), líneas 176–222:

```asm
; the game's build: the game's sys_tick (2899h) inline, as interrupcion.s's: the 6526 and the 6525 acknowledged, the
; tick counter [289C] + 1 kept at FFh, the sound (0CD0: the opcode at plat_irq_sonido, JSR while a channel plays, BIT
; else) and the phrase scroller (368A).  t_frase lets a further tick in (its CLI): this handler is re-entrant.
.proc plat_irq
        pha
        tya
        pha
        lda     P5_IND
        pha
        lda     P5_PIO
        pha
        lda     P5_PIO+1
        pha
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$0D                    ; the 6526's flags read: its line up
        lda     (P5_PCIA),y
        ldy     #$07                    ; TPI 1's active interrupt ended (written back); with the 6526's line still
        lda     (P5_PTPI1),y            ;   down it would be taken again at once, an endless stream of interrupts
        sta     (P5_PTPI1),y
        ldy     #$0D                    ; the 6526's flags again: an underflow between the two reads, whose interrupt
        lda     (P5_PCIA),y             ;   TPI 1 has just ended, would leave its line down for ever (no new edge, no
                                        ;   tick any more); this read puts it up (that one tick is lost)
        lda     #0
        sta     P5_IND                  ; the game's data
        cld
        inc     D64_SYS_TICKS           ; 2899h: the tick counter, kept at FFh
        bne     :+
        dec     D64_SYS_TICKS
:
::plat_irq_sonido:
        bit     s_interrupcion          ; 0CD0: JSR ($20) while a channel plays (objetos_sonido.s), BIT ($2C) else
        inc     D64_TXT_SCROLL_TIMER    ; 368A's test: the scroller's 2Dh-th tick
        lda     D64_TXT_SCROLL_TIMER
        cmp     #$2D
        bne     :+
        jsr     t_frase                 ; (X and Y kept)
:       pla
        sta     P5_PIO+1
        pla
        sta     P5_PIO
        pla
        sta     P5_IND
        pla
        tay
        pla
        rti
```

## El teclado

El teclado del CBM-II es una matriz de 16 columnas y 6 filas en la segunda 6525 (la TPI 2), que leo como la lee el
KERNAL (cada fila dos veces, hasta que dos lecturas coinciden), y los dos puertos de juego están en la 6526; el
resultado es la matriz del CPC que lee el juego, igual que en el C64:

[`src/c64/plataforma/teclado500.s`](../../../src/c64/plataforma/teclado500.s#L146-L172), líneas 146–172:

```asm
columna:
        ldy     #0
        lda     col_pa,x
        sta     (P5_PIO),y
        iny
        lda     col_pb,x
        sta     (P5_PIO),y
        iny
:       lda     (P5_PIO),y              ; the rows (until two reads agree: LDA (zp),Y twice, the 6509's CMP (zp),Y
        sta     filas_ant               ;   would read bank 0)
        lda     (P5_PIO),y
        cmp     filas_ant
        bne     :-
        ora     #$C0                    ; (bits 6-7: the VIC-II's bank lines)
        eor     #$FF
        beq     siguiente
        sta     pulsadas                ; keys down in column x
        ldy     seis,x                  ; 6 x + row
tecla:  lsr     pulsadas
        bcc     :+
        jsr     aplica
:       iny
        lda     pulsadas
        bne     tecla
siguiente:
        dex
        bpl     columna
```

## El KERNAL del banco 15

Grabar y cargar pasan por el KERNAL, que tiene su propia página cero y su propia pila en el banco 15: no hay que mover
nada del juego (el C128 intercambia su RAM con una foto).  La llamada entre bancos es el propio protocolo del KERNAL, el
mismo que usa el entorno de cc65: la pila del banco 15 recibe el camino de vuelta, los registros y la dirección de la
rutina; un `STA $00` en `$FFF6`, igual en los dos bancos, lleva la CPU al banco 15:

[`src/c64/plataforma/p500.s`](../../../src/c64/plataforma/p500.s#L375-L435), líneas 375–435:

```asm
.proc k15
        php
        pha
        lda     $01FF                   ; (the bottom of the game's stack, back after the call)
        sta     fondo
        lda     #P5_SISTEMA
        sta     P5_IND
        txa
        pha
        tya
        pha
        sei
        ldy     #$FF
        lda     (K_P1),y                ; bank 15's stack pointer
        tay
        lda     #0                      ; the bank to come back to
        sta     (K_P1),y
        dey
        lda     #>(K_EXCRTS - 1)
        sta     (K_P1),y
        dey
        lda     #<(K_EXCRTS - 1)
        sta     (K_P1),y
        tya
        sec
        sbc     #7
        sta     k_sp
        tay
        pla                             ; Y, X, A, P
        iny
        sta     (K_P1),y
        pla
        iny
        sta     (K_P1),y
        pla
        iny
        sta     (K_P1),y
        pla
        iny
        sta     (K_P1),y
        lda     k_dir                   ; the routine's address - 1
        iny
        sta     (K_P1),y
        lda     k_dir+1
        iny
        sta     (K_P1),y
        ldy     k_sp
        lda     #>(K_EXPULL - 1)
        sta     (K_P1),y
        dey
        lda     #<(K_EXPULL - 1)
        sta     (K_P1),y
        dey
        tsx
        stx     $01FF                   ; bank 0's stack pointer, for the way back ($FF11)
        tya
        tax
        txs
        lda     #P5_SISTEMA
        jmp     K_CAMBIA
.endproc
```

## La carga

El menú, el pergamino y el cargador son un programa de cc65 para el destino cbm510.  Carga el banco 1 del juego y su
banco 0, comprimido, en el banco 1, y empieza allí la última etapa: corriendo en el banco 1, la etapa descomprime en el
banco 0 con las dos instrucciones entre bancos (el descompresor de Exomizer sin cambios: sus literales se leen en el
banco que corre, y sus copias y su salida van por `LDA`/`STA (zp),Y`), pone las opciones (las notas del paso y del
pitido en silencio si se han quitado, ver [El sonido](Sonido.md)), carga el Ave María y entra en el juego:

[`src/c64/discop500/etapa500.s`](../../../src/c64/discop500/etapa500.s#L129-L147), líneas 129–147:

```asm
; the game: bank 0's $FFF6-$FFFA = STA $00, JMP principal_inicio; the switch from bank 1's $FFF6
juego:  lda     #0
        sta     IND
        lda     #<$FFF6
        sta     PTR
        lda     #>$FFF6
        sta     PTR + 1
        ldy     #4
:       lda     salto,y
        sta     (PTR),y
        dey
        bpl     :-
        lda     #$85                    ; bank 1's $FFF6: STA $00
        sta     K_CAMBIA
        lda     #$00
        sta     K_CAMBIA + 1
        lda     #0                      ; bank 0
        jmp     K_CAMBIA
salto:  .byte   $85, $00, $4C, <J_PRINCIPAL_INICIO, >J_PRINCIPAL_INICIO
```

La etapa se queda en el banco 1 durante toda la partida: con el 100 % el juego vuelve a ella, y ella carga el final
encima del juego y lo arranca como lo haría el `SYS` del BASIC (`src/c64/discop500/NOTAS.md`).

## Certificado contra el PC

El juego del P500 está certificado fotograma a fotograma contra mi reconstrucción del PC, igual que el del C128: cuatro
sesiones al azar de 6000 fotogramas desde su propio disco, 237 datos comparados en cada fotograma, 0 diferencias (ver
[Construcción y certificación](Construccion.md)).  Así que el P500 hace exactamente lo mismo que el PC original, también
en sus rarezas: a completas el abad persigue a Guillermo hasta que entra en su celda, y su buscador de caminos puede
dejarlo atascado en una puerta que se abre y se cierra a su paso.
