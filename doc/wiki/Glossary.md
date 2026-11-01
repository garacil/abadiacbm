<!-- Made by tools/wiki.py from doc/wiki/fuentes/Glossary.md: edit the template, not this page. -->
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

# Glossary

[Home](Home.md) · previous: [My tools](Tools.md)

## The game's words

| Word | Meaning |
|---|---|
| *abadía* | abbey |
| *abad* | the abbot |
| *fray* | brother (a friar's title: *fray Guillermo*) |
| *obsequium* | obedience: the bar of the score bar that the abbot's reprimands empty |
| *noche, prima, tercia, sexta, nona, vísperas, completas* | the canonical hours: night, prime, terce, sext, none, vespers, compline |
| *finis Africae* | the secret room of the library, behind the mirror |
| *scriptorium* | the monks' writing room, on the first floor |
| *Guillermo, Adso, Malaquías, Berengario, Severino, Jorge, Bernardo Gui, Venancio* | William of Occam, Adso of Melk, Malachi, Berengar, Severinus, Jorge, Bernard Gui, Venantius |
| *pergamino* | parchment: the introduction's and the ending's texts |

## The names in the sources

| Spanish | English | Where |
|---|---|---|
| `juego`, `juego_final` | the game, the final (integrated) game | `src/juego/` (C), `src/c64/juego_final/` (6502) |
| `principal` | main | the start and the main loop |
| `motor_iso` | isometric engine | rooms, blocks, tiles |
| `personajes` | characters | movement, keyboard, the interrupt's tick |
| `camino` | path | the monks' drivers and route planning |
| `logica_a`, `logica_b` | logic A and B | sprites, searches, text (A); objects, clock, scripts (B) |
| `guiones` | scripts | the monks' bytecode (`logica_b_guiones.s`) |
| `estado_texto` | state and text | state blocks, height buffer, font, phrase scroller |
| `objetos_sonido` | objects and sound | doors, objects, the sound sequencer |
| `cabezas` | heads | the C128's hires heads |
| `plataforma` | platform | the machine layer |
| `pantalla`, `tinta`, `teclado`, `interrupcion`, `disco` | screen, ink, keyboard, interrupt, disk | the platform's files |
| `cinta` | tape | the tape release, the stream |
| `disco64`, `disco128` | the C64 disk, the C128 disk | the disk releases |
| `presentacion` | presentation | the introduction and the ending programs |
| `flujo`, `cargador`, `etapa`, `arranque` | stream, loader, stage, boot | loading |
| `menu`, `opciones` | menu, options | the start menu (`OPCIONES`: the options byte) |
| `paso`, `pitido` | footstep, beep | the two sounds the menu can turn off |
| `veloz`, `completo` | fast, full | the C128's speed work (`-D VELOZ`), the full game (`-D COMPLETO`) |
| `baldosas` | tiles | |
| `editados`, `retoques` | edited, retouches | the hand edits of the graphics |
| `marcos` | frames | the animation frames and the graphics' addresses |
| `mapa`, `bloques`, `datos`, `punteros` | map, blocks, data, pointers | the memory map |
| `salas`, `alturas` | rooms, heights | |
| `libres` | free | the bytes the game does not need at its start |
| `hibrido`, `sombra`, `anfitrion`, `puro` | hybrid, shadow, host, pure | the checking host (Z80 and 6502 side by side; the pure C game) |
| `construye`, `prueba`, `comprueba`, `certifica` | builds, test, checks, certifies | the scripts |
| `resultados` | results | |
| `idioma`, `ingles` | language, English | |
| `piloto` | pilot | the automatic player of the videos |
| `grabaciones`, `entrega` | recordings, delivery | the videos |
| `herramientas`, `terceros` | tools, third parties | |
| `referencias`, `revisiones`, `respaldos` | references, reviews, backups | |

## Address notation

* `20BEh`, `5060` — an address of the CPC 64 KiB program (the Z80 code or its data), as the comments give them.
* `$C000` — a C64 (or C128) address.
* `1000:5A23`, `1800:B83E` — a segment:offset address of the PC version, quoted where the PC's analysis helped.
* `[28D9h]` — the contents of a variable at that CPC address.
* `IY+0Eh`, `[IY+5]` — a field of the record that IY points to.
