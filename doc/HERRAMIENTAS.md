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

# My tools

Everything in this project was made, checked and measured with tools I wrote for it, and they are all here, under
the same licence as the game.  This page says what each one does and how it works, grouped by what I use it for; the
details are in each tool's own text (its docstring or its first comment lines: `python3 -I TOOL` without arguments
prints it).  The wiki explains the most important ones with their code: [Tools](wiki/Tools.md)
([Herramientas](wiki/es/Herramientas.md) in Spanish).

The rules I keep in all of them:

* **Deterministic.**  The same inputs give the same outputs, byte for byte: no clock, no random seed that is not
  written down, no manual step.  A tool that measures in an emulator says which figures are wall time (the only ones
  that may change).
* **Nothing from memory.**  Every machine fact a tool uses (an address, a cycle count, a KERNAL routine) comes from
  the official documentation or from the code it measures, and the tool says where (`doc/referencias/`).
* **Checked against the original.**  A tool that changes the game is followed by the checks that prove the game is
  the same: the 6502 routines and the whole game against the Z80, frame by frame.
* Python runs with `python3 -I` (no current directory or user site on the path); the third-party programs are in
  `tools/terceros/` (not in the repository: cc65 2.19, Exomizer 2.0.9; see the README).

## The pipelines

    the original tape ──► tools/cinta64.py ──► data/cpc64/ (the CPC 64 KiB game's memory)
                                                    │
         tools/cpc_carga.py (a Z80 simulator) ◄─────┤──► the function map, listings, accesses (tools/*64.py)
                                                    │
                     src/juego/ (the game in C) ◄───┤──► src/juego/hibrido: the C and the 6502 against the Z80
                                                    │
    src/c64/juego_final (the 6502 game) ──► construye.sh ──► images ──► loaders ──► tape and disks (construye.sh)
                                                    │
                    certification in VICE ◄─────────┴──► speed: tools/velocidad/ ; videos: src/c64/video/

## Building the releases

| Tool | What it does and how |
|---|---|
| `src/c64/cinta/construye.sh` | the C64 tape `abadia64ks.tap` and every C64 image of the game: the English data (`src/c64/ingles/datos.sh`), the game's images for the tape (both languages), the menu, the presentation and the ending, the stream of the game's blocks, then `cinta.py` writes the TAP |
| `src/c64/disco64/construye.sh` | the C64 disk `abadia64ks.d64`: the same programs crunched with Exomizer, the game's stream read by the KERNAL |
| `src/c64/disco128/construye.sh` | the C128 disk: the game built with `C128=1` (the full game), its pieces (`piezas128.py`), the Ave María (`ave128.py`), the boot sector (`arranque128.py`), every file crunched |
| `src/c64/discop500/construye.sh` | the P500 disks (8050 and 2031/4040): the game built with `P500=1`, its pieces (`piezas500.py`), the cc65 menu and loader for the cbm510 target |
| `tools/genera_todo.sh` | the four builds above in order, and with `--prueba` the tests in VICE of the tape and the C64 and C128 disks |
| `src/c64/juego_final/construye.sh` | the 6502 game itself: `mapa64.py` (the memory map from `bloques64.tsv`), `tools/punteros64.py` (the pointer fields), `datos64.py` (the data as ca65 source at their C64 addresses), `stubs64.py`, then ca65/ld65; the variables `C64`, `CINTA`, `DISCO`, `C128`, `P500`, `IDIOMA=en` choose the machine and the release; without `C64` the checked build for the host |
| `src/c64/juego_final/guiones64.py` | the monks' behaviour scripts (Z80 51E7-60F2) as bytecode for the 6502 virtual machine of `logica_b.s` |
| `src/c64/presentacion/construye.sh`, `datos.py` | the parchments' program in C (cc65) and its data, from the tape's own text and pictures |
| `src/c64/cinta/flujo.py`, `flujo_cinta.py`, `libres.py`, `lz64.c` | the game's image as the stream the loader reads under the loading picture: the bytes needed at the game's start (checked with the host), in segments, with literal runs |
| `src/c64/cinta/cinta.py` | the TAP image: the KERNAL's files in the ROM's own encoding and my turbo blocks |
| `src/c64/ingles/datos.sh` and its `*.py` | the English data: the phrases tokenised into the tape's format (`genera_ram_en.py`), the parchments broken into lines with the glyphs' widths (`pergamino_en.py`), the missing glyphs (`glifos_en.py`), "Day" (`dia_en.py`), the English title (`titulo_en.py`) |
| `tools/c64_graficos.py`, `c64_mitad.py`, `c64_colores.py` | the CPC graphics converted to the C64's formats with the rule `trazos` (every stroke of the drawing kept), the inks by hue, my hand edits put over them |
| `tools/datos128.py`, `tools/baldosas128.py` | the full game's map and tiles for abadia128ks, from the PC version's data |

## Proving the game

| Tool | What it does and how |
|---|---|
| `src/juego/hibrido` (`hibrido.c`, `m6502/sombra6502.c`) | my hybrid host: the CPC's Z80 program runs, and at every call of a function I translated, the C function (and with `--6502` the 6502 routine on sim65's core) runs from the same state; all the 64 KiB, SP, PC and the declared results are compared.  With `--juego6502` the whole 6502 game runs in step with the Z80 and its memory is compared at every frame |
| `src/juego/prueba.sh` | the C functions against the Z80 over the 8 exploration sessions |
| `src/c64/juego_final/comprueba.sh`, `dias.sh` | the 6502 routines (or with `--juego` the whole 6502 game) against the Z80: the 8 sessions, the 16 long scripts, every day and hour and the ending |
| `src/juego/puro/pruebas/*.sh` | the pure C game (no Z80) against the Z80 run, frame by frame |
| `src/c64/certifica/certifica.py`, `vice_cert.py`, `parche_externo.py` | the certification: the real C64 build in VICE, frame by frame in step with the host's Z80 through two FIFOs, the whole memory compared |
| `src/c64/certifica/pc/` (`lote.sh`, `corre128.py`, `corre500.py`, `compara.py`, `construye.sh`) | abadia128ks against my PC rebuild of the full game: the C128 and the P500 in VICE and the PC rebuild with the same keys, 237 data compared at every frame |
| `src/c64/cinta/prueba_cinta.py`, `src/c64/disco128/prueba128.py` | the tape and the disks in VICE as a player loads them (both a 1541 and a 1571): the menu's options, the presentation, the game's memory equal to its image, the ending, save and load |
| `src/c64/plataforma/pruebas/prueba.py` | the platform layer's tests in VICE: inks, keyboard, the interrupt, the sound against the AY |
| `src/c64/plataforma/pruebas/vice_mb.py` | my client of VICE's binary monitor, used by all the tests: checkpoints, memory, registers, keys |

## Understanding the original

| Tool | What it does and how |
|---|---|
| `tools/tzx.py`, `tools/cinta64.py`, `tools/dsk.py` | the original cassette (CDT) and disk images read: the three blocks of the tape placed in memory as its loader places them |
| `tools/cpc_carga.py`, `tools/z80sim.py` | a CPC program loaded and run on a Z80 simulator (SkoolKit's) with the firmware calls emulated: the memory it leaves, the calls, the coverage, the AY's writes, screenshots |
| `tools/guion_azar.py` | the exploration sessions' key scripts, random but from a written seed |
| `tools/funciones64.py`, `tools/listado64.py`, `tools/particion64.py` | the function map of the CPC 64 KiB game, a Z80 listing per function, the memory split into code, data in code and data |
| `tools/datos64.py`, `tools/quien64.py`, `tools/inventario64.py`, `tools/punteros64.py` | every datum the game uses, who reads and writes it, and the pointer fields among them |
| `tools/mapa64.py`, `tools/mapa_por_codigo.py`, `tools/compara_datos_pc.py`, `tools/difcodigo*.py`, `tools/difiere*.py`, `tools/par_funcion.py`, `tools/codigo_comun.py` | the 64 KiB game against the full game (my PC rebuild): the data found through the code, the code compared function by function |
| `tools/salas64.py`, `tools/bloques_base.py`, `tools/compara_salas.py`, `tools/alturas.py`, `tools/compara_alturas.py` | the rooms and the height maps built and drawn as the game builds them |
| `tools/cpc_velocidad.py` | the CPC game's real speed on the Caprice32 emulator, through its control socket |
| `tools/ay_a_wav.py`, `tools/compara_audio.py`, `tools/gnu_comparacion/` | the CPC's music as a WAV from its register writes, and my versions' sound and pictures against the CPC's |

## Speed: `tools/velocidad/`

The instruments of the speed work (the C64 faster than the CPC: rounds 4 and 5 of `doc/ESTADO.md`).  They work on a
copy of the game, never on the project:

| Tool | What it does and how |
|---|---|
| `copia.sh WORK` | a working copy at the same depth as in the project (the game and the platform copied, the rest linked), built twice by its own `construye.sh` |
| `analizador/ciclos6502.py` | the static cycle analyzer: every instruction of the ca65 listings with its cycles, read from sim65's own `6502.c` (its opcode table and macros, each figure with the source lines it comes from), the loops and their cost per pass, the routines and calls |
| `analizador/prueba_sim65.py` | the analyzer checked against sim65: a small program per opcode and a program of loops, measured by `sim65 --cycles` |
| `colocacion/construye.sh`, `colocacion/saltos6502.py` | the copy's builds again with listings and debug information (the images checked identical), and the jumps that the placement of the routines could avoid, weighed by the profile: a plan and its verification |
| `perfil/construye_prueba.sh`, `perfil.sh`, `perfil_rutinas.py`, `goal.py` | the host's profile by address over the sessions, attributed to routines through ld65's debug file; the arithmetic of the goal |
| `perfil/parche_traza.py`, `traza.sh`, `ticks.sh`, `traza_analisis.py`, `partes.py`, `huella_bloques.py`, `volcado_diff.py`, `golpes.sh` | a call tracer added to a copy of the host: calls, inclusive cycles, identical inputs, memory footprints |
| `vice/medir.py`, `une.py`, `sitios.py` | the real frame in VICE: the cycles of every frame and of every 300 Hz interrupt, the sound and every SID write, by checkpoints only (exact); long runs in chunks joined seamlessly |
| `vice/latencia.py`, `prueba_vic.py`, `prueba_52.py`, `prueba_temp.py` | checks of the measurement itself: the monitor's cost, the VIC-II's stolen cycles, a frame step by step, the checkpoints' behaviour |
| `src/c64/juego_final/perfil64.py`, `categorias64.py`, `ciclos_categorias.py`, `usados64.py`, `vice/mide.py`, `vice/perfil_irq.py` | the profile by routine and by module, what the game never uses, the speed in emulated time, a statistical profile in VICE |

I kept only the instruments: the scripts that wrote each round's report from its runs are not here; the rounds'
figures are in `doc/ESTADO.md`.

## Size

| Tool | What it does and how |
|---|---|
| `tools/mide_cc65.py`, `tools/mide_juego.py` | how big the game's C would be compiled by cc65 for the C64 (the reason the game is in assembler) |
| `tools/prototipos64.py`, `tools/resultados64.py`, `tools/condiciona.py` | the C prototypes of every function; the routines' declared results merged; one ca65 source with two versions under `.ifdef` |

## The videos: `src/c64/video/`

| Tool | What it does and how |
|---|---|
| `piloto.py`, `meta_adso.c`, `cargar_piloto.py`, `actualizar_en_vivo.py` | my automatic player: it gives William and Adso destinations only, from the game's state, and presses the real keys; it can be updated in a running recording |
| `genera_sesion64.py`, `genera_sesion128.py`, `genera_sesion500.py`, `sesion*.py`, `ayudas.py` | the sessions: VICE driven through its binary monitor from the start menu to the ending, for each machine (generated one from another with counted replacements) |
| `graba64.sh`, `graba128.sh`, `graba500.sh` | the recording in real time on a virtual display |
| `monta.py`, `entrega.py`, `textos.py`, `miniaturas.py`, `cambia_portada.py`, `empaqueta.py`, `captura_carga*.py`, `ordenador_p500.py` | the cut with its title card and chapters, the YouTube kit (text, thumbnail, zip), a new title card put into a finished video without encoding it again |

## Keeping the project

| Tool | What it does and how |
|---|---|
| `tools/licencia.py` | my licence header on every text file in its own comment syntax (`--git`: every tracked file; `--comprueba`: only list the ones without it); the files that hold something of the original game get the header's other form, which says so |
| `tools/wiki.py`, `tools/wiki_github.py` | the wiki made from its templates with every code excerpt taken from the sources at build time (`--check`: which pages are out of date), and published to the GitHub wiki in both languages |
| `tools/c64_editor.py` | my pixel editor: the PC EGA graphic beside the C64 one, the edits saved to `src/c64/datos/editados64.txt` |
| `tools/sincroniza.sh`, `tools/vice_remoto.sh`, `tools/teclea_p500.py` | the project copied to my other machines (`tools/maquinas.conf`, not in the repository), VICE started on another machine's desktop, lines typed into the P500 |

Before each commit I run `tools/licencia.py --comprueba --git` and `tools/wiki.py --check`.
