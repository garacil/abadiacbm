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

# Mis herramientas

[Inicio](Inicio.md) · anterior: [Gráficos y herramientas](Graficos.md) · siguiente: [Glosario](Glosario.md)

Todo lo de este proyecto lo hice, lo comprobé y lo medí con herramientas que escribí para él, y están todas en el
repositorio, con la misma licencia que el juego: `doc/HERRAMIENTAS.md` las enumera todas, agrupadas por lo que hago
con ellas.  Aquí enseño cómo funcionan las más importantes.  Todas cumplen tres reglas: con las mismas entradas dan
las mismas salidas, byte a byte; cada dato de la máquina sale de la documentación oficial o del código que se mide,
nunca de memoria; y todo lo que cambia el juego va seguido de las comprobaciones que demuestran que sigue siendo el
mismo juego.

## El anfitrión híbrido: cada rutina contra el Z80

Nunca me fié de la traducción a C ni de las rutinas 6502 por leerlas: `src/juego/hibrido` ejecuta el programa Z80
original del CPC, y cada vez que el Z80 llama a una función que he traducido, primero se ejecuta la traducción desde
el mismo estado, después la máquina vuelve atrás y el original Z80 hace la misma llamada:

{{code src/juego/hibrido.c | ^static void llamada_traducida | ^\x7d}}

La comparación abarca los 64 KiB enteros, SP, PC y los resultados que declara cada función (sus banderas, sus
registros); solo se deja fuera la pila muerta por debajo de la entrada, que una función en C nunca escribe:

{{code src/juego/hibrido.c | ^static void compara\(const traducida_t | ^\x7d}}

Con `--6502 DIR` las rutinas 6502 del juego (`src/c64/juego_final`) se comprueban igual sobre el núcleo 6502 de
sim65 (`src/juego/m6502/sombra6502.c`), y con `--juego6502 DIR` el juego 6502 entero corre al paso del Z80 y su
memoria se compara en cada fotograma.  Las comprobaciones recorren las 8 sesiones de exploración, 16 guiones largos,
cada día y cada hora del juego y el final (`src/c64/juego_final/comprueba.sh`, `dias.sh`): 0 diferencias.

## La certificación en las máquinas de verdad

El anfitrión prueba el código 6502; la certificación prueba las ediciones.  `src/c64/certifica/certifica.py` ejecuta
la construcción real del C64 en VICE fotograma a fotograma, al paso del Z80 del anfitrión, a través de dos FIFO;
`src/c64/certifica/pc/lote.sh` ejecuta los discos del C128 y del P500 en VICE (`corre128.py`, `corre500.py`: el P500
desde su propio disco, con su menú, su pergamino y su cargador) junto a mi reconstrucción del juego completo de PC
con las mismas teclas, y `compara.py` compara 237 datos en cada fotograma.

## Los ciclos sacados del propio código del emulador

Para el trabajo de velocidad necesitaba el coste exacto de cada instrucción.  `tools/velocidad/analizador/ciclos6502.py`
no lleva una tabla de ciclos: los lee del propio `6502.c` de sim65, de su tabla de códigos de operación y de las
macros de cada manejador, y cada cifra guarda las líneas del fuente de donde salió:

{{code tools/velocidad/analizador/ciclos6502.py | ^def parse_6502c | +24}}

`prueba_sim65.py` comprueba después el analizador contra la realidad: un programa pequeño para cada código de
operación legal, cruzando página y sin cruzarla, y un programa de bucles, todo medido con `sim65 --cycles` (200 casos,
0 diferencias).

## Medir el fotograma real en VICE

`tools/velocidad/vice/medir.py` mide el fotograma del C64 en VICE sin estorbarlo: solo para el emulador en puntos de
control y en cada parada lee el CIA 2 como un contador de ciclos de 32 bits, así que cada cifra es exacta:

{{code tools/velocidad/vice/medir.py | ^Checkpoints \(addresses from juego.lbl | +9}}

## Mi licencia en cada fichero

`tools/licencia.py` pone mi cabecera en cada fichero de texto del repositorio, con la sintaxis de comentario de cada
uno, y dice cuáles no la tienen (`--comprueba --git`, antes de cada commit):

{{code tools/licencia.py | ^def cabecera | ^    return}}

## Esta wiki

`tools/wiki.py` hace estas páginas a partir de sus plantillas: cada fragmento se corta de las fuentes al construir la
wiki, con su fichero y sus números de línea, así que ninguno se copia a mano y ninguno puede quedarse viejo:

{{code tools/wiki.py | ^def extracto | ^    return}}

`tools/wiki_github.py` publica las páginas de los dos idiomas en la wiki de GitHub del repositorio.
