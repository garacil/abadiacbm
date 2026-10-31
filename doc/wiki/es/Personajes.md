<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Personajes.md: se edita la plantilla, no esta página. -->
# Los personajes y su movimiento

[Inicio](Inicio.md) · anterior: [Las salas y el motor isométrico](Motor-isometrico.md) · siguiente: [Los sprites y la pantalla](Sprites.md)

Todo el movimiento está en `src/c64/juego_final/personajes.s`: los registros de los personajes, los pasos y los giros,
la lectura de las alturas, las órdenes de movimiento de los monjes, la animación y la proyección a la pantalla.

## Los registros de personaje

Cada uno de los seis personajes tiene un registro de 15 bytes (`CHR_GUILLERMO` y los cinco siguientes, en el orden
Guillermo, Adso, Malaquías, el abad, el registro de Berengario y el de Severino):

| Desplazamiento | Significado |
|---|---|
| +0 | el contador de animación, 0-3 (con el bit 0 a 1: a mitad de un paso) |
| +1 | la orientación, 0-3 (0 = +x, 1 = −y, 2 = −x, 3 = +y) |
| +2, +3, +4 | x, y y la altura |
| +5 | banderas: bit 7 = el personaje ocupa una celda (en las escaleras) en vez de 2 × 2; bit 5 = girado de través en una pendiente; bit 4 = bajando |
| +6 | el estado de volteo de sus gráficos |
| +7, +8 | el desplazamiento de su sprite |
| +9 | el contador de bits de órdenes (bit 7 = sin órdenes) |
| +0A, +0B, +0C-0D | el byte de orden actual, su índice y la dirección del flujo de órdenes |
| +0E | la marca que el personaje deja en el búfer de alturas (10h o 20h) |

Una segunda tabla, `CHR_TABLE` (10 bytes por personaje), une cada uno con su sprite, su registro, su rutina de
comportamiento, la rutina que voltea sus gráficos y su tabla de animación.  En el Z80, `chr_load_params` copiaba esas
cinco palabras en los operandos de cinco instrucciones repartidas por el código; como esa lista de destinos es fija, en
el 6502 las guardo directamente en la página cero y en `$0208`.

## Un paso de un personaje

Cada fotograma, cada personaje pasa por `chr_update`: sale del búfer de alturas (para no estorbarse a sí mismo), piensa
o termina su paso, y vuelve a marcar el búfer de alturas:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L577-L607), líneas 577–607:

```asm
; 2472 chr_update: moves one character and updates its sprite.  HL = its chr_table entry: chr_load_params;
; IX = the sprite [2477], spr_save_old_rect; IY = the record [247E]; the mark leaves the height buffer; [3EED]
; (Malachi rising) is read and cleared; chr_think_or_step; the mark [IY+0E] goes back (JP 2444).
; Out: IY = the record, IX = what the last chr_mark_hbuf leaves.
.proc chr_update
        jsr     chr_load_params
        lda     D64_CHR_CUR_SPRITE
        sta     zix
        lda     D64_CHR_CUR_SPRITE+1
        sta     zix+1
        jsr     spr_save_old_rect
        lda     D64_CHR_CUR_DATA
        sta     ziy
        lda     D64_CHR_CUR_DATA+1
        sta     ziy+1
        lda     #0
        sta     zbc
        jsr     chr_mark_hbuf
        lda     D64_CHR_CUR_SPRITE      ; IX back (the Z80's PUSH IX / POP IX)
        sta     zix
        lda     D64_CHR_CUR_SPRITE+1
        sta     zix+1
        lda     #0
        ldx     D64_CHR_MALACHI_RISING  ; Z: not rising
        sta     D64_CHR_MALACHI_RISING
        jsr     chr_think_or_step
        ldy     #$0E
        lda     (ziy),y
        sta     zbc
        jmp     chr_mark_hbuf
.endproc
```

Un paso dura dos fotogramas (el medio paso del bit 0 del contador de animación); entre dos pasos se ejecuta la **rutina
de comportamiento** del personaje: para Guillermo, las teclas; para los demás, sus órdenes de movimiento.  Lo decide
`chr_think_or_step`: con un paso a medias lo termina, y si no, llama a la rutina de comportamiento por su dirección,
como el `JP (HL)` del Z80.  Cuando Malaquías muere se eleva: su altura sube una unidad cada pocos fotogramas (`ai_malaquias_rise`), y mientras tanto
solo se anima.

## Guillermo

El comportamiento de Guillermo hace tres cosas, en este orden:

* **La caída de la trampa del espejo**: si el estado de Guillermo no es 0, cae; el contador baja, el sprite desciende
  `CHR_GUILLERMO_FALL_DY` líneas cada fotograma y al final desaparece.
* **Nada** mientras la cámara sigue a otro personaje.
* **Las teclas**: izquierda o derecha recién pulsadas (una pulsación nueva, no mantenida) giran; arriba mantenida avanza,
  si las alturas lo permiten.

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L633-L696), líneas 633–696:

```asm
.proc chr_guillermo_behaviour
        lda     D64_CHR_GUILLERMO_STATE
        beq     normal
        sec
        sbc     #1
        bne     :+
        rts
:       sta     D64_CHR_GUILLERMO_STATE
        cmp     #$13
        bne     fall
        lda     D64_CHR_GUILLERMO_FALL_DY
        cmp     #2
        bne     fall
        ldy     #2
        lda     (ziy),y
        sec
        sbc     #1
        sta     (ziy),y
        jmp     chr_animate
fall:   cmp     #1
        beq     hide
        ldy     #2
        lda     (zix),y
        clc
        adc     D64_CHR_GUILLERMO_FALL_DY
        sta     (zix),y
        ldy     #0
        lda     (zix),y
        and     #$3F
        ora     #$80
        sta     (zix),y
        lda     #$FF
        sta     D64_CHR_MOVED
        rts
hide:   lda     #$FE
        ldy     #0
        sta     (zix),y
        rts
normal: lda     D64_GAME_CAMERA_OTHER
        bne     ret
        lda     #8
        jsr     sys_key_pressed
        beq     :+
        lda     #1
        sta     zbc
        jmp     chr_turn
:       lda     #1
        jsr     sys_key_pressed
        beq     :+
        lda     #$FF
        sta     zbc
        jmp     chr_turn
:       lda     #0
        jsr     sys_key_down
        beq     ret
        ldx     #<guillermo_self
        stx     zhl
        ldx     #>guillermo_self
        stx     zhl+1
        jsr     chr_probe_ahead
        jmp     chr_try_advance
ret:    rts
.endproc
guillermo_self: .byte   $00, $3E        ; the bytes at 23E2h (NOP; LD A,n)
```

El último detalle es una curiosidad del original que conservo: el Z80 dejaba en HL la dirección de la propia rutina
(23E2h), y `chr_try_advance`, cuando el suelo no es el que se enseña, leía de ahí sus valores por defecto, que resultan
ser los bytes del código (`00 3E`: un `NOP` y el comienzo de un `LD A,n`).  `guillermo_self` son esos dos bytes.

Girar es inmediato:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L834-L852), líneas 834–852:

```asm
; 2561 chr_turn: turns character IY by C (+1 or FF): [IY] = 0; a 1-cell character toggles bit 5 of [IY+5];
; [IY+1] = ([IY+1] + C) & 3; falls into chr_animate.
.proc chr_turn
        ldy     #0
        tya
        sta     (ziy),y
        ldy     #5
        lda     (ziy),y
        bpl     :+
        eor     #$20
        sta     (ziy),y
:       ldy     #1
        lda     (ziy),y
        clc
        adc     zbc
        and     #3
        sta     (ziy),y
        jmp     chr_animate
.endproc
```

Antes de avanzar, el juego lee una ventana de 4 × 4 alturas delante del personaje (`chr_probe_ahead`) del **búfer de
alturas** de la sala (24 × 24 celdas alrededor de la sala: la altura del suelo, o la marca de un personaje que está
allí).  Las dos celdas de delante deciden: suelo llano, una unidad hacia arriba, una hacia abajo, o bloqueado.  En las
escaleras un personaje ocupa una celda; en suelo llano, 2 × 2:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L779-L805), líneas 779–805:

```asm
; 250C chr_try_advance_2x2: A = ahead1: 1 climbs (height + 1, [IY+5] = 80h: 1-cell), FF descends (height - 1,
; [IY+5] = 90h), 0 is a level step (2549), anything else blocks.  After climbing or descending it steps once, or
; twice for the orientations 1 and 2; [2912] = FF; animates (2556).
.proc chr_try_advance_2x2
        tax
        bne     :+
        jmp     chr_step_level
:       ldy     #$80                    ; 1 climbs: [IY+5] = 80h
        cpx     #1
        beq     :+
        ldy     #$90                    ; FF descends: [IY+5] = 90h
        cpx     #$FF
        beq     :+
        rts
:       tya
        ldy     #5
        sta     (ziy),y
        dey
        txa                             ; the height + ahead1
        clc
        adc     (ziy),y
        sta     (ziy),y
        jsr     personajes_step_kept
        beq     personajes_moved
        jsr     chr_apply_step
        ; falls into personajes_moved
.endproc
```

El búfer de alturas se rellena al entrar en la sala (`chr_fill_height_buffer`): se vacía, se fija su origen en la sala
del personaje y se llena con los datos de alturas del piso que corresponde.

## Los demás: flujos de órdenes

Adso y los monjes no deciden sus pasos uno a uno.  Su mente (ver [La mente de los monjes](Monjes.md)) elige un destino,
el buscador de caminos ([Alturas y búsqueda de caminos](Caminos.md)) calcula una ruta, y la ruta se escribe como un
**flujo de bits** de órdenes en el búfer de órdenes del personaje.  En cada paso, `chr_ai_follow_commands` lee la orden
siguiente:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L1340-L1344), líneas 1340–1344:

```asm
; 280D chr_read_command: decodes one command of character IY's bit stream into C (C flag clear).  1-cell: '1b'
; -> b.  2x2: '1' -> 1.  Both: '01b' -> 2+b (a turn), '001b' -> 4+b, '0000' -> 0 for a 1-cell character, or the
; stream restarts ([IY+0B] = [IY+9] = 0) and is read again (2x2).  '0001' = the end: bit 7 of [IY+9] set and
; the C flag set (the Z80 POPs its return address and the step 278F pushed, returning from 278F; its only
; caller, 278F, does so on the flag).
```

| Bits | Orden |
|---|---|
| `1` (2 × 2), `1b` (una celda) | avanzar (una celda: b = 0 subir o llano, 1 bajar) |
| `01b` | girar (+1 o −1) |
| `001b` | subir o bajar cambiando de tamaño |
| `0000` | volver a empezar el flujo (2 × 2) |
| `0001` | el final: no hay más órdenes |

Antes de intentar el paso, `chr_ai_follow_commands` guarda los diez bytes de la posición del personaje (de +2 a +0B);
supone las diferencias de altura que corresponden a la orden (para cuando el personaje no está en el suelo que se ve),
prueba el paso como Guillermo, y si nadie lo ha movido (otro personaje estaba en medio) vuelve a poner esos diez
bytes:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L1393-L1404), líneas 1393–1404:

```asm
; 278F chr_ai_follow_commands: Adso and the monks.  Nothing when bit 7 of [IY+9] (no commands).  Saves the 10
; bytes [IY+2..0B] to 28B9, reads a command (the end of the stream returns from here): 3 turns +1, 2 turns -1;
; otherwise (A, C) = the height differences assumed off the floor shown (2x2: 1 -> (0,FF), 5 -> (FF,FF), others
; (1,FF); 1-cell: 0 -> (0,0) with bit 5 of [IY+5] else (1,2), 1 -> (FF,FE), 4 -> (1,1), others (FF,FF)),
; [2912] = 0, chr_probe_ahead and chr_try_advance with the step entry + 6; if [2912] is still 0 the 10 bytes are
; restored.  In: IY, IX.
.proc chr_ai_follow_commands
        ldy     #9
        lda     (ziy),y
        bpl     :+
        rts
:       jsr     chr_step_table
```

## Del mundo a la pantalla

`chr_project` convierte una posición en una posición de sprite: coordenadas locales respecto de la sala, giradas según
la orientación de la cámara, y después la proyección isométrica (la fila sale de `x + y − altura` y la columna de
`x − y`):

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L1056-L1064), líneas 1056–1064:

```asm
; 2632 chr_project: projects character (or object, door) IY onto the screen, sprite IX.  Local x = [IY+2] -
; [2636], y = [IY+3] - [2640], each < 28h; the floor of [IY+4] must be [264E]; h = the height over it.  The camera
; rotation [2656] turns (x, y) (HL); they go to [IX+12h,13h].  Visible when r = x+y-h-6 is in 8..39h (row 4(r+1))
; and the column 2(x-y)+28h in 0..4Fh: then the return address is dropped (it returns to its caller's caller) and
; the depth is max(0, x+y-10h).  Not visible: a plain return.  Test mode ([2684] = C9h, set by 0ABC): A = the
; depth, HL = row:column, C = x+y.  Normal mode: plus the per-orientation offset of the table [28D5] (+16 per
; camera-relative orientation, +2 per frame chosen from [IY], [IY+5]) and [IY+7] / [IY+8]: the sprite's x
; (bytes) and y (lines) in [IX+1,2] (and [IX+3,4] when the sprite was inactive), HL = them; C = the depth.
        .assert D64_CHR_ROOM_ORIGIN_Y = D64_CHR_ROOM_ORIGIN_X + 1, error, "chr_project: the origins contiguous"
```

La tabla de animación da, para la orientación relativa a la cámara y el contador, el gráfico, su ancho y su alto
(`chr_select_frame`).  Los monjes comparten una tabla de cuerpos, y la palabra del gráfico se convierte en la cara de
cada monje; los fotogramas con el bit 4 del índice usan su segunda cara:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L925-L929), líneas 925–929:

```asm
; 25B6 chr_select_frame: the 4-byte animation entry of character IY, sprite IX.  o = the camera-relative
; orientation, n = [IY]; the low nibble of [IX+0B] = 4o | n; index = 4 (((o+1) & 2) 2 | n).  A real table [25D9]:
; HL = table + index.  The monks ([25D9] = C0xxh, a tag: tested as C0h exactly, the C64's tables lie at CFxxh):
; the shared body table 2D30 + index, whose graphics word becomes the monk's face [2BE8 + xx] (the second face,
; +1Eh on the C64 for the CPC's +32h, on the frames with index bit 4).  Out: HL.
```

Dos de las cuatro orientaciones se dibujan con los mismos gráficos reflejados: cuando cambia la orientación de un
personaje respecto de la cámara, sus gráficos se voltean **en su sitio** (`spr_flip_guillermo`, `spr_flip_adso` y las
caras de los monjes), como hacía el CPC, sobre el formato de sprite del C64: dos píxeles en un byte, los nibbles
intercambiados a través de una tabla.  Las caras y la puerta están debajo de la E/S, así que se desconecta mientras
tanto:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L2248-L2254), líneas 2248–2254:

```asm
; 2F57 spr_flip_graphics_h: mirrors in place B lines (0 = 256) of a graphic HL in the C64 sprite format, C CPC
; bytes (= nibbles) wide: ceil(C/2) bytes a line, an odd width's last low nibble is padding.  Every line's
; nibbles are reversed, each through espejo_nibble (its two pixels swapped), the padding staying last; this is
; exactly the conversion of the CPC graphic flipped by the Z80 (the "sim" rule, c64/NOTAS_GRAFICOS.md).  The
; width is kept in [2FA3] as the Z80 does.  The faces and the door lie under the I/O: switched off meanwhile
; ($01 = $34; the caller's $01 comes back at the end).
; The Z80's registers at the exit (it returns with the banks exchanged) are not reproduced: no caller uses them.
```

## Todas las rutinas de los personajes

| Original | Rutina | Línea |
|---|---|---|
| 2226h | [`game_run_npc_behaviours`](../../../src/c64/juego_final/personajes.s#L93) | 93 |
| 2236h | [`spr_draw_or_darken`](../../../src/c64/juego_final/personajes.s#L102) | 102 |
| 223Dh | [`personajes_dark`](../../../src/c64/juego_final/personajes.s#L111) | 111 |
| 2265h | [`spr_place_light`](../../../src/c64/juego_final/personajes.s#L146) | 146 |
| 22D4h | [`vid_clear_play_area`](../../../src/c64/juego_final/personajes.s#L204) | 204 |
| 22D8h | [`chr_step_table`](../../../src/c64/juego_final/personajes.s#L213) | 213 |
| 22E7h | [`util_add_bx_8al`](../../../src/c64/juego_final/personajes.s#L229) | 229 |
| 22F0h | [`chr_to_hbuf_coords`](../../../src/c64/juego_final/personajes.s#L245) | 245 |
| 2309h | [`chr_probe_ahead_flat`](../../../src/c64/juego_final/personajes.s#L271) | 271 |
| 230Dh | [`chr_probe_ahead`](../../../src/c64/juego_final/personajes.s#L280) | 280 |
| 2472h | [`chr_update`](../../../src/c64/juego_final/personajes.s#L581) | 581 |
| 249Ah | [`chr_think_or_step`](../../../src/c64/juego_final/personajes.s#L611) | 611 |
| 23E2h | [`chr_guillermo_behaviour`](../../../src/c64/juego_final/personajes.s#L633) | 633 |
| 24A9h | [`chr_try_advance`](../../../src/c64/juego_final/personajes.s#L704) | 704 |
| — | [`personajes_step_kept`](../../../src/c64/juego_final/personajes.s#L756) | 756 |
| 2503h | [`chr_orientation_parity`](../../../src/c64/juego_final/personajes.s#L770) | 770 |
| 250Ch | [`chr_try_advance_2x2`](../../../src/c64/juego_final/personajes.s#L782) | 782 |
| — | [`personajes_moved`](../../../src/c64/juego_final/personajes.s#L808) | 808 |
| 2539h | [`chr_apply_step`](../../../src/c64/juego_final/personajes.s#L815) | 815 |
| 2561h | [`chr_turn`](../../../src/c64/juego_final/personajes.s#L836) | 836 |
| 2549h | [`chr_step_level`](../../../src/c64/juego_final/personajes.s#L856) | 856 |
| 2553h | [`chr_step_and_animate`](../../../src/c64/juego_final/personajes.s#L859) | 859 |
| 2556h | [`chr_advance_anim`](../../../src/c64/juego_final/personajes.s#L865) | 865 |
| 257Ch | [`chr_animate`](../../../src/c64/juego_final/personajes.s#L877) | 877 |
| 2589h | [`chr_show_frame`](../../../src/c64/juego_final/personajes.s#L897) | 897 |
| 25B6h | [`chr_select_frame`](../../../src/c64/juego_final/personajes.s#L930) | 930 |
| 261Eh | [`chr_project_or_hide`](../../../src/c64/juego_final/personajes.s#L1028) | 1028 |
| 2623h | [`spr_mark_leaving`](../../../src/c64/juego_final/personajes.s#L1039) | 1039 |
| — | [`personajes_store_hl`](../../../src/c64/juego_final/personajes.s#L1230) | 1230 |
| 2765h | [`chr_command_bit`](../../../src/c64/juego_final/personajes.s#L1304) | 1304 |
| 280Dh | [`personajes_read_command`](../../../src/c64/juego_final/personajes.s#L1345) | 1345 |
| 278Fh | [`chr_ai_follow_commands`](../../../src/c64/juego_final/personajes.s#L1399) | 1399 |
| — | [`personajes_copy10`](../../../src/c64/juego_final/personajes.s#L1468) | 1468 |
| 28ADh | [`chr_backup_args`](../../../src/c64/juego_final/personajes.s#L1479) | 1479 |
| 2855h | [`iso_select_room`](../../../src/c64/juego_final/personajes.s#L1499) | 1499 |
| 2D50h | [`sys_read_keyboard`](../../../src/c64/juego_final/personajes.s#L1659) | 1659 |
| 2E98h | [`sys_key_bit`](../../../src/c64/juego_final/personajes.s#L1684) | 1684 |
| 2E42h | [`sys_test_key`](../../../src/c64/juego_final/personajes.s#L1713) | 1713 |
| — | [`kb_mira`](../../../src/c64/juego_final/personajes.s#L1898) | 1898 |
| — | [`kb_mira`](../../../src/c64/juego_final/personajes.s#L1958) | 1958 |
| 2DFCh | [`game_check_qr_mirror`](../../../src/c64/juego_final/personajes.s#L2015) | 2015 |
| 2D99h | [`game_input_and_mirror`](../../../src/c64/juego_final/personajes.s#L2050) | 2050 |
| 2EBBh | [`obj_init_mirror`](../../../src/c64/juego_final/personajes.s#L2104) | 2104 |
| 2EC4h | [`obj_close_mirror`](../../../src/c64/juego_final/personajes.s#L2115) | 2115 |
| — | [`personajes_mirror_entry`](../../../src/c64/juego_final/personajes.s#L2139) | 2139 |
| 2EE7h | [`spr_flip_adso`](../../../src/c64/juego_final/personajes.s#L2155) | 2155 |
| — | [`personajes_flip2`](../../../src/c64/juego_final/personajes.s#L2172) | 2172 |
| 2F00h | [`spr_flip_malachi`](../../../src/c64/juego_final/personajes.s#L2210) | 2210 |
| 2F57h | [`spr_flip_graphics_h`](../../../src/c64/juego_final/personajes.s#L2255) | 2255 |
