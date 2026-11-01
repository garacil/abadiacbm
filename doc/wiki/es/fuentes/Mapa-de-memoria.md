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

# Mapa de memoria

[Inicio](Inicio.md) · anterior: [Del Z80 al 6502](Del-Z80-al-6502.md) · siguiente: [Arranque y bucle principal](Bucle-principal.md)

El juego de 64 KiB del CPC llena casi todos sus 64 KiB: 16 KiB de pantalla, unos 16 KiB de código del Z80 y el resto,
datos.  El C64 tiene los mismos 64 KiB, pero su imagen tiene otro formato y el código 6502 del juego ocupa más que el
del Z80.  Todo cabe porque el mapa se calcula bloque a bloque, y porque la propia pantalla del C64 deja sitio para
datos.

## El C64 durante la partida

Desconecto las ROM del BASIC y del KERNAL (`$01 = $35`: RAM en todas partes salvo la E/S de `$D000-$DFFF`); el KERNAL
solo vuelve para cargar o grabar en disco.

| Zona del C64 | Uso |
|---|---|
| `$0000-$0001` | el puerto del 6510 |
| `$0002-$0023` | los registros del Z80 como pares de la página cero y los bytes de trabajo (`zp.inc`) |
| `$0024-$009D` | los operandos que el código del Z80 reescribe: las variables más usadas |
| `$009E-$00FF` | 12 bytes para cada grupo de rutinas (`camino`, `objetos_sonido`, `motor_iso`…) |
| `$0100-$01FF` | la pila del 6502 |
| `$0200-$07FF` | los bloques de variables del CPC enteros y en el orden del CPC (personajes, sprites, puertas, objetos, las variables de la lógica, el estado del sonido, el teclado) y un poco de código 6502 |
| `$0800-$714D` | **el código**: todas las rutinas 6502 del juego, seguidas |
| `$7151-$BFFF` | los datos, empaquetados hacia abajo desde `$C000`: la tabla de salas, las alturas de los tres pisos, los bloques, los textos, los gráficos de los personajes, los búferes, cinco tablas de mezcla alineadas a página |
| `$C000-$C3E7` | la RAM de pantalla del bitmap multicolor (dos de las cuatro plumas de cada celda) |
| `$C400-$CFFF` | las tablas de mezcla de las baldosas, la pila del intérprete de bloques, las palabras, el búfer de alturas |
| `$D000-$DFFF` | **debajo de la E/S**: las baldosas, las caras, la puerta, los números de los días, la luz; se leen con la E/S desconectada |
| `$D800-$DBE7` | (E/S) la RAM de color: la tercera pluma de cada celda |
| `$E000-$FF3F` | el bitmap multicolor: la imagen de 256 × 192 del juego |
| dentro de `$E000-$FFF9` | los bytes invisibles del bitmap: 2042 bytes que nunca se ven, para tablas pequeñas y los datos del sonido |
| `$FFFA-$FFFF` | los vectores NMI, RESET e IRQ (en RAM: el KERNAL está desconectado) |

## Lo que queda libre

He contado los bytes que no usa nadie con el mapa del enlazador de la versión de cinta
(`src/c64/juego_final/c64cinta/juego.map`), quitando la página cero, la pila, la RAM de pantalla, las celdas visibles
del bitmap y los vectores: quedan **925 bytes** (970 en la versión de disco), repartidos en trozos de 64 bytes o menos
dentro del borde invisible del bitmap.  Entre el final del código y el comienzo de los datos quedan **3 bytes** en la
cinta (48 en el disco).  Por eso el C64 no tiene las cabezas en alta resolución con los sprites del VIC-II: sus
máscaras, los sprites y su código no caben.  El C128 y el P500 sí las tienen, porque sacan la tabla de salas y los
textos a su segundo banco de 64 KiB.

## Cómo se hace el mapa

Nada se coloca a mano.  Una tabla enumera cada bloque de datos que necesita el juego, con su dirección del CPC, su
longitud, su tipo y la zona a la que debe ir (los operandos de la página cero de la página anterior son filas así); un
generador los coloca:

{{code src/c64/juego_final/mapa64.py | ^and prints the budget | ^"""}}

{{code src/c64/juego_final/mapa64.py | ^BITMAP = 0xE000 | ^RESERVA_VAR}}

Sus salidas son `mapa64.tsv` (una fila por bloque: la dirección del CPC y la del C64, y cómo lo tratan las
comprobaciones) y `mapa64.inc`, que da a cada nombre `D64_` de las cabeceras de C su dirección en el C64, por ejemplo
`D64_CHR_GUILLERMO = $055B ; CPC 2B87h` (el registro de Guillermo) o `D64_GAME_HOUR = $02A6 ; CPC 28D2h` (la hora).
Después `datos64.py` convierte la imagen en segmentos de ca65 en esas direcciones y ld65 enlaza código y datos en una
sola imagen de 64 KiB.  Cada campo de puntero dentro de los datos (642, encontrados por `tools/punteros64.py`) se
recoloca a la dirección del C64 a la que apunta.

En el C128 y en el P500 el mismo generador saca la tabla de salas y los textos al segundo banco de 64 KiB (el bloque 1
del C128, el banco 1 del P500), lo que deja sitio en el primero para la velocidad y para las cabezas en alta
resolución (ver [El Commodore 128](Commodore-128.md) y [El Commodore P500](Commodore-P500.md)):

{{code src/c64/juego_final/mapa64.py | ^C128 = os.environ.get | +2}}

## La pantalla

El juego del CPC dibuja en modo 1: 256 × 192 píxeles de cuatro colores, un byte con cuatro píxeles, 64 bytes por
línea.  En el C64 esa imagen pasa a ser de 128 × 192 píxeles multicolor (un píxel del C64 por cada pareja de píxeles
del CPC, así que un byte del CPC se convierte en un nibble del C64), centrada en los 160 píxeles de la pantalla, cuatro
celdas desde la izquierda:

{{code src/c64/plataforma/pantalla.s | ^; The CPC screen on the C64 | ^; void __fastcall__}}

Las cuatro plumas del CPC son las cuatro parejas de bits de una celda multicolor.  Un cambio de tinta del CPC no
reescribe ningún píxel, igual que en el CPC: cambia el registro de fondo, o llena la RAM de pantalla o la RAM de color
de las 32 × 24 celdas del juego:

{{code src/c64/plataforma/tinta.s | ^; plat_tinta: A = pen 0-16 | ^; switched between}}

La pluma 3 y el borde son negros en todas las paletas del juego, así que las celdas que quedan fuera del área del
juego, cuya RAM de pantalla y de color siguen negras, nunca enseñan sus bytes del bitmap: guardan datos, igual que el
CPC guardaba datos en la parte oculta de su propia pantalla.
