<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Glosario.md: se edita la plantilla, no esta página. -->
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

# Glosario

[Inicio](Inicio.md) · anterior: [Mis herramientas](Herramientas.md) · siguiente: [Índice de rutinas](Indice-de-rutinas.md)

## Las palabras del juego

| Palabra | Significado |
|---|---|
| *obsequium* | la obediencia: la barra del marcador que vacían las reprimendas del abad |
| *noche, prima, tercia, sexta, nona, vísperas, completas* | las horas canónicas del día monástico |
| *finis Africae* | la sala secreta de la biblioteca, detrás del espejo |
| *scriptorium* | la sala donde escriben los monjes, en el primer piso |
| *pergamino* | los textos de la presentación y del final, y el manuscrito de Venancio |

## Los nombres de las fuentes

| Nombre | Qué hay | Dónde |
|---|---|---|
| `juego`, `juego_final` | el juego, el juego final (integrado) | `src/juego/` (C), `src/c64/juego_final/` (6502) |
| `principal` | el arranque y el bucle principal | `principal.s` |
| `motor_iso` | el motor isométrico: salas, bloques, baldosas | `motor_iso.s` |
| `personajes` | el movimiento, el teclado, el tick de la interrupción | `personajes.s` |
| `camino` | los conductores de los monjes y la planificación de rutas | `camino.s`, `camino_memo.s`, `camino_limpia.s` |
| `logica_a`, `logica_b` | la lógica A (sprites, búsquedas, texto) y B (objetos, reloj, guiones) | `logica_a*.s`, `logica_b*.s` |
| `guiones` | el código de bytes de los monjes | `logica_b_guiones.s` |
| `estado_texto` | los bloques de estado, el búfer de alturas, la fuente, el desplazamiento de las frases | `estado_texto.s` |
| `objetos_sonido` | puertas, objetos y el secuenciador de sonido | `objetos_sonido.s` |
| `cabezas` | las cabezas en alta resolución del C128 y del P500 | `cabezas128.s` |
| `plataforma` | la capa de la máquina: `pantalla`, `tinta`, `teclado`, `interrupcion`, `disco` | `src/c64/plataforma/` |
| `cinta`, `disco64`, `disco128`, `discop500` | las ediciones en cinta y en disco | `src/c64/` |
| `presentacion`, `pergamino` | los programas de la presentación y del final | `src/c64/` |
| `flujo`, `cargador`, `etapa`, `arranque` | la carga | |
| `menu`, `opciones` | el menú de inicio (`OPCIONES`: el byte de opciones) | |
| `paso`, `pitido` | los dos sonidos que el menú puede quitar | |
| `veloz`, `completo` | el trabajo de velocidad (`-D VELOZ`), el juego completo (`-D COMPLETO`) | |
| `editados`, `retoques` | los retoques a mano de los gráficos | |
| `hibrido`, `sombra`, `anfitrion`, `puro` | el anfitrión de comprobación (Z80 y 6502 juntos; el juego en C puro) | `src/juego/` |
| `construye`, `prueba`, `comprueba`, `certifica` | los guiones de construir, probar, comprobar y certificar | |
| `piloto`, `grabaciones`, `entrega` | el jugador automático de los vídeos, las grabaciones y su entrega | `src/c64/video/` |

## Las palabras inglesas de los comentarios

Los comentarios del código están en inglés.  Estas son las palabras que más salen, con el término que uso en esta wiki:

| En el código | En la wiki |
|---|---|
| frame | fotograma |
| tick | tick (cada interrupción de 300 Hz) |
| tile / tile buffer | baldosa / búfer de baldosas |
| block | bloque (de una sala, o del mapa de memoria) |
| height buffer | búfer de alturas |
| record | registro |
| holder | portador (de objetos) |
| driver | conductor (de un monje) |
| script / bytecode | guion / código de bytes |
| places | lugares (los puntos fijos de un monje) |
| score bar | marcador |
| phrase / dictionary | frase / diccionario |
| sequence / envelope / rest | secuencia / envolvente / silencio (del sonido) |
| stream / stage | flujo / etapa (de la carga) |
| flip | volteo (de los gráficos) |
| crunched | comprimido (con Exomizer) |

## Cómo escribo las direcciones

* `20BEh`, `5060`: una dirección del programa de 64 KiB del CPC (el código del Z80 o sus datos), como la dan los
  comentarios.
* `$C000`: una dirección del C64 (o del C128, o del P500).
* `1000:5A23`, `1800:B83E`: una dirección segmento:desplazamiento de la versión de PC, citada donde ayudó el análisis
  del PC.
* `[28D9h]`: el contenido de una variable en esa dirección del CPC.
* `IY+0Eh`, `[IY+5]`: un campo del registro al que apunta IY.
