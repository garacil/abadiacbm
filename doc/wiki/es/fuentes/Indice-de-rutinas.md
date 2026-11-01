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

# Índice de rutinas

[Inicio](Inicio.md) · anterior: [Glosario](Glosario.md)

Todas las rutinas del juego y de la plataforma, fichero a fichero, tal como están en las fuentes: cada `.proc` y cada
etiqueta de principio de línea que lleva un comentario encima.  La columna *Original* da la dirección de la función del
Z80 que traduce la rutina en el programa de 64 KiB del CPC, cuando su comentario empieza con ella; un guion, cuando es
una rutina propia del 6502 (una ayuda, una parte de la plataforma).  Cada nombre enlaza con su línea.  Esta página la
genera `tools/wiki.py`, así que siempre está al día con el código.

## El juego (`src/c64/juego_final/`)

### `principal.s`: el arranque y el bucle principal

{{rutinas src/c64/juego_final/principal.s}}

### `motor_iso.s`: las salas y el motor isométrico

{{rutinas src/c64/juego_final/motor_iso.s}}

### `personajes.s`: los personajes, el teclado y el tick

{{rutinas src/c64/juego_final/personajes.s}}

### `camino.s`: los conductores y la búsqueda de caminos

{{rutinas src/c64/juego_final/camino.s}}

### `logica_a.s`: la cámara, el texto, el porcentaje

{{rutinas src/c64/juego_final/logica_a.s}}

### `logica_a_cam.s`: las búsquedas y el escritor de órdenes

{{rutinas src/c64/juego_final/logica_a_cam.s}}

### `logica_a_spr.s`: los sprites

{{rutinas src/c64/juego_final/logica_a_spr.s}}

### `logica_b.s`: objetos, reloj, marcador y la máquina virtual de los guiones

{{rutinas src/c64/juego_final/logica_b.s}}

### `logica_b_guiones.s`: los guiones

{{rutinas src/c64/juego_final/logica_b_guiones.s}}

### `estado_texto.s`: el estado de la partida, las alturas y el texto

{{rutinas src/c64/juego_final/estado_texto.s}}

### `objetos_sonido.s`: puertas, objetos y sonido

{{rutinas src/c64/juego_final/objetos_sonido.s}}

### `cabezas128.s`: las cabezas en alta resolución (C128 y P500)

{{rutinas src/c64/juego_final/cabezas128.s}}

## La plataforma (`src/c64/plataforma/`)

### `interrupcion.s`: la preparación del C64 y la interrupción

{{rutinas src/c64/plataforma/interrupcion.s}}

### `teclado.s`: el teclado y el joystick del C64

{{rutinas src/c64/plataforma/teclado.s}}

### `psg.s`: el AY en el SID

{{rutinas src/c64/plataforma/psg.s}}

### `disco.s`: grabar, cargar y el final

{{rutinas src/c64/plataforma/disco.s}}

### `c128.s`: el Commodore 128

{{rutinas src/c64/plataforma/c128.s}}

### `p500.s`, `interrupcion500.s`, `teclado500.s`: el Commodore P500

{{rutinas src/c64/plataforma/p500.s}}

{{rutinas src/c64/plataforma/interrupcion500.s}}

{{rutinas src/c64/plataforma/teclado500.s}}
