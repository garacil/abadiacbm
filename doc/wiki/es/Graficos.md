<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Graficos.md: se edita la plantilla, no esta página. -->
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

# Gráficos y herramientas

[Inicio](Inicio.md) · anterior: [Construcción y certificación](Construccion.md) · siguiente: [Mis herramientas](Herramientas.md)

## De los píxeles del CPC a los del C64

El juego del CPC dibuja en modo 1: cuatro colores, 320 píxeles por línea.  El bitmap multicolor del C64 también tiene
cuatro colores por celda, pero 160 píxeles por línea: cada pareja de píxeles del CPC tiene que convertirse en un píxel
del C64.  Para una baldosa o una pared apenas importa; para una cara de 5 píxeles de ancho decide si sobreviven los
ojos.  La conversión es un programa, `tools/c64_graficos.py`, y sus reglas las elegí mirando el resultado en la
pantalla:

[`tools/c64_graficos.py`](../../../tools/c64_graficos.py#L55-L75), líneas 55–75:

```python
The pixel rule: a CPC mode 1 byte (4 pixels) becomes one C64 multicolour nibble (2 pixels), each pair of
CPC pixels one C64 pixel, pen -> bit pair BITS (c64_sala.py: pen 3 = 00 = $D021, pen 0 = 01, pen 1 = 10,
pen 2 = 11).  Which pixel of a pair survives:
  sim      the door and the objects: the pen first in 1, 2, 3, 0 (orange, yellow, black, then transparent pen 0).
           Mirror-symmetric and per byte, so the game's in-place flip of the door gives exactly the conversion of
           the flipped CPC graphic.
  trazos   Guillermo, Adso, the monks' faces and robes (c64_mitad.py: the same shape as the PC
           EGA / CPC drawing): per line, the least-cost choice of one pixel of each pair, where losing a stroke of
           the drawing (a run of any pen that is darker or lighter than its neighbours, an inner gap) costs much,
           losing a one-pixel step of shading costs little, and moving an edge costs little; the silhouette grows
           outward; ties go with the line above.  Not mirror-symmetric: the game flips the C64 data in place
           (faces, Guillermo, Adso) or reads the robes backwards, and the host's checks take a flipped unit from the
           image (src/juego/m6502/sombra6502.c, convierte).  It replaces the rules aislado and the hand retouches of
           src/c64/datos/retoques64.txt (kept, no longer applied).  Over the rule, the lines edited by hand with
           tools/c64_editor.py (src/c64/datos/editados64.txt, same format: the graphic's CPC address, the
           line, one character a C64 pixel) replace the rule's lines of Guillermo, Adso, the faces, the robes and
           the tiles 01h-D9h but the object slots (the tile's key: its tape address 8300h + 32n; normal build only,
           not --hw); a line of the wrong length, outside its graphic or at an unknown address
           stops the build.  Another file: the environment variable C64_EDITADOS.
  detalle  tiles (per tile), the roman numerals: c64_sala.py's rule (right pixel, keeps one-pixel
           vertical lines and fluting).
```

Los colores son las paletas de la versión de CPC (no las del PC), llevadas por su tono a los colores más cercanos del
C64 (`src/c64/datos/paleta.tsv`).

## Los retoques a mano

Por encima de las reglas, las líneas retocadas a mano sustituyen a las convertidas.  `tools/c64_editor.py` (PySide6)
enseña los fotogramas de cada personaje, las caras y los hábitos de los monjes y las baldosas, el gráfico EGA del PC al
lado del del C64, y los edita píxel a píxel: un cursor de píxel que parpadea, el color elegido con las cifras, ESPACIO
pinta, O P Q A mueven; deshacer y rehacer; el ciclo de andar animado como lo juega el juego, a la velocidad elegida.
Escribe `src/c64/datos/editados64.txt`, una línea por cada línea de gráfico editada, que aplica cada construcción; una
línea de longitud equivocada o en una dirección que no se puede editar detiene la construcción.  Las baldosas del 64ks
y del 128ks son las mismas; en el C128 las cabezas cambian (sus trazos negros van a los sprites por hardware), y las
baldosas nuevas del C128 (las 32 imágenes nuevas del juego completo) se convierten con la misma regla.

## Las cabezas del C128

Con `--c128` la conversión aparta los trazos negros de las cabezas: la cabeza multicolor se queda solo con los
rellenos, y el negro de cada una de las 26 cabezas (los 12 fotogramas de Guillermo y de Adso, las 14 caras de los
monjes) se guarda a la anchura completa del PC, un bit por píxel, para los sprites en alta resolución del VIC-II (ver
[El Commodore 128](Commodore-128.md)).

## Otras herramientas

Todas mis herramientas están en `doc/HERRAMIENTAS.md`, y las principales explicadas en [Mis herramientas](Herramientas.md).

| Herramienta | Qué |
|---|---|
| `tools/c64_compara_pc.py` | hojas que comparan cada gráfico: el EGA del PC, el del C64, las reglas una al lado de otra, con medidas de los trazos perdidos |
| `tools/mapa_por_codigo.py`, `tools/compara_datos_pc.py`, `tools/difiere_funciones.py`, `tools/par_funcion.py` | el juego de 64 KiB contra el juego completo (la versión de PC): datos por nombre, funciones por código, uno al lado de otro |
| `tools/datos128.py`, `tools/baldosas128.py` | el mapa y las baldosas del juego completo para el C128, a partir de los datos de la versión de PC |
| `tools/punteros64.py`, `tools/inventario64.py` | los campos de puntero dentro de los datos; el inventario de lo que lee el juego |
| `tools/cpc_velocidad.py` | la velocidad real del juego del CPC en Caprice32, para las comparaciones de velocidad |
| `tools/guion_azar.py` | guiones de teclas al azar para las sesiones de certificación |
| `tools/genera_todo.sh`, `tools/genera_cinta.sh` | las ediciones de una vez |
| `tools/sincroniza.sh` | el proyecto copiado a mis otras máquinas, comparando antes los retoques de los gráficos |
| `tools/wiki.py`, `tools/wiki_github.py` | esta wiki: cada fragmento de código tomado de las fuentes al construirla; y su copia en la wiki de GitHub |
| `src/c64/mapa/hoja64.py`, `mapa64.py` | una hoja con todos los gráficos del C64, y el mapa de toda la abadía tal como la dibuja el C64 |

## Esta wiki

Las páginas de `doc/wiki/es/` las hace `tools/wiki.py` a partir de las plantillas de `doc/wiki/es/fuentes/` (y las
inglesas de `doc/wiki/`, a partir de `doc/wiki/fuentes/`): una línea `{{code RUTA | INICIO | FIN}}` se convierte en las
líneas de RUTA desde la que encaja con INICIO hasta la que encaja con FIN, con el fichero y los números de línea; una
línea `{{rutinas RUTA}}` se convierte en la tabla de todas las rutinas de RUTA.  `tools/wiki.py --check` dice si alguna
página ya no coincide con las fuentes, y `tools/wiki_github.py` copia las dos wikis a la wiki de GitHub.
