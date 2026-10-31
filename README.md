# abadiacbm — La abadía del crimen for Commodore computers

*La abadía del crimen* (The Abbey of Crime; Paco Menéndez and Juan Delcán, Opera Soft, 1987) for the Commodore 64,
the Commodore 128 and the Commodore P500, written in 6502 assembler as a faithful translation of the original Z80
program and certified frame by frame: the C64 game against the CPC original, the C128's against the PC rebuild (the
P500 runs the C128's game on its own machine layer).

**Downloads, videos and news: [abbeyofcrime.com](https://abbeyofcrime.com).**

| Release | Machine | Media | What it is |
|---|---|---|---|
| **abadia64ks** | Commodore 64 | tape (`.tap`) and disk (`.d64`) | the Amstrad CPC 64 KiB tape version: its map, rules, clock, monks and puzzles; Spanish and English chosen in a start menu |
| **abadia128ks** | Commodore 128 (C128 mode) | disk (`.d64`) | the full game (the map and rules of the CPC 6128 and PC versions), hires heads with the VIC-II's sprites, 2 MHz in the borders, the whole game in memory, the digitised Ave Maria; Spanish and English |
| **abadia128ks for the P500** | Commodore P500 (CBM-II 510, 128 KiB) | disk (`.d80` for an 8050, `.d64` for a 2031 or 4040) | the same full game on the MOS 6509: the game in bank 0, the rooms, texts, faces' masks and Ave Maria in bank 1, the chips in bank 15, reached with the 6509's cross-bank instructions; hires heads, the Ave Maria; Spanish and English |

The current releases are in the repository, built from these sources: `src/c64/cinta/abadia64ks.tap`,
`src/c64/disco64/abadia64ks.d64` and `src/c64/disco128/abadia128ks.d64` (both disks work with a 1541 or a 1571 drive),
`src/c64/discop500/abadia128ks_p500.d80` and `.d64`; their packages with instructions are on
[abbeyofcrime.com](https://abbeyofcrime.com).

**How the game works**, part by part with the code: the wiki in [`doc/wiki/Home.md`](doc/wiki/Home.md), also on this
repository's [wiki](https://github.com/garacil/abadiacbm/wiki) (`tools/wiki_github.py`).

## Layout

| Directory | Contents |
|---|---|
| `src/c64/` | the 6502 game (`juego_final/`), its platform layer (`plataforma/`), the tape and the game's stream with its loader tools (`cinta/`, `cinta/FLUJO.md`), the C64 disk (`disco64/`), the C128 disk (`disco128/`), the P500 disks (`discop500/`), the presentation and ending (`presentacion/`, with its test disk in `pruebas/disco_prueba/`), the certification (`certifica/`), the video sessions (`video/`), notes and tests |
| `src/juego/` | the original program translated to C, function by function: the host that runs the Z80 original and the 6502 build side by side for the certification |
| `tools/` | the project's tools: graphics conversion and pixel editor (`c64_graficos.py`, `c64_editor.py`), the data generators, the comparators, the synchronisation of the machines |
| `tools/terceros/` | third-party tools, **not in the repository** (below) |
| `data/` | the original game's data (the CPC tape images and memory dumps, the full game's map), the recorded sessions and reference states the checks use |
| `doc/` | the project's working reference (`PROYECTO.md`: releases, builds and checks, machines, design, videos, rules), the work log (`ESTADO.md`), the milestones (`HITOS.md`), the cuts (`RECORTES.md`), the references of the machines (`referencias/`), the reviews against the CPC with their pictures (`revisiones/`) |

## Building

Requirements: Python 3 with Pillow, GCC and make, and in `tools/terceros/`:

* `cc65/` — cc65 V2.19 (https://github.com/cc65/cc65), built there (`tools/terceros/cc65/bin/ca65`, `ld65`, `cl65`);
* `exomizer/` — Exomizer 2.0.9 (the source archive https://github.com/bitshifters/exomizer), built in
  `tools/terceros/exomizer/exomizer2/src/`.

Then, each release from its own directory:

    src/c64/cinta/construye.sh        # abadia64ks.tap (and every C64 image)
    src/c64/disco64/construye.sh      # abadia64ks.d64
    src/c64/disco128/construye.sh     # abadia128ks.d64
    src/c64/discop500/construye.sh    # abadia128ks_p500.d80 and .d64

Every build is deterministic: the same sources give the same images, byte for byte.

## Checking

VICE 3.10 (`x64sc`, `x128`, `xcbm5x0`) runs the tests:

    src/c64/cinta/prueba_cinta.py OUT [--disco [--unidad 1541|1571]] [--opciones KEYS] [--final]   # the tape / the C64 disk
    src/c64/disco128/prueba128.py OUT [--opciones KEYS] [--final|--guarda] [--unidad 1571|1541]     # the C128 disk
    src/c64/certifica/lote.sh BUILD OUT N SESSION...                           # the C64 game against the CPC original
    src/c64/certifica/pc/lote.sh BUILD PC_BUILD OUT FRAMES N SEED...           # the C128 game against the PC rebuild
                                                                               # (PC_BUILD: outside this repository)

## Credits

*La abadía del crimen*: Paco Menéndez (author), Juan Delcán (graphics and cover), Opera Soft, 1987; after Umberto
Eco's novel *The Name of the Rose*.

The Commodore versions: Germán Luis Aracil Boned, 2016-2026 — garacilb@gmail.com — https://abbeyofcrime.com

The project began in September 2016 with the presentation's parchment program in C (cc65).

The code is free software under the GNU General Public License, version 3 or later (`COPYING`).  The original
game's graphics, texts, music and data belong to their authors.

---

**En español.**  *La abadía del crimen* para Commodore 64 (abadia64ks: la versión de cinta de 64 KiB del Amstrad
CPC, en cinta y en disco), Commodore 128 (abadia128ks: el juego completo, en disco) y Commodore P500 (el mismo juego
completo, en disco), en ensamblador 6502, traducción fiel del programa original del Z80 y certificada contra él
fotograma a fotograma.  Descargas, vídeos y novedades: [abbeyofcrime.com](https://abbeyofcrime.com).
Español e inglés en cada edición.
Versiones para Commodore de Germán Luis Aracil Boned.
