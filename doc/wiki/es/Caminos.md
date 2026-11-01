<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Caminos.md: se edita la plantilla, no esta página. -->
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

# Alturas y búsqueda de caminos

[Inicio](Inicio.md) · anterior: [Los sprites y la pantalla](Sprites-y-pantalla.md) · siguiente: [La mente de los monjes](Monjes.md)

Los monjes andan solos por toda la abadía: suben y bajan escaleras, cruzan puertas, van de una sala a otra y de un
piso a otro.  Lo hacen con dos búsquedas en anchura (una dentro de una sala y otra entre salas) y un escritor que
convierte el camino encontrado en órdenes de movimiento.  Es el trabajo más pesado del juego: casi la mitad de los
ciclos del C64 en las sesiones grabadas.  Está en `src/c64/juego_final/camino.s` y `logica_a_cam.s`.

## El búfer de alturas

Cada sala tiene un **búfer de alturas**: 24 × 24 celdas (las 16 × 16 posiciones de la sala y un borde de 4), cada una
con la altura del suelo en ese punto (el nibble bajo) o la marca de un personaje que está encima (10h, 20h).  Se
rellena cuando cambia la sala, a partir de la lista de registros de alturas del piso (zonas llanas, rampas, escalones):

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L1525-L1527), líneas 1525–1527:

```asm
; 2873 chr_fill_height_buffer: clears the 24x24 height buffer [28DB] (240h bytes), sets the window origin from
; the room of character IY (07FF iso_grid_set_origin, which returns the floor base 0 / 0Bh / 16h), [3454] = the
; floor's height data and fills the buffer (JP 3456 chr_hbuf_fill_room).
```

Las sondas de los personajes lo leen para decidir cada paso (ver [Los personajes y su movimiento](Personajes.md)); las
búsquedas usan un segundo búfer del mismo tipo, construido alrededor del personaje que busca un camino, para que un
monje que está en otra sala pueda planear sin estropear la sala de la pantalla.  Lo construye `chr_path_build_grid`:
rellena el búfer con la sala del monje y, si Guillermo (o la sala de la cámara) está a una sala de distancia como mucho
y en el mismo piso, marca a los demás personajes como obstáculos (10h), da altura 0Fh a las hojas de las puertas
abiertas y quita la marca del propio monje:

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L1328-L1332), líneas 1328–1332:

```asm
; 082F chr_path_build_grid: chr_hbuf_ptr [28DB] = 8174h (chr_path_grid); chr_fill_height_buffer for chr;
; then, if Guillermo, or else the camera room (28C6-28C8), is within one room of chr in x and y
; (chr_room_distance_near) and on its floor: chr_grid_owner [08A0] = chr, the records of 5 chr_table
; entries from 270Dh (6 from 2703h when both distances are 1) but chr get the mark 10h (chr_mark_hbuf), the
; leaves of the open doors (bit 6 of [door+1]) get height 0Fh (obj_door_mark_cells) and chr's cells are
```

## Los conductores de los monjes

Cada fotograma, `game_run_npc_behaviours` llama al *conductor* de cada monje: Malaquías, el abad, Berengario y Severino
comparten el mismo código (el byte 2Ch, un `BIT abs`, salta el `LDX` siguiente para elegir el monje sin saltos), y Adso
tiene el suyo:

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L70-L70), líneas 70–70:

```asm
; 036D ai_update_malachi, 038E ai_update_abbot, 04A0 ai_update_berengar, 04C1 ai_update_severin: one
```

El conductor ejecuta la mente del monje (ver [La mente de los monjes](Monjes.md)), que deja un destino, y termina en la
cola común 03ACh (`camino_plan_route`):

* si el monje ya tiene un movimiento planeado, solo comprueba que el último intento no falló; si falló, descarta las
  órdenes (`chr_cmd_discard` escribe la orden 10h, «piensa otra vez», al principio del búfer) y en el siguiente
  fotograma se vuelve a planear;
* si la mente ha dicho que no hay que moverse (`AI_NO_ROUTE`), no hace nada;
* si no, busca el camino al destino: un lugar de la tabla de lugares del monje, o uno de cuatro destinos especiales
  (FFh Guillermo, FEh el abad, FDh el libro, FCh el pergamino), cuyas cuatro casillas vecinas son los candidatos; si
  `chr_path_find` contesta que ya está allí, el destino se da por alcanzado.

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L145-L149), líneas 145–149:

```asm
; 03AC (ai_plan_route, the shared tail of the drivers): a move already planned (bit 7 of [chr+9] clear) ->
; ai_check_planned_move; ai_no_route set -> nothing.  Destination d = [places-1]: FF/FE/FD/FC = Guillermo /
; the abbot / the book / the parchment, whose four neighbours are the candidates (slot 0201h); else the
; place p = places + 3d (8 bit) is copied to 0203h (FF after it) and its neighbours follow (slot 0204h).
; chr_path_alt_ptr [0213] = 0203h; a candidate -> chr_path_find; result FD (already there) -> [places-3] =
```

## Elegir el tipo de búsqueda

`chr_path_find` es la entrada: llevar a un personaje hacia una posición.  Otro piso: hacia las escaleras que suben o
bajan; otra sala del mismo piso: por el grafo de salas; la misma sala: una búsqueda en el búfer de alturas.  Cuando el
personaje ya está en la casilla de destino, `chr_path_face_target` solo lo gira hacia la orientación pedida:

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L662-L671), líneas 662–671:

```asm
; 05FA chr_path_find: route chr towards the target position (x, y, orient<<6 | z).  chr_path_result [2907]
; = FE; nothing while Guillermo is in mid-step ([0600] odd) or when a route was found in this iteration
; ([28FA]).  Else the floor test of the room search [440D] = BIT 6,(HL), [2907] = 0, chr_path_room_links_ptr
; [3F73] = the room links of the character's floor.  Other floor: stairs in the character's room in the
; wanted direction (bit 10h up / 20h down) -> every grid cell of height [0692] (0Dh / 01h) becomes a target
; (076D); else the room graph (4399, BIT 4 / BIT 5,(HL)) gives the nearest room with stairs (DE) -> 0734.
; Same floor: another room -> chr_path_via_rooms; the same cell -> [2907] = FD and chr_path_face_target;
; another cell -> the grid towards it (chr_path_search_to_dest).  In: IY = chr, IX = target.  Out: CF = a
; route was found (or chr_path_face_target's carry).
.proc chr_path_find
```

## La búsqueda dentro de una sala

La búsqueda es una expansión en anchura sobre el búfer de alturas a partir de la celda del personaje: cada posición de
la cola prueba sus cuatro vecinas, que tienen que poder pisarse desde ella (la misma altura o una unidad más o menos,
para un personaje de 2 × 2 celdas), y las marca como visitadas (bit 7), hasta que llega a una celda marcada como
destino (bit 6).  Primero se marca como visitado el borde de la sala, para que la búsqueda no se salga:

[`src/c64/juego_final/logica_a_cam.s`](../../../src/c64/juego_final/logica_a_cam.s#L129-L169), líneas 129–169:

```asm
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
```

El Z80 usaba su propia **pila** como cola de la búsqueda: metía las posiciones y recorría el puntero de pila sobre
ellas.  La pila del 6502 solo tiene 256 bytes, así que en la traducción la cola está en memoria, en las mismas
direcciones, creciendo hacia abajo como la del Z80, y escribo en ella las mismas palabras que dejaban allí los `CALL` y
los `PUSH` del Z80, para que la memoria siga siendo igual a la del original byte a byte (la certificación la compara).

## Entre salas y entre pisos

El mapa del piso (un byte por sala) funciona como una rejilla más pequeña: la misma búsqueda recorre ese mapa para
encontrar la sucesión de salas hacia la sala de destino, y las puertas son aristas que los permisos de las puertas
abren o cierran.  Después el personaje busca dentro de su sala un camino hasta la franja de celdas que lleva a la sala
siguiente; esas franjas las marcan cuatro rutinas, una por lado (la fila 3, la columna 20, la columna 3 o la fila 20):

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L1485-L1486), líneas 1485–1486:

```asm
; 090A chr_path_mark_exit_up, 091C _right, 0924 _left, 0929 _down (called through [076B]): bit 6 in 16
; cells of [28DB] + offset, step 1 or 24 (the exit band: row 3, column 20, column 3, row 20).  Its caller
```

Para cambiar de piso, todas las celdas que tienen la altura de la escalera pasan a ser destino.

## Del camino a las órdenes

La búsqueda deja en su cola la celda que llegó al destino.  `chr_cmd_write_path` recorre la cola hacia atrás para
reconstruir el camino, simula el paseo del personaje por él y escribe las órdenes (giros y pasos) en su búfer de
órdenes, como el flujo de bits que el personaje leerá paso a paso:

[`src/c64/juego_final/logica_a_cam.s`](../../../src/c64/juego_final/logica_a_cam.s#L1506-L1513), líneas 1506–1513:

```asm
; 41C9 chr_cmd_write_path: the default generator: rebuilds the path the room search found and writes its
; commands.  DI, sys_ticks := FFh; from chr_path_solution (the queue word that reached the target) the queue is
; read towards older entries and 3-byte records (x, y, orientation) are written at the sprite buffer after an
; FFh: the target with chr_path_orientation XOR 2, then for each earlier level the first queued cell next to the
; current one along one axis (chr_path_dy_tmp, chr_path_candidate), until chr_path_origin; EI.  Then from the last
; record back to the FFh: a turn (a 1-cell character turning to the other axis toggles +5 bit 5),
; chr_cmd_write_turn, chr_probe_ahead and chr_cmd_write_step; records whose position the simulated character
; already passed are skipped.  In: IY.  Out: IX = the FFh record, A = FFh.  The DI ... EI are the checked build's
```

Los bits se añaden de uno en uno con `chr_cmd_write_bits`, el bit más alto primero: cada ocho bits el byte completo
pasa al búfer:

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L1650-L1654), líneas 1650–1654:

```asm
; 0959 chr_cmd_write_bits: appends the B most significant bits of HL (B = 0: 256) to chr's command
; stream, MSB first: when the bit counter [chr+9] is 8, the byte [chr+0Ah] goes to [chr+0Ch] + [chr+0Bh]
; (DE), the index [chr+0Bh] + 1 and the counter 0; then HL << 1 and its bit 15 rotated into [chr+0Ah]
; (RL), counter + 1.  In: IY = chr, HL, B.  Out: HL, B = 0, A as the last pass leaves it (the counter
; read, or the byte stored), CF = bit 7 of [chr+0Ah] before the last RL, DE = the last byte stored (if
```

## Adso

Adso no planea cuando sigue a Guillermo: su conductor mide la longitud del camino entre los dos y da un paso cuando
están bastante separados (4 celdas si Adso ocupa una sola o no comparte ninguna coordenada con Guillermo; si no, 3).
Cuando Guillermo se le echa encima, Adso se aparta, y el jugador puede empujarlo con la tecla *abajo*
(`chr_adso_step_aside`, `chr_adso_step_guillermo_dir`).  Si un movimiento planeado falla, lo cuenta hasta 10 veces
antes de descartarlo:

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L366-L375), líneas 366–375:

```asm
; 04EB ai_update_adso: driver of Adso (X = 4 in camino_drive).  A destination ([3860] != FF) -> 03AC like a
; monk.  Following Guillermo: nothing while the camera follows another character ([37DC] >= 2); a planned
; move that failed is counted in [28FB] up to 10, then discarded; no plan: sys_key_down(17h),
; util_return_zero (RET NZ); [2907] = 0; Adso off the height buffer -> chr_path_find(Adso, Guillermo's
; position) and, when found, the driver again; key 0 down and a cell ahead of Guillermo (2917, 2918, 291B,
; 291C bit 5) holds Adso -> JP 410D; key 2 -> JP 40EB (both run the driver again when he moved); else a grid
; search from Guillermo to Adso gives the path length [3F82]; a long enough path (4 when Adso uses one cell
; or shares no coordinate with Guillermo, else 3) writes one step in orientation [3F81] (41A8) and the
; driver runs again (JP 04EB: a loop).
.ifdef VELOZ
```

## La memoria del C128

Sin pulsar teclas, el original repite cada fotograma algunas búsquedas que fallan igual (Severino desde el fotograma 674
del principio, por ejemplo: 1328 llamadas idénticas de 91 152 ciclos cada una).  En el trabajo de velocidad del C128
guardo la última búsqueda de sala a sala que falló (cada byte que lee, como clave; cada byte que escribe, como
resultado) y la repito cuando vuelve la misma llamada: como el 6502 es determinista, las mismas entradas dan las mismas
salidas, y la certificación contra el PC no muestra ninguna diferencia.

[`src/c64/juego_final/camino_memo.s`](../../../src/c64/juego_final/camino_memo.s#L16-L23), líneas 16–23:

```asm
; abadia64ks, 6502 code of the game: a memo of the whole route search between rooms (M4, measured and
; verified in the speed work's round 5; M1 moved up to camino_room_to_room's entry).  camino_room_to_room (0734)
; searches the floor's room graph (chr_path_floor_to_screen, 8 700 cycles), clears its marks
; (chr_path_clear_room_marks, 4 070) and, when it found the next room, builds the character's grid, marks the exit
; band and searches it (~77 000 cycles when that fails).  The Z80 repeats that failing call every frame while
; nothing changes (Severin from frame 674 of the no-keys run); this memo keeps the last failing one: its inputs (the
; key) and the compared bytes it left (the outputs).  A later call whose key equals the stored one replays the
; outputs and returns as the call returns (C = 0): the 6502 being deterministic, a call that reads the same bytes
```

## Todas las rutinas de los caminos

| Original | Rutina | Línea |
|---|---|---|
| 036Dh | [`ai_update_malachi`](../../../src/c64/juego_final/camino.s#L72) | 72 |
| — | [`camino_drive`](../../../src/c64/juego_final/camino.s#L90) | 90 |
| 03ACh | [`camino_plan_route`](../../../src/c64/juego_final/camino.s#L151) | 151 |
| 042Dh | [`chr_path_add_targets_around`](../../../src/c64/juego_final/camino.s#L244) | 244 |
| 0442h | [`chr_path_add_target_beside`](../../../src/c64/juego_final/camino.s#L271) | 271 |
| 04E2h | [`ai_check_planned_move`](../../../src/c64/juego_final/camino.s#L629) | 629 |
| 052Eh | [`chr_cmd_discard`](../../../src/c64/juego_final/camino.s#L638) | 638 |
| 05FAh | [`chr_path_find`](../../../src/c64/juego_final/camino.s#L671) | 671 |
| 06C8h | [`chr_path_face_target`](../../../src/c64/juego_final/camino.s#L833) | 833 |
| 06E3h | [`chr_cmd_rewind`](../../../src/c64/juego_final/camino.s#L860) | 860 |
| 06FEh | [`chr_room_coords`](../../../src/c64/juego_final/camino.s#L872) | 872 |
| 0724h | [`chr_path_via_rooms`](../../../src/c64/juego_final/camino.s#L944) | 944 |
| 076Dh | [`camino_search_to_marks`](../../../src/c64/juego_final/camino.s#L1035) | 1035 |
| — | [`camino_origin`](../../../src/c64/juego_final/camino.s#L1044) | 1044 |
| 077Eh | [`chr_path_search_to_dest`](../../../src/c64/juego_final/camino.s#L1079) | 1079 |
| 07E6h | [`chr_path_restore_screen_grid`](../../../src/c64/juego_final/camino.s#L1142) | 1142 |
| 07FFh | [`iso_grid_set_origin`](../../../src/c64/juego_final/camino.s#L1163) | 1163 |
| 082Fh | [`chr_path_build_grid`](../../../src/c64/juego_final/camino.s#L1334) | 1334 |
| 08E5h | [`chr_room_distance_near`](../../../src/c64/juego_final/camino.s#L1464) | 1464 |
| 090Ah | [`chr_path_mark_exit_up`](../../../src/c64/juego_final/camino.s#L1488) | 1488 |
| 092Eh | [`iso_grid_cell_of`](../../../src/c64/juego_final/camino.s#L1533) | 1533 |
| — | [`iso_mul24_lo`](../../../src/c64/juego_final/camino.s#L1600) | 1600 |
| 0944h | [`iso_grid_cell_ptr`](../../../src/c64/juego_final/camino.s#L1612) | 1612 |
| 0959h | [`chr_cmd_write_bits`](../../../src/c64/juego_final/camino.s#L1656) | 1656 |

| Original | Rutina | Línea |
|---|---|---|
| 40DEh | [`la_fin_busqueda`](../../../src/c64/juego_final/logica_a_cam.s#L49) | 49 |
| 3F92h | [`chr_path_room_to_marked`](../../../src/c64/juego_final/logica_a_cam.s#L61) | 61 |
| — | [`la_destino`](../../../src/c64/juego_final/logica_a_cam.s#L72) | 72 |
| 3F9Eh | [`chr_path_room_search`](../../../src/c64/juego_final/logica_a_cam.s#L83) | 83 |
| — | [`la_c_ix`](../../../src/c64/juego_final/logica_a_cam.s#L114) | 114 |
| 3FD3h | [`la_sala`](../../../src/c64/juego_final/logica_a_cam.s#L129) | 129 |
| 441Eh | [`chr_path_floor_cell_ptr`](../../../src/c64/juego_final/logica_a_cam.s#L173) | 173 |
| 438Fh | [`chr_path_floor_to_screen`](../../../src/c64/juego_final/logica_a_cam.s#L194) | 194 |
| 4399h | [`chr_path_floor_search`](../../../src/c64/juego_final/logica_a_cam.s#L208) | 208 |
| 4080h | [`cuadro`](../../../src/c64/juego_final/logica_a_cam.s#L593) | 593 |
| — | [`pend_y`](../../../src/c64/juego_final/logica_a_cam.s#L657) | 657 |
| — | [`ret_exp`](../../../src/c64/juego_final/logica_a_cam.s#L733) | 733 |
| 4080h | [`cuadro`](../../../src/c64/juego_final/logica_a_cam.s#L997) | 997 |
| — | [`ret_exp`](../../../src/c64/juego_final/logica_a_cam.s#L1118) | 1118 |
| 4164h | [`chr_adso_step_restore`](../../../src/c64/juego_final/logica_a_cam.s#L1167) | 1167 |
| 40EBh | [`chr_adso_step_guillermo_dir`](../../../src/c64/juego_final/logica_a_cam.s#L1178) | 1178 |
| 410Dh | [`chr_adso_step_aside`](../../../src/c64/juego_final/logica_a_cam.s#L1191) | 1191 |
| 4130h | [`la_adso_prueba`](../../../src/c64/juego_final/logica_a_cam.s#L1220) | 1220 |
| 41A8h | [`chr_cmd_write_one_step`](../../../src/c64/juego_final/logica_a_cam.s#L1263) | 1263 |
| 434Fh | [`chr_cmd_generate`](../../../src/c64/juego_final/logica_a_cam.s#L1283) | 1283 |
| 41B8h | [`chr_cmd_turn_and_step`](../../../src/c64/juego_final/logica_a_cam.s#L1333) | 1333 |
| 432Ch | [`chr_cmd_write_turn`](../../../src/c64/juego_final/logica_a_cam.s#L1351) | 1351 |
| 4292h | [`chr_cmd_write_step`](../../../src/c64/juego_final/logica_a_cam.s#L1389) | 1389 |
| 41C9h | [`chr_cmd_write_path`](../../../src/c64/juego_final/logica_a_cam.s#L1516) | 1516 |
