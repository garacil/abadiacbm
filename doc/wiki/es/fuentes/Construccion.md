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

# Construcción y certificación

[Inicio](Inicio.md) · anterior: [Presentación y final](Pergaminos.md) · siguiente: [Gráficos y herramientas](Graficos.md)

## La cadena de construcción

Todo se genera a partir de las fuentes y de los datos del juego original, de forma determinista: las mismas fuentes dan
la misma cinta y los mismos discos, byte a byte.

1. **Los gráficos**: `tools/c64_graficos.py` convierte cada gráfico del juego del CPC a los formatos del C64 (y aplica
   los retoques a mano de `src/c64/datos/editados64.txt`), en `data/c64graf/`.
2. **El mapa de memoria**: `mapa64.py` coloca cada bloque de datos; `punteros64.py` encuentra los campos de puntero;
   `datos64.py` escribe la imagen de los datos como segmentos de ca65 y la configuración del enlazador (ver
   [Mapa de memoria](Mapa-de-memoria.md)).
3. **Los guiones**: `guiones64.py` traduce los guiones del Z80 de los monjes al código de bytes de la máquina virtual
   (ver [La mente de los monjes](Monjes.md)).
4. **El juego**: ca65 y ld65 ensamblan y enlazan las fuentes 6502 y los datos en una sola imagen de 64 KiB.
5. **La edición**: la presentación y el final (cc65), el flujo o los ficheros comprimidos, el menú, la imagen de la
   cinta o del disco.

{{code src/c64/juego_final/construye.sh | ^# The 6502 game for the hybrid host's checks | ^# tools/inventario64.py}}

Las mismas fuentes construyen todas las variantes con condicionales: `C64=1` la máquina real (sin él, la construcción
para el anfitrión de comprobación), `CINTA=1` la cinta, `DISCO=1` el disco del C64, `C128=1` el Commodore 128, `P500=1`
el Commodore P500, `IDIOMA=en` el inglés; las del C128 y del P500 añaden `-D COMPLETO` y `-D VELOZ`.

## Tres niveles de comprobación

**1. Cada rutina, en cada llamada.**  El anfitrión híbrido (`src/juego/hibrido`) ejecuta el programa original del Z80 y,
en cada llamada a una función que tiene traducción al 6502, ejecuta también la rutina 6502 en un núcleo 6502 (el sim65
de cc65), desde el mismo estado pasado al mapa del C64, y compara: los registros y las banderas que devuelve la función
y cada bloque de datos.  `comprueba.sh` lo hace con las ocho sesiones grabadas (y con `--largos`, con dieciséis largas):

{{code src/c64/juego_final/comprueba.sh | ^# The checks of the integrated 6502 build | ^# Prints the host's summary}}

**2. El juego entero, fotograma a fotograma.**  Con `--juego` el anfitrión ejecuta todo el juego 6502 desde su entrada,
al paso del Z80, y compara toda la memoria en cada fotograma; `dias.sh` lo arranca en cada día y cada hora del juego (49
estados) y juega hasta el final del 100 %.

**3. La máquina real contra el original.**  `src/c64/certifica/certifica.py` ejecuta la construcción real del C64 en
VICE con las mismas teclas que el Z80 original, el mismo byte aleatorio y el mismo modelo de interrupción, y compara en
cada fotograma toda la RAM del C64 con la memoria del CPC a través del mapa:

{{code src/c64/certifica/certifica.py | ^"""The certification of the C64 game | ^c64/juego_final/juego6502.tsv}}

El juego completo del C128 se certifica igual contra mi reconstrucción de la versión de PC (`src/c64/certifica/pc/`),
que juega el juego completo y que a su vez verifiqué fotograma a fotograma contra el original de PC: sesiones al azar de
4000 fotogramas, 0 diferencias.  Y el del P500 también: `corre500.py` arranca el propio disco del P500 en el xcbm5x0 de
VICE como lo haría un jugador (el menú, el pergamino, el cargador, la etapa del banco 1) y después, en cada fotograma,
pone las mismas teclas y vuelca el banco 0 y los datos del banco 1.  Cuatro sesiones al azar de 6000 fotogramas (pasadas
las primeras completas, con el abad persiguiendo a Guillermo y las puertas abriéndose y cerrándose), 237 datos
comparados en cada fotograma, 0 diferencias: el P500 juega exactamente la misma partida que el PC original.

{{code src/c64/certifica/pc/corre500.py | ^"""abadia128ks on the P500 against the PC | ^"""$}}

## Las pruebas de las ediciones

Las propias ediciones se prueban en VICE, desde la cinta o el disco, como las arrancaría un jugador:

| Prueba | Qué comprueba |
|---|---|
| `src/c64/cinta/prueba_cinta.py SALIDA [--opciones TECLAS] [--final]` | la cinta: el menú, cada bloque cargado, la memoria del juego en su primera instrucción igual a su imagen, las opciones (las notas del paso y del pitido en silencio), el final cargado de la cinta |
| `prueba_cinta.py SALIDA --disco [--unidad 1541\|1571]` | lo mismo en el disco del C64, con cada unidad |
| `src/c64/disco128/prueba128.py SALIDA [--opciones 1234] [--final\|--guarda] [--unidad 1571\|1541]` | el disco del C128: el arranque, los dos bloques de memoria, las opciones, grabar y cargar, el final; con cada unidad |
| `src/c64/presentacion/pruebas/disco_prueba/prueba.py` | las páginas y la música de los pergaminos, la imagen durante la carga |

`tools/genera_todo.sh --prueba` construye las ediciones de C64 y C128 y ejecuta estas pruebas.
