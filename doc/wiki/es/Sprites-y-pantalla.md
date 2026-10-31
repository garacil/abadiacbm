<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Sprites-y-pantalla.md: se edita la plantilla, no esta página. -->
# Los sprites y la pantalla

[Inicio](Inicio.md) · anterior: [Los personajes y su movimiento](Personajes.md) · siguiente: [Alturas y búsqueda de caminos](Caminos.md)

El CPC no tiene sprites por hardware y el juego tampoco usa los del C64 (salvo para las cabezas del C128 y del P500):
todo lo que se mueve (los personajes, las puertas, los objetos, la luz de la lámpara) es un **sprite** por software,
dibujado en el bitmap junto con las baldosas que tiene delante.  Es el trabajo más caro de un fotograma, y solo se hace
donde algo ha cambiado.  Está en `src/c64/juego_final/logica_a_spr.s`.

## La tabla de sprites

`SPR_TABLE` tiene 23 registros de 20 bytes (y un `FF` al final): primero los seis personajes, luego las puertas, los
objetos y la luz.

| Desplazamiento | Significado |
|---|---|
| +0 | `FE` = inactivo; bit 7 = hay que redibujarlo; bit 6 = compuesto en esta pasada; bits 0-5 = la profundidad (el orden de dibujo) |
| +1, +2 | x (en bytes del CPC, 4 píxeles cada uno) e y (en líneas) |
| +3, +4 | la x y la y anteriores |
| +5, +6 | el ancho y el alto (bit 7 del ancho: borrar la zona antigua) |
| +7, +8 | el gráfico |
| +9, +0A | el ancho y el alto anteriores |
| +0B | la animación (orientación × 4 + fotograma) |
| +0C-0F | el rectángulo que se está componiendo |
| +10, +11 | dónde está el rectángulo en el búfer de sprites |
| +12, +13 | la posición local, para la prueba de profundidad contra las baldosas |

## Componer por rectángulos

`spr_draw_all` hace todo el trabajo, en este orden:

1. hace la lista de los sprites activos y, si ninguno tiene el bit 7 (nada ha cambiado), termina;
2. ordena la lista por profundidad con el método de la burbuja (`[sprite] & 3Fh`, de menor a mayor);
3. a cada sprite que ha cambiado le da un **rectángulo** que cubre su sitio viejo y el nuevo, alineado a las baldosas
   (4 bytes de ancho, 8 líneas de alto), y le reserva un trozo del búfer de sprites, que vacía;
4. compone cada rectángulo: las baldosas de detrás, cada sprite que se solapa con él en orden de profundidad, y las
   baldosas de delante;
5. copia a la pantalla cada rectángulo compuesto de una vez, así que nada parpadea; si el búfer de sprites se llenó,
   vuelve a empezar con los sprites que no cupieron.

[`src/c64/juego_final/logica_a_spr.s`](../../../src/c64/juego_final/logica_a_spr.s#L944-L956), líneas 944–956:

```asm
; 447D spr_draw_all: composes and draws every sprite that changed.  The active sprites (FE skipped, FF ends)
; listed (the Z80 pushed them on its stack: the last one first, and counted those with bit 7); none with bit 7: EI
; and out (looked for first: the list, which is the C64's own memory, is not needed then).
; Bubble sort by depth ([spr] & 3Fh, ascending from the top).  Then for each sprite of the list: bit 6 cleared;
; bit 7 set: the union of its new and old rectangles aligned to tiles (spr_rect_pos/size, [spr+0Ch..0Fh]),
; spr_tile_pos := 8594h + 12 y + 1.5 x (the tile buffer), the rectangle allocated in the sprite buffer (full past
; 877Eh: step 5) and cleared, bit 6 set, spr_depth_upper := 0; every sprite of the list (vanishing ones skipped)
; clipped to it (3786, x then y), the tiles between the previous depth and its depth [spr+12h] copied, the sprite
; merged; at the end the tiles in front of everything (BC = FCFCh, the hook 491B = NOP).  Step 5: every composed
; sprite blitted, its flags cleared, a vanishing one becomes FE; then the whole routine again (the sprites that did
; not fit).  Out: IX = the FFh of the sprite table (step 5), IY = the last sprite overlaid (both kept when nothing
; changed), HL = the FFh of the sprite table, DE = 14h, A = C = 0; EI.
.proc spr_draw_all
```

El alineamiento lo hacen dos rutinas: `spr_rect_tile_align` lleva el principio del rectángulo al principio de su
baldosa y agranda el tamaño a baldosas enteras, y `spr_rect_union_old` lo agranda para cubrir también el rectángulo
viejo, con la aritmética de 8 bits del original:

[`src/c64/juego_final/logica_a_spr.s`](../../../src/c64/juego_final/logica_a_spr.s#L140-L141), líneas 140–141:

```asm
; 48FC spr_rect_tile_align: the tile the rectangle starts in (x & FCh, y & F8h) and its size grown to whole tiles:
; w = (w + (x & 3) + 3) & FCh, h = (h + (y & 7) + 7) & F8h.  In: HL = pos (L = x), DE = size (E = w).
```

En el C64 guardo el búfer con la misma disposición que el bitmap (celda a celda, 8 bytes por celda), así que una
baldosa son 16 bytes seguidos y una fila del rectángulo es una tira de bytes seguidos del bitmap: la copia mueve filas
enteras.

[`src/c64/juego_final/logica_a_spr.s`](../../../src/c64/juego_final/logica_a_spr.s#L19-L32), líneas 19–32:

```asm
; The C64 sprite buffer.  Every changed sprite gets a rectangle aligned to the tiles (x multiple of 4 CPC bytes,
; y of 8 lines, w and h likewise), allocated as on the CPC (spr_buf_free advances by w * h, so the variables keep
; the CPC's values and the same sprites fit in a pass), but held in the C64 format, cell-major: the rectangle is
; h / 8 rows of w / 2 cells, a cell 8 bytes (its 8 lines), a row 4w bytes; the byte of rectangle line y, nibble x
; (CPC byte x) is at buffer + (y >> 3) 4w + (x >> 1) 8 + (y & 7), the high nibble for an even x.  A tile is then 16
; consecutive bytes (its two cell columns, as the tile graphics), and a row of the rectangle is consecutive bitmap
; bytes, so the blit copies whole rows.  The rest of the CPC's w * h bytes is unused.  The sprite routines leave
; the sprite buffer out of the shadow comparison (resultados.tsv).
;
; The graphics: tiles $D000 + 16n (column-major, merged with the tables $C400-$C7FF), sprites row-major,
; ceil(w / 2) bytes a line (the odd width's padding nibble 5 is transparent), merged with the tables and_spr /
; or_spr (pen 0 transparent); the robes drawn mirrored (bit 14 of their pointer) read backwards through
; espejo_byte; a sprite at an odd CPC x is half a byte off: the nibble swap table (c64/NOTAS_GRAFICOS.md).  The
; tiles, faces, door, objects and light lie under the I/O: the drawing routines switch it off ($01 = $34).
```

## Mezclar un sprite

`la_mezcla` mezcla un sprite en el rectángulo, línea a línea: la pluma 0 es transparente, así que cada byte se combina
con dos tablas (`AND` del fondo con una máscara, `OR` de los píxeles del sprite).  Un sprite en una x impar del CPC
está medio byte desplazado: sus nibbles pasan por una tabla de intercambio.  Los monjes se dibujan en dos partes: la
cara (cada monje la suya) y el hábito (compartido, que se lee hacia atrás cuando está reflejado).

## Las baldosas de delante

Una baldosa tapa a un personaje cuando su profundidad (guardada en el búfer de baldosas al construir la sala, ver
[Las salas y el motor isométrico](Motor-isometrico.md)) está delante de la posición del personaje: `la_capas` copia,
para cada sprite, las baldosas cuya profundidad está entre la del sprite anterior y la de este, y al final las
baldosas que están delante de todo.  Así un personaje que pasa por detrás de una columna desaparece tras ella píxel a
píxel.  La prueba es la del original: la baldosa se dibuja si su profundidad x o y no es menor que el límite de abajo y
las dos son menores que el límite de arriba; una baldosa ya dibujada lleva el bit 7 para no dibujarla dos veces:

[`src/c64/juego_final/logica_a_spr.s`](../../../src/c64/juego_final/logica_a_spr.s#L464-L470), líneas 464–470:

```asm
; 4925 spr_draw_tiles_in_depth_range: the tiles of the rectangle (tile buffer from spr_tile_pos, size
; spr_rect_size) whose depth lies between the previous limit and BC + 0101h: spr_depth_lower := spr_depth_upper,
; spr_depth_upper := (C + 1, B + 1).  The destination starts at spr_cur_buffer, +16 a tile, +4w a row of tiles.
; Per cell spr_tile_test_jump := 497F; per layer (entry bytes 0-2, 3-5: depth x, depth y, tile): tile 0 skipped;
; drawn (bit 7): drawn again only when spr_tile_test_jump = 49AA; else the depth test ((x >= lower.x or y >=
; lower.y) and y < upper.y and x < upper.x): 49AA, bit 7 set when the entry lies in the tile buffer, drawn; after
; each layer the hook (491B, the final pass: the bit cleared again).  Row and cell counts 0 mean 256.  (The C64's
```

## La copia a la pantalla

[`src/c64/juego_final/logica_a_spr.s`](../../../src/c64/juego_final/logica_a_spr.s#L634-L639), líneas 634–639:

```asm
; 47E7 spr_blit_to_screen: the composed rectangle of the sprite IX (buffer [IX+10h], x [IX+0Ch] bytes, y [IX+0Dh]
; lines, w [IX+0Eh], h [IX+0Fh]) copied to the screen, clipped to the play area (sprite space: lines 28h-C7h, bytes
; 8-47h): spr_blit_skip, spr_blit_width (low byte), spr_blit_lines as the Z80 computes them; the copy goes by
; rows of cells (the cuts are whole cells: the rectangles are tile-aligned).  A rectangle cut on both sides (wider
; than the play area) is copied right here, where the CPC skipped only the right cut after each line.
.proc spr_blit_to_screen
```

En el C128 la copia espera al haz de barrido (`la_haz`): nunca copia las líneas que el haz va a enseñar enseguida, así
que los sprites aparecen enteros; allí las cabezas se dibujan además en alta resolución con los sprites del propio
VIC-II (ver [El Commodore 128](Commodore-128.md)).

## Dibujar una sala entera

Cuando se entra en una sala iluminada, el búfer de baldosas se dibuja entero en espiral, desde el centro hacia fuera:
8 vueltas de tramos abajo, a la derecha, arriba y a la izquierda, de 4, 1, 5 y 2 baldosas, cada vuelta dos más largos;
de cada entrada, primero la baldosa de fondo y después la de delante, si no son 0:

[`src/c64/juego_final/logica_a_spr.s`](../../../src/c64/juego_final/logica_a_spr.s#L335-L338), líneas 335–338:

```asm
; 4A5F iso_draw_room_spiral: the whole tile buffer drawn to the screen from the centre outwards: from the entry
; 8AAAh and the screen at C21Ch (bitmap row 8, cells 18-19), 8 rounds of runs down, right, up, left
; (iso_spiral_runs: lengths 4, 1, 5, 2, each 2 longer the next round; tile-buffer steps +60h, +6, -60h, -6;
; bitmap steps +320, +16, -320, -16); each entry's background tile [+2], then its foreground tile [+5], when not 0.
```

## Las salas a oscuras y la lámpara

En las salas a oscuras de la biblioteca no se dibuja nada salvo la luz de la lámpara, que sigue a Adso cuando él la
lleva:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L101-L110), líneas 101–110:

```asm
; 2236 spr_draw_or_darken: lit room: the sprites are drawn (JP 447D); dark room: 223D.
.proc spr_draw_or_darken
        lda     D64_ISO_ROOM_DARK
        bne     personajes_dark
        jmp     spr_draw_all
.endproc

; 223D (inside 2236, also reached from 2274): dark room.  Clears the redraw bit 7 of every active sprite record
; (FE inactive, FF end); then, if Adso's sprite is active and he carries the lamp (bit 7 of [2944]), the light
; is shown (BCh) and the sprites drawn (JP 447D).
```

La luz es un sprite cuyo gráfico es una máscara: un dibujo de filas de 16 bits que deja visible la zona alrededor de
Adso y oscuro el resto de su rectángulo.  La versión del C64 la aplica de dos en dos nibbles sobre el búfer ordenado por
celdas:

[`src/c64/juego_final/logica_a_spr.s`](../../../src/c64/juego_final/logica_a_spr.s#L1734-L1739), líneas 1734–1739:

```asm
; The same CPC light mask, applied two nibbles at a time in the cell-major C64 buffer. spr_place_light and
; tile alignment guarantee even x, fill counts 159/239, dx 0..3 and dx_rest = 4-dx. Each 16-bit pattern row,
; with its dark margins, is expanded to ten byte masks only once, then reused for its four lines. The cursor
; retains the original linear wrapping at the rectangle's width (not at the light's width of 20 nibbles).
; la_q is the destination pointer, la_s the logical x/y; la_f4w was set by la_capas. No multiply per pixel.
.proc la_luz
```

## Todas las rutinas de los sprites

| Original | Rutina | Línea |
|---|---|---|
| — | [`la_sw`](../../../src/c64/juego_final/logica_a_spr.s#L68) | 68 |
| — | [`la_mascara`](../../../src/c64/juego_final/logica_a_spr.s#L78) | 78 |
| — | [`la_fila_lo`](../../../src/c64/juego_final/logica_a_spr.s#L83) | 83 |
| — | [`la_mul`](../../../src/c64/juego_final/logica_a_spr.s#L93) | 93 |
| 48EBh | [`util_mul_al_bx`](../../../src/c64/juego_final/logica_a_spr.s#L116) | 116 |
| 48FCh | [`spr_rect_tile_align`](../../../src/c64/juego_final/logica_a_spr.s#L143) | 143 |
| 4886h | [`spr_rect_union_old`](../../../src/c64/juego_final/logica_a_spr.s#L176) | 176 |
| — | [`la_baldosa_io`](../../../src/c64/juego_final/logica_a_spr.s#L313) | 313 |
| 4A5Fh | [`iso_draw_room_spiral`](../../../src/c64/juego_final/logica_a_spr.s#L340) | 340 |
| — | [`la_capas`](../../../src/c64/juego_final/logica_a_spr.s#L489) | 489 |
| — | [`capa`](../../../src/c64/juego_final/logica_a_spr.s#L587) | 587 |
| 47E7h | [`spr_blit_to_screen`](../../../src/c64/juego_final/logica_a_spr.s#L639) | 639 |
| — | [`la_haz`](../../../src/c64/juego_final/logica_a_spr.s#L840) | 840 |
| — | [`haz_espera`](../../../src/c64/juego_final/logica_a_spr.s#L890) | 890 |
| 447Dh | [`spr_draw_all`](../../../src/c64/juego_final/logica_a_spr.s#L956) | 956 |
| — | [`la_mezcla`](../../../src/c64/juego_final/logica_a_spr.s#L1346) | 1346 |
| — | [`la_habito_l`](../../../src/c64/juego_final/logica_a_spr.s#L1509) | 1509 |
| — | [`la_fuente`](../../../src/c64/juego_final/logica_a_spr.s#L1547) | 1547 |
| — | [`la_tramo`](../../../src/c64/juego_final/logica_a_spr.s#L1577) | 1577 |
| — | [`la_luz`](../../../src/c64/juego_final/logica_a_spr.s#L1739) | 1739 |
| — | [`banda`](../../../src/c64/juego_final/logica_a_spr.s#L1851) | 1851 |
| — | [`aplica`](../../../src/c64/juego_final/logica_a_spr.s#L1861) | 1861 |
