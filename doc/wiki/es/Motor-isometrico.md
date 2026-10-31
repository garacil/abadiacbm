<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Motor-isometrico.md: se edita la plantilla, no esta página. -->
# Las salas y el motor isométrico

[Inicio](Inicio.md) · anterior: [El reloj y las ceremonias](Reloj.md) · siguiente: [Los personajes y su movimiento](Personajes.md)

La abadía es un mundo de 256 × 256 posiciones en tres pisos (la planta baja, el primer piso con el scriptorium y la
biblioteca bajo el tejado), cortado en **salas** de 16 × 16 posiciones.  Solo se enseña una sala a la vez, dibujada en
proyección isométrica; cuando el personaje al que sigue la cámara sale de ella, se construye y se dibuja la siguiente.
Todo el motor está en `src/c64/juego_final/motor_iso.s`.

## Qué sala, y desde qué lado

Los mapas de los pisos dan un número de sala para cada cuadrado de 16 × 16 de cada piso.  Cada fotograma
`iso_update_camera_room` mira el cuadrado del personaje al que sigue la cámara (`x & F0h`, `y & F0h` y el piso de su
altura); cuando ha cambiado, elige la sala y también la **orientación de la cámara**, que depende de la posición de la
sala: la abadía se ve desde un lado distinto en salas vecinas, uno de los rasgos más conocidos del juego.

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L938-L946), líneas 938–946:

```asm
; 1F79 iso_update_camera_room: main-loop step.  The record of the character the camera follows ([28D9h]): x & F0h
; vs 28C6h (then the origin x 2636h = x - 0Ch), y & F0h vs 28C7h (origin y), the floor base of its height vs
; 28C8h (then the floor 264Eh and the floor map 2013h); each one that changed is stored and counted; none ->
; return (A = 0).  Else 2909h = the count; the room is dark (11DCh = 1) on floor 16h with room x >= 20h but the
; room (20h, 60h); the light sprite 2B20h = FEh; the camera orientation 20A5h = ((X ^ Y) & 1) | (X & 1) << 1 of
; the room coordinates; iso_select_room(map[Y << 4 | X]); chr_fill_height_buffer; the sprite offsets 28D5h =
; 2BF0h + 40h * orientation; the camera transform 2656h = the word 1E81h[orientation]; doors and objects placed;
; then for each chr_table entry (10 bytes, FFh in byte 1 ends): 2070h = sprite, 2074h = record, 25AEh = word +6,
; 25D9h = word +8, spr_update_char_sprite and chr_mark_hbuf (C = [record + 0Eh]).  Out: A = FFh (0 unchanged).
```

El piso sale de la altura del personaje con `iso_floor_base`: por debajo de 0Dh es la planta baja (base 00h), desde 18h
la biblioteca (16h) y entre medias el primer piso (0Bh).  El acarreo queda como lo dejaba el Z80, porque hay quien lo
mira:

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L1098-L1111), líneas 1098–1111:

```asm
; 2097 iso_floor_base: the floor of height A: B = 00h below 0Dh, 16h from 18h, else 0Bh; the carry as the Z80's
; (set when A < 18h), A kept.
iso_floor_base:
        ldx     #0
        cmp     #$0D
        bcc     @set
        ldx     #$16
        cmp     #$18
        bcs     @clr
        ldx     #$0B
@set:   stx     zbc+1
        sec
        rts
@clr:   stx     zbc+1
```

Con la orientación de la cámara, las coordenadas del mundo se giran antes de proyectarlas.  Son cuatro
transformaciones sobre la rejilla de 28h posiciones; la orientación 2 es la 1 aplicada dos veces.  Al cambiar de sala,
`iso_update_camera_room` copia la dirección de la que toca, de una tabla de cuatro (`ISO_CAMERA_ROTATIONS`), en la
palabra `CHR_CAMERA_TRANSFORM` (2656h): en el Z80 era el operando de un `CALL` que el programa reescribía; en el 6502
es un puntero a una de estas rutinas:

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L1122-L1145), líneas 1122–1145:

```asm
; the camera transforms (2656h holds one): (x, y) = (L, H).  20A9 orientation 1: (28h - y, x), A = L;
; 20AE orientation 0: nothing; 20AF orientation 2: (28h - x, 28h - y), A = L; 20B8 orientation 3: (y, 28h - x),
; A = H.
iso_rotate_cam1:
        lda     #$28
        sec
        sbc     zhl+1
        ldx     zhl
        stx     zhl+1
        sta     zhl
iso_rotate_cam0:
        rts
iso_rotate_cam2:                        ; orientation 1 twice
        jsr     iso_rotate_cam1
        jmp     iso_rotate_cam1
iso_rotate_cam3:
        lda     #$28
        sec
        sbc     zhl
        ldx     zhl+1
        stx     zhl
        sta     zhl+1
        rts

```

## Las salas son programas

Una sala no es una imagen.  Su registro en la tabla de salas (`ISO_ROOM_TABLE`: 129 registros en el juego de 64 KiB) es
una lista de **entradas** de tres o cuatro bytes, y cada entrada coloca un **bloque** (una pared, un suelo, una
escalera, un arco, una mesa, una estantería…) en una posición de la rejilla de la sala, con dos parámetros de tamaño y
una altura opcional:

| byte | bits | significado |
|---|---|---|
| 0 | 7-1 | el tipo de bloque: un número par, el índice de una palabra de la tabla de bloques |
| 0 | 0 | 1 = sigue un byte de altura |
| 1 | 4-0, 7-5 | x (0-31) y el primer parámetro de tamaño p1 (0-7) |
| 2 | 4-0, 7-5 | y (0-31) y el segundo parámetro de tamaño p2 (0-7) |
| 3 | 7-0 | la altura (si la hay) |

`FF` termina el registro.  `iso_draw_room` vacía el búfer de baldosas, llena el área de juego (de negro si la sala está
a oscuras) y ejecuta el registro; una sala iluminada se dibuja después desde el búfer de baldosas:

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L271-L304), líneas 271–304:

```asm
; 1611 iso_draw_room: builds and shows the current room: the tile buffer cleared and the play area filled with
; 00h (lit) or FFh (dark, D64_ISO_ROOM_DARK not 0); iso_build_room on the record [11DAh] + 1 with the cell update
; of iso_put_tile (12C0h = 12C9h; 12C2h after it); a lit room is then drawn (iso_draw_room_spiral, a tail jump).
iso_draw_room:
        lda     D64_ISO_ROOM_DARK
        beq     :+
        lda     #$FF
:       jsr     iso_clear_tile_buffer
.ifdef C128
        jsr     far_sala                ; the C128: the record from block 1 into SALA (plataforma/c128.s)
        lda     #<(SALA + 1)
        sta     zix
        lda     #>(SALA + 1)
        sta     zix+1
.else
        lda     D64_ISO_ROOM_PTR
        clc
        adc     #1
        sta     zix
        lda     D64_ISO_ROOM_PTR+1
        adc     #0
        sta     zix+1
.endif
        lda     #<MI_PUT_TILE_UPDATE
        sta     D64_ISO_PUT_TILE_JUMP
        lda     #>MI_PUT_TILE_UPDATE
        sta     D64_ISO_PUT_TILE_JUMP+1
        jsr     iso_build_room
        lda     #<MI_PUT_TILE_MARK
        sta     D64_ISO_PUT_TILE_JUMP
        lda     D64_ISO_ROOM_DARK
        bne     :+
        jmp     iso_draw_room_spiral
:       rts
```

`iso_build_room` descodifica una entrada tras otra.  Antes de entrar en un bloque mete en la pila su propia dirección
como marca de vuelta, para que el `END` del bloque vuelva a ella a por la entrada siguiente, igual que hacía el Z80 con
su propia pila:

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L306-L375), líneas 306–375:

```asm
; 163F iso_build_room: interprets the room entries at IX up to a byte FFh.  Entry: byte 0 = block type (bits 1-7:
; the word of the block table) | bit 0 (a height byte follows); byte 1 = x | p1 << 5; byte 2 = y | p2 << 5;
; [byte 3 = height].  For each: the block at 1697h (D64_ISO_CUR_BLOCK), depth 0, 0, height (1BEBh) = the byte or
; FFh; HL = y, x, BC = p2, p1; the tag (this routine) pushed; the block entered with its tile list; its END pops
; IX = the next entry and returns here.  Out: IX = the FFh, A = FFh.
iso_build_room:
        ldy     #0
        lda     (zix),y
        cmp     #$FF
        bne     :+
        rts
:       and     #$FE
        tax
        lda     D64_ISO_BLOCK_TABLE,x
        sta     D64_ISO_CUR_BLOCK
        lda     D64_ISO_BLOCK_TABLE+1,x
        sta     D64_ISO_CUR_BLOCK+1
        ldx     #0                      ; L = x, C = p1; H = y, B = p2
:       iny
        lda     (zix),y                 ; x | p1 << 5, y | p2 << 5
        pha
        and     #$1F
        sta     zhl,x
        pla
        lsr
        lsr
        lsr
        lsr
        lsr
        sta     zbc,x
        inx
        cpx     #2
        bne     :-
        lda     #0
        sta     D64_ISO_DEPTH_X
        sta     D64_ISO_DEPTH_Y
        ldy     #0
        lda     (zix),y
        lsr                             ; C = a height follows
        lda     #$FF
        ldy     #3
        bcc     :+
        lda     (zix),y
        iny
:       sta     D64_ISO_BLOCK_HEIGHT
        tax
        tya                             ; IX past the entry
        clc
        adc     zix
        sta     zix
        bcc     :+
        inc     zix+1
:       lda     #>(iso_build_room-1)    ; the tag 163Fh: END returns to the next entry
        pha
        lda     #<(iso_build_room-1)
        pha
        ldy     #0                      ; DE = the tile list, the script after it
        lda     (D64_ISO_CUR_BLOCK),y
        sta     zde
        iny
        lda     (D64_ISO_CUR_BLOCK),y
        sta     zde+1
        lda     D64_ISO_CUR_BLOCK
        clc
        adc     #2
        sta     mi_ptr
        lda     D64_ISO_CUR_BLOCK+1
        adc     #0
        sta     mi_ptr+1
        txa                             ; A = the height
```

## El intérprete de bloques

Cada bloque es una lista de 12 números de baldosa y un pequeño programa de **código de bytes** que pone esas baldosas
en el búfer.  Los códigos de operación están guardados complementados (`FF` es la operación 0) y el despachador salta a
cada manejador a través de una tabla de direcciones con un `RTS`, el equivalente en el 6502 del `PUSH DE / RET` del
Z80:

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L402-L416), líneas 402–416:

```asm
; 1C2C the dispatcher: op = [IX++], the handler of ~op (opcodes FFh down to E4h), entered by RTS as the Z80's
; PUSH DE / RET; every handler comes back here.
mi_dispatch:
        ldy     #0
        lda     (zix),y
        inc     zix
        bne     :+
        inc     zix+1
:       eor     #$FF
        tax
        lda     mi_ops_hi,x
        pha
        lda     mi_ops_lo,x
        pha
        rts
```

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L727-L738), líneas 727–738:

```asm
; the handlers of opcodes FFh down to E4h (index ~op), minus one for the RTS
mi_ops_lo:
        .lobytes mi_op_end-1, mi_op_loop_p1-1, mi_op_loop_p2-1, mi_op_push_pos-1, mi_op_pop_pos-1, mi_op_next-1
        .lobytes mi_op_up-1, mi_op_right-1, mi_op_set-1, mi_op_y_inc-1, mi_op_x_inc-1, mi_op_y_dec-1
        .lobytes mi_op_x_dec-1, mi_op_y_add-1, mi_op_x_add-1, mi_op_p1_inc-1, mi_op_p2_inc-1, mi_op_p1_dec-1
        .lobytes mi_op_p2_dec-1, mi_op_call-1, mi_op_left-1, mi_op_jump-1, mi_op_mirror-1, mi_op_mirror-1
        .lobytes mi_op_mirror-1, mi_op_mirror-1, mi_op_mirror-1, mi_op_call_keep-1
mi_ops_hi:
        .hibytes mi_op_end-1, mi_op_loop_p1-1, mi_op_loop_p2-1, mi_op_push_pos-1, mi_op_pop_pos-1, mi_op_next-1
        .hibytes mi_op_up-1, mi_op_right-1, mi_op_set-1, mi_op_y_inc-1, mi_op_x_inc-1, mi_op_y_dec-1
        .hibytes mi_op_x_dec-1, mi_op_y_add-1, mi_op_x_add-1, mi_op_p1_inc-1, mi_op_p2_inc-1, mi_op_p1_dec-1
        .hibytes mi_op_p2_dec-1, mi_op_call-1, mi_op_left-1, mi_op_jump-1, mi_op_mirror-1, mi_op_mirror-1
```

| Código | Significado |
|---|---|
| `FF` END | vuelve a quien llamó (la entrada siguiente de la sala, o el bloque que llamó a este) |
| `FE` / `FD` LOOP | repetir hasta `FA` NEXT p1 o p2 veces |
| `FC` / `FB` | guardar / recuperar la posición |
| `F9` / `F8` / `EB` | una tira de baldosas: hacia arriba, a la derecha, a la izquierda, una celda tras cada una |
| `F7` SET | un registro := una expresión (operandos: literales, los registros de baldosa, p1, p2, la altura, la profundidad) |
| `F6`-`F1` | mover la posición: y+1, x+1, y−1, x−1, y += expr, x += expr |
| `F0`-`ED` | p1 / p2 más o menos 1 |
| `EC` CALL, `E4` CALL_KEEP | ejecutar otro bloque aquí (con sus baldosas o conservando estas) |
| `EA` JUMP | seguir en el programa de otro bloque: la mayoría de los bloques comparten código así |
| `E9`-`E5` MIRROR | reflejar la dirección x hasta el END del bloque: una pared que mira al otro lado es el mismo bloque reflejado |

### Las expresiones

`SET` y los desplazamientos llevan una expresión: un primer valor y después operandos que se suman hasta un byte de C8h
o más, que no se consume; el byte 84h cambia de signo lo acumulado.  Un operando por debajo de 60h es un literal; 82h
dice que el byte siguiente es un literal; los demás son registros del bloque (61h-6Ch las doce baldosas, 6Dh p1, 6Eh
p2, 6Fh la altura, 70h y 71h la profundidad, intercambiadas cuando el bloque está reflejado):

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L812-L837), líneas 812–837:

```asm
; 1D74 iso_expression: the rest of an expression: while [IX] < C8h, 84h negates the value so far, any other
; byte is an operand added to it; the byte that ends it is not consumed.  In: C = the first value, IX.
; Out: C, IX, A = [IX] (>= C8h); B kept.
iso_expression:
@l:     ldy     #0
        lda     (zix),y
        cmp     #$C8
        bcs     @r
        inc     zix
        bne     :+
        inc     zix+1
:       cmp     #$84
        bne     @add
        lda     #0
        sec
        sbc     zbc
        sta     zbc
        jmp     @l
@add:   ldx     zbc
        stx     mi_t0
        jsr     mi_operand
        clc
        adc     mi_t0
        sta     zbc
        jmp     @l
@r:     rts
```

Un suelo, por ejemplo, son dos bucles anidados (p2 + 1 filas de p1 + 1 baldosas) de `TILES_UP t1, t1` más un borde, y un
remate delantero; una pared gruesa es el mismo programa que una fina con otra lista de baldosas.  Toda la abadía se
dibuja con menos de cien bloques de unas pocas decenas de bytes cada uno (88 en la tabla de bloques del juego de 64 KiB).

## El búfer de baldosas y la profundidad

La parte visible de la rejilla son 16 × 20 celdas de 16 × 8 píxeles.  Cada celda del búfer de baldosas guarda las dos
**últimas** baldosas que se le pusieron (la de abajo se dibuja primero) y, para cada una, una **profundidad**: la
posición del bloque en el mundo, para que el motor de sprites pueda decidir después, píxel a píxel, si una baldosa
tapa a un personaje.

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L86-L91), líneas 86–91:

```asm
; 1295 iso_put_tile: puts tile C at the grid position HL (H = y, L = x) when it is visible (y - 8 < 14h,
; x - 8 < 10h).  The cell is tile buffer + 96 (y - 8) + 6 (x - 8): the old tile [5] becomes the lower tile [2];
; [0],[1] = the old depth [3],[4], or the current depth (1BECh, 1BEDh) when it is smaller in both; [3],[4] = the
; current depth; [5] = the tile.  Out: A = the depth y put, or the coordinate that failed (y - 8, x - 8).
; HL, BC kept; X, Y clobbered.  (DE, which no caller reads, is not set.)
iso_put_tile:
```

Las tiras de baldosas se hacen con `iso_put_tile_step` (poner y dar un paso; el paso es una instrucción que se cambia
según la dirección de la tira) y `iso_put_tile_times` (repetirlo mientras quede cuenta).  La profundidad de un bloque
sale de su posición y de su altura, como la inversa de la proyección de los personajes:

[`src/c64/juego_final/motor_iso.s`](../../../src/c64/juego_final/motor_iso.s#L912-L932), líneas 912–932:

```asm
; 1BC6 iso_block_depth: the depth of the block from its position HL (H = y, L = x) and height A: nothing for
; FFh; else t = A / 2 + y, depth x (1BECh) = t + x - 0Fh, depth y (1BEDh) = 10h + t - x.  X clobbered.
iso_block_depth:
        cmp     #$FF
        beq     @r
        lsr
        clc
        adc     zhl+1
        tax
        clc
        adc     zhl
        sec
        sbc     #$0F
        sta     D64_ISO_DEPTH_X
        txa
        clc
        adc     #$10
        sec
        sbc     zhl
        sta     D64_ISO_DEPTH_Y
@r:     rts
```

## El dibujo

Una sala iluminada se dibuja desde el búfer de baldosas en espiral, del centro hacia fuera (`iso_draw_room_spiral`);
cada baldosa son 8 líneas en el formato multicolor del C64, 4 bytes por línea; las baldosas por debajo de 0Bh se copian
opacas y las demás se mezclan con las tablas AND/OR.  Las baldosas viven debajo de la E/S (`$D000`), así que el dibujo
desconecta la E/S mientras las lee.  Una sala a oscuras (las de la biblioteca en el piso alto, todas menos una) deja el
área de juego en negro y solo se ve la luz de la lámpara (ver [Los sprites y la pantalla](Sprites-y-pantalla.md)).

## Todas las rutinas del motor

| Original | Rutina | Línea |
|---|---|---|
| 128Fh | [`util_add_bx_al`](../../../src/c64/juego_final/motor_iso.s#L77) | 77 |
| 1295h | [`iso_put_tile`](../../../src/c64/juego_final/motor_iso.s#L91) | 91 |
| 1D26h | [`iso_put_tile_step`](../../../src/c64/juego_final/motor_iso.s#L184) | 184 |
| — | [`mi_step`](../../../src/c64/juego_final/motor_iso.s#L187) | 187 |
| — | [`mi_step_x`](../../../src/c64/juego_final/motor_iso.s#L190) | 190 |
| 1D48h | [`iso_put_tile_times`](../../../src/c64/juego_final/motor_iso.s#L209) | 209 |
| 16A1h | [`vid_fill_play_area_ff`](../../../src/c64/juego_final/motor_iso.s#L221) | 221 |
| 16A5h | [`iso_clear_tile_buffer`](../../../src/c64/juego_final/motor_iso.s#L226) | 226 |
| 16B2h | [`vid_fill_play_area`](../../../src/c64/juego_final/motor_iso.s#L239) | 239 |
| — | [`mi_nibble`](../../../src/c64/juego_final/motor_iso.s#L255) | 255 |
| 1611h | [`iso_draw_room`](../../../src/c64/juego_final/motor_iso.s#L274) | 274 |
| 163Fh | [`iso_build_room`](../../../src/c64/juego_final/motor_iso.s#L311) | 311 |
| 17F1h | [`mi_enter_block`](../../../src/c64/juego_final/motor_iso.s#L378) | 378 |
| 17EEh | [`mi_enter_keep`](../../../src/c64/juego_final/motor_iso.s#L388) | 388 |
| 1C2Ch | [`mi_dispatch`](../../../src/c64/juego_final/motor_iso.s#L404) | 404 |
| 1DFEh | [`mi_call_return`](../../../src/c64/juego_final/motor_iso.s#L421) | 421 |
| — | [`mi_op_end`](../../../src/c64/juego_final/motor_iso.s#L444) | 444 |
| — | [`mi_op_mirror`](../../../src/c64/juego_final/motor_iso.s#L458) | 458 |
| — | [`mi_mirror_a`](../../../src/c64/juego_final/motor_iso.s#L464) | 464 |
| — | [`mi_op_y_inc`](../../../src/c64/juego_final/motor_iso.s#L475) | 475 |
| — | [`mi_op_x_dec`](../../../src/c64/juego_final/motor_iso.s#L483) | 483 |
| — | [`mi_op_y_add`](../../../src/c64/juego_final/motor_iso.s#L492) | 492 |
| — | [`mi_op_p1_inc`](../../../src/c64/juego_final/motor_iso.s#L510) | 510 |
| — | [`mi_op_loop_p2`](../../../src/c64/juego_final/motor_iso.s#L532) | 532 |
| 1CB3h | [`mi_loop_skip`](../../../src/c64/juego_final/motor_iso.s#L551) | 551 |
| — | [`mi_op_push_pos`](../../../src/c64/juego_final/motor_iso.s#L582) | 582 |
| — | [`mi_op_next`](../../../src/c64/juego_final/motor_iso.s#L598) | 598 |
| — | [`mi_op_up`](../../../src/c64/juego_final/motor_iso.s#L617) | 617 |
| — | [`mi_op_set`](../../../src/c64/juego_final/motor_iso.s#L632) | 632 |
| — | [`mi_op_jump`](../../../src/c64/juego_final/motor_iso.s#L656) | 656 |
| — | [`mi_op_call_keep`](../../../src/c64/juego_final/motor_iso.s#L670) | 670 |
| — | [`mi_ops_lo`](../../../src/c64/juego_final/motor_iso.s#L728) | 728 |
| 1D0Ah | [`iso_tile_run`](../../../src/c64/juego_final/motor_iso.s#L743) | 743 |
| — | [`mi_tile_run`](../../../src/c64/juego_final/motor_iso.s#L759) | 759 |
| 1D74h | [`iso_expression`](../../../src/c64/juego_final/motor_iso.s#L815) | 815 |
| 1D90h | [`iso_fetch_word`](../../../src/c64/juego_final/motor_iso.s#L840) | 840 |
| 1E22h | [`iso_fetch_operand`](../../../src/c64/juego_final/motor_iso.s#L856) | 856 |
| 1E27h | [`iso_operand_value`](../../../src/c64/juego_final/motor_iso.s#L866) | 866 |
| — | [`mi_fetch`](../../../src/c64/juego_final/motor_iso.s#L879) | 879 |
| — | [`mi_operand`](../../../src/c64/juego_final/motor_iso.s#L887) | 887 |
| 1BC6h | [`iso_block_depth`](../../../src/c64/juego_final/motor_iso.s#L914) | 914 |
| 1F79h | [`iso_update_camera_room`](../../../src/c64/juego_final/motor_iso.s#L947) | 947 |
| — | [`mi_setup_regs`](../../../src/c64/juego_final/motor_iso.s#L1086) | 1086 |
| 2097h | [`iso_floor_base`](../../../src/c64/juego_final/motor_iso.s#L1100) | 1100 |
| 20A4h | [`iso_orient_relative`](../../../src/c64/juego_final/motor_iso.s#L1116) | 1116 |
| — | [`iso_rotate_cam1`](../../../src/c64/juego_final/motor_iso.s#L1125) | 1125 |
| 1E6Eh | [`vid_set_crtc`](../../../src/c64/juego_final/motor_iso.s#L1148) | 1148 |
