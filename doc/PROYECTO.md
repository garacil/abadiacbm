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

# abadiacbm — my working reference

What I need to carry the project on: the releases, how I build and prove them, how I keep my machines in step, the
decisions behind each release, the videos, and the rules I keep to.  The history is in `ESTADO.md`, the milestones in
`HITOS.md`, every tool and how it works in `HERRAMIENTAS.md`, the machines' official facts in `referencias/`
(`referencias/INDICE.md`).

## The releases

| Release | File | sha256 (first 12) | Download zip (abbeyofcrime.com) |
|---|---|---|---|
| abadia64ks, Commodore 64, tape | `src/c64/cinta/abadia64ks.tap` | `b71b0054bb14` | `abadia64ks_c64.zip` (tape + disk + README) |
| abadia64ks, Commodore 64, disk | `src/c64/disco64/abadia64ks.d64` | `2aab55a407e8` | (the same zip) |
| abadia128ks, Commodore 128, disk | `src/c64/disco128/abadia128ks.d64` | `ee42c9e23e9d` | `abadia128ks_c128.zip` (disk + README) |
| abadia128ks, Commodore P500, disk for an 8050 | `src/c64/discop500/abadia128ks_p500.d80` | `3ed50bd6bcfe` | `abadia128ks_p500.zip` (both disks + README) |
| abadia128ks, Commodore P500, disk for a 2031 / 4040 | `src/c64/discop500/abadia128ks_p500.d64` | `ece905579358` | (the same zip) |

* The zips are made by `src/c64/video/empaqueta.py OUT.zip [--c128 | --p500]` with `src/c64/video/entrega/README.txt` /
  `README500.txt` (the P500's) /
  `README128.txt` (English and Spanish, signed by me).  Links: `https://abbeyofcrime.com/download/abadia64ks_c64.zip`,
  `https://abbeyofcrime.com/download/abadia128ks_c128.zip`.
* I keep only the current releases; I deleted the older ones.  Both disks work with a 1541 and a 1571.
* Every build is deterministic: rebuilding from these sources gives the files above byte for byte (checked after the
  reorganisation).

## Building and proving

    src/c64/cinta/construye.sh          # the C64 tape (and the C64 game images, both languages)
    src/c64/disco64/construye.sh        # the C64 disk
    src/c64/disco128/construye.sh       # the C128 disk (game -D C128 -D COMPLETO -D VELOZ, both languages)
    src/c64/discop500/construye.sh      # the P500 disks (game -D C128 -D P500 -D COMPLETO -D VELOZ, both languages)

Third-party tools in `tools/terceros/` (not in the repository, README): cc65 2.19, Exomizer 2.0.9.  VICE 3.10 for
the tests (`x64sc`, `x128`); the tests use Xvfb `:99`.

| Check | Command | Passes when |
|---|---|---|
| tape | `src/c64/cinta/prueba_cinta.py OUT [--opciones KEYS] [--final]` | all checks passed |
| C64 disk | `prueba_cinta.py OUT --disco [--final] --unidad 1541` and `--unidad 1571` | both drives |
| C128 disk | `src/c64/disco128/prueba128.py OUT [--opciones 1\|234] [--final\|--guarda] --unidad 1571` and `--unidad 1541` | both drives |
| C64 game against the CPC | `src/c64/certifica/certifica.py BUILD OUT NAME data/cpc64/inicio_juego/ram.bin data/cpc64/exploracion/NAME.txt FRAMES` | 0 differences |
| C128 game against the PC rebuild | `src/c64/certifica/pc/lote.sh src/c64/juego_final/c128 PC_BUILD OUT FRAMES N SEED...` (PC_BUILD from `src/c64/certifica/pc/construye.sh`, the PC rebuild outside this repository) | 0 differences |
| P500 game against the PC rebuild | `CORRE=corre500.py src/c64/certifica/pc/lote.sh src/c64/juego_final/p500 PC_BUILD OUT FRAMES N SEED...` (the P500's own disk in xcbm5x0, its menu, parchment and loader, up to the game) | 0 differences (4 random sessions of 6000 frames, past the first completas: 237 data a frame) |

Rules: any change to `src/c64/plataforma/c128.s`, the disks or the loaders is tested with both drives (
they must work with both drives).  The defaults (Spanish, every sound on) are the original game; the
certifications run with them.

## My machines

I work on one PC and keep the project, at the same place in my home directory, on two more: one for backups and tests
(the videos' kits on its Desktop), the other a second workstation.

* `tools/sincroniza.sh` copies the project to the machines named in `tools/maquinas.conf` (a name, an SSH host, and its
  VPN address a line; not in the repository), with rsync, never deleting, the recordings and `__pycache__` left out.
  `src/c64/datos/editados64.txt` (the graphic edits) is compared first: the newer one wins and the other is kept in
  `respaldos/<date>/`.  `tools/vice_remoto.sh MACHINE FILE [EMULATOR]` starts VICE on another machine's desktop, its
  binary monitor on that machine's VPN address only.
* The repository: GitHub `garacil/abadiacbm`, public, branch `main`; every machine has the same working tree.  The
  commits are mine (`Germán Luis Aracil Boned <garacilb@gmail.com>`).  Not in the repository: `respaldos/`, the
  recordings, `tools/terceros/`, `tools/maquinas.conf`, build outputs (`.gitignore`).

## Graphics

* `tools/c64_editor.py` (PySide6): the PC EGA graphic beside the C64 one, pixel editing, animation of Guillermo and
  Adso, the background tiles; it writes `src/c64/datos/editados64.txt`, which `tools/c64_graficos.py` applies.
* My rules: the existing graphics are not changed; new graphics needed by the full game are converted the same
  way as the existing ones, and the 64ks and 128ks releases share the same tiles (no difference in the common ones);
  the bricks of tile 0A are all orange.

## The releases' design

**abadia64ks (Commodore 64, tape and disk).**  The Amstrad CPC 64 KiB tape version translated to 6502, certified
against the Z80 original.  Start menu: 1 language (español / English), 2 footsteps, 3 text sound; the texts of the
language chosen are loaded from the tape; a sound off is its sequence's note made a rest (the game plays it as the
original, silent: the footsteps still end the music, a phrase still cuts it).  Save and load on tape or disk.  No hires heads: there is no RAM left for the masks, the sprites and
their code.

**abadia128ks (Commodore 128, C128 mode, disk).**  The full game: the map, rooms and rules of the CPC 6128 / PC
version (data from the PC rebuild, kept in `data/completo/`; tiles in `data/c64graf128`).  Every head in high
resolution: its black strokes are a hires hardware sprite of the VIC-II (a black mask) over the multicolour bitmap
(`src/c64/juego_final/cabezas128.s`), also in the dark rooms with the lamp (the heads merged into the
light's rectangle are registered too).  2 MHz while the beam is in the borders; texts and data in block 1; speed work
under `-D VELOZ`.  Start menu with 4 the Ave María at compline (the PC's digitised voice).  The disk loads everything
at once, file by file, crunched; save and load on disk, ten slots.  The ending: `plat_final` puts back the KERNAL's
interrupt code and vectors in RAM ($FF05-$FF44, $FFFA-$FFFF, as the KERNAL's $E0CD does) before loading FINAL, or a
1541's slow load ends in the game's code.

**abadia128ks on the Commodore P500.**  The C128's full game on the CBM-II 510 with 128 KiB (`-D C128 -D P500`): the
game in bank 0, its rooms, texts, the heads' blacks and the Ave Maria in bank 1, the I/O in bank 15, all through the
6509's two cross-bank instructions; the menu, the parchment and the loader in cc65's cbm510 target; disks for the 8050
(D80) and the 2031/4040 (D64), loaded with SHIFT + RUN/STOP (`src/c64/discop500/NOTAS.md`, the machine's facts in
`doc/referencias/p500.md`).

## The videos

Tools in `src/c64/video/` (run as my user, not as root):

* `genera_sesion64.py` / `genera_sesion128.py` make `sesion64.py` / `sesion128.py`: VICE driven through its binary
  monitor (127.0.0.1 only), the game played from the start menu to the ending parchment by the automatic player
  (`piloto.py`, `meta_adso.c`): it gives Guillermo and Adso destinations only; the keys are the real ones and nothing is
  set by hand.  Rehearsal: `sesion128.py --idioma es|en --ensayo-vice --salida DIR` (warp).
* `genera_sesion500.py` makes `sesion500.py` from `sesion128.py` for the P500 (xcbm5x0, the 8050 disk, DLOAD and RUN
  typed, the menu's and the parchment's keys into cc65's buffer, the planner in a second VICE also in the rehearsal:
  VICE's xcbm5x0 restores a snapshot without its interrupt).
* `graba64.sh` / `graba128.sh` / `graba500.sh LANG DISPLAY PORT` record in real time (Xvfb `:95`/`:96`, ports 6517/6516, about two
  hours), into `src/c64/video/grabaciones/` (not in the repository).
* `entrega.py RECORDING VIDEO.mkv es|en [--c128 | --p500]` makes the kit into `~/Escritorio/abbeyofcrime/c64`, `c128` or
  `p500` (`ABADIA_ENTREGA` names another place; the P500's title card and thumbnail with a photograph of the computer
  when `ABADIA_FOTO_P500` names one, an RGBA PNG transparent around the case, not in the repository, or else the
  computer drawn by `ordenador_p500.py`; its loading picture from `captura_carga500.py`): the
  title card (7 s), the cut video at 1920x1080 with its chapters, the thumbnail, the text (`textos.py`: title,
  description signed by me, with the download links, chapters, credits, tags, in the video's language) and
  the zip.  I mirror the kit to my test PC's Desktop and check it by sha256.
* The language is called «español» (on the C64 screens «ESPANOL»), never «castellano».

## The wiki

`doc/wiki/` explains how the game works, part by part, with excerpts of the code: in English (from `Home.md`) and in
Spanish (`doc/wiki/es/`, from `Inicio.md`).  `tools/wiki.py` makes the pages from the templates in `doc/wiki/fuentes/`
and `doc/wiki/es/fuentes/`: every excerpt is taken from the sources when the wiki is built, so `tools/wiki.py --check`
after a change of the code says which pages must be made again; `tools/wiki_github.py` publishes both languages in the
repository's GitHub wiki.

## My rules

* Every hardware fact (addresses, cycles, KERNAL routines, drive protocol) is taken from official documentation or
  measured in the machine, never assumed; the sources are recorded in `doc/referencias/`.
* Everything is proved: builds compared byte for byte, the tests above, the certifications with 0 differences.
* Nothing broken is shipped; nothing is deleted without a decision to delete it.
* The repository holds only the current Commodore releases and their sources and tools: no PC release and no old
  material.
* Before each commit: `tools/licencia.py --comprueba --git` (my licence header on every text file) and
  `tools/wiki.py --check` (the wiki up to date with the code).
