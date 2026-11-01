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

# Cómo funciona la abadía — la wiki de abadiacbm

*La abadía del crimen* (Paco Menéndez y Juan Delcán, Opera Soft, 1987) es una aventura isométrica en la que fray
Guillermo de Occam y su novicio Adso pasan siete días en una abadía benedictina para resolver una serie de muertes.
En esta wiki explico cómo funciona el juego por dentro, rutina a rutina, a través del código de mis versiones para
Commodore:

* **abadia64ks** — Commodore 64, cinta y disco: la versión de cinta de 64 KiB del Amstrad CPC, que traduje a 6502
  rutina a rutina y certifiqué contra el programa original del Z80 fotograma a fotograma;
* **abadia128ks** — Commodore 128 en su propio modo, disco: el juego completo (el mapa y las reglas de las versiones
  de CPC 6128 y PC) sobre el mismo código 6502, con las cabezas en alta resolución, 2 MHz en los bordes y el Ave María;
* **abadia128ks para el P500** — Commodore P500 (CBM-II 510, 128 KiB), disco: el mismo juego completo sobre el MOS 6509
  y sus bancos.

Las descargas, con sus instrucciones, y los vídeos de partidas completas están en
[abbeyofcrime.com](https://abbeyofcrime.com).  Las fuentes completas, en
[github.com/garacil/abadiacbm](https://github.com/garacil/abadiacbm).

Cada fragmento de código de estas páginas se toma de las fuentes al construir la wiki (`tools/wiki.py`), con su
fichero y sus números de línea enlazados, así que siempre coincide con el código del repositorio.

*English version: [Home](../Home.md).*

## Páginas

| Página | Qué explica |
|---|---|
| [El juego](El-juego.md) | los siete días, las horas, las ceremonias, los monjes, el obsequium, los objetos, el final y el porcentaje |
| [Del Z80 al 6502](Del-Z80-al-6502.md) | cómo traduje el programa del CPC: registros, nombres de los datos, direcciones, los contratos de las rutinas |
| [Mapa de memoria](Mapa-de-memoria.md) | dónde vive el juego en los 64 KiB del C64, cómo se genera el mapa, qué queda libre |
| [Arranque y bucle principal](Bucle-principal.md) | el arranque, una partida nueva, el fotograma, la interrupción de 300 Hz, la velocidad |
| [El reloj y las ceremonias](Reloj.md) | días y horas, su duración, qué pasa en cada hora, la noche |
| [Las salas y el motor isométrico](Motor-isometrico.md) | la tabla de salas, el intérprete de bloques, las baldosas, la profundidad, la cámara |
| [Los personajes y su movimiento](Personajes.md) | los registros de personaje, pasos, giros, alturas, animación y proyección |
| [Los sprites y la pantalla](Sprites-y-pantalla.md) | la tabla de sprites, la composición por rectángulos, la luz, el volcado |
| [Alturas y búsqueda de caminos](Caminos.md) | el búfer de alturas, las búsquedas dentro de una sala y entre salas, las órdenes de movimiento |
| [La mente de los monjes](Monjes.md) | los guiones de comportamiento y su máquina virtual, los conductores, cada personaje |
| [Objetos, puertas y el espejo](Objetos.md) | portadores, coger y dejar, llaves y puertas, el enigma del espejo |
| [El texto y el marcador](Texto.md) | palabras y frases, el desplazamiento del texto, el marcador, la barra del obsequium |
| [El sonido](Sonido.md) | el secuenciador de la interrupción, música y efectos, el AY tocado en el SID |
| [La plataforma del Commodore 64](Plataforma-C64.md) | la preparación de la máquina, la interrupción, teclado y joystick, tintas, disco |
| [El Commodore 128](Commodore-128.md) | la MMU y el bloque 1, los 2 MHz, las cabezas en alta resolución, el Ave María |
| [El Commodore P500](Commodore-P500.md) | los bancos del 6509, los chips del banco 15, la interrupción, el teclado, el KERNAL entre bancos |
| [La carga: cinta y discos](Carga.md) | el menú de inicio, el cargador turbo, las etapas, la compresión, las opciones |
| [Presentación y final](Pergaminos.md) | los pergaminos con su música, escritos en C |
| [Construcción y certificación](Construccion.md) | la cadena de construcción, los datos generados, las pruebas, la certificación |
| [Gráficos y herramientas](Graficos.md) | los gráficos del CPC en el C64, la conversión, el editor, las demás herramientas |
| [Mis herramientas](Herramientas.md) | cómo construyo, pruebo y mido el juego: el anfitrión híbrido, la certificación, el analizador de ciclos, la medida en VICE, la licencia, esta wiki |
| [Glosario](Glosario.md) | los nombres en español del código y los términos del juego |
| [Índice de rutinas](Indice-de-rutinas.md) | todas las rutinas del juego, fichero a fichero, con la dirección de la función original |

## Cómo leer el código

* Las fuentes 6502 están en `src/c64/juego_final/` (el juego), `src/c64/plataforma/` (la máquina), `src/c64/cinta/`,
  `disco64/`, `disco128/`, `discop500/` (la carga) y `src/c64/presentacion/` (los pergaminos).
* Casi todas las rutinas empiezan con un comentario que da la **dirección de la función del Z80** que traducen en el
  programa de 64 KiB del CPC (por ejemplo `; 20BE game_main`), y muchas líneas llevan la dirección de la instrucción
  del Z80 a la que sustituyen.  Los mismos nombres están en la traducción a C (`src/juego/f_*.c`), que es la
  referencia legible.
* A los datos se llega por los nombres `D64_*`: cada uno es un dato del programa del CPC colocado en una dirección del
  C64 por el mapa de memoria generado (ver [Mapa de memoria](Mapa-de-memoria.md)).
* Las rutinas conservan la interfaz de la función del Z80: los pares de registros del Z80 son pares de la página cero
  (`zbc`, `zde`, `zhl`, `zix`, `ziy`) y el acumulador es el acumulador (ver [Del Z80 al 6502](Del-Z80-al-6502.md)).
* Los comentarios, los nombres y los documentos del código están en inglés; los nombres de ficheros y directorios
  suelen estar en español (ver el [Glosario](Glosario.md)).
