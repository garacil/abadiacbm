<!-- Made by tools/wiki.py from doc/wiki/fuentes/Building.md: edit the template, not this page. -->
# Building and certification

[Home](Home.md) · previous: [Presentation and ending](Parchments.md) · next: [Graphics and tools](Graphics.md)

## The build chain

Everything is generated from the sources and the original game's data, deterministically: the same sources give the
same tape and disks, byte for byte.

1. **The graphics**: `tools/c64_graficos.py` converts every graphic of the CPC game to the C64's formats (and applies the
   hand edits from `src/c64/datos/editados64.txt`), into `data/c64graf/`.
2. **The memory map**: `mapa64.py` places every data block; `punteros64.py` finds the pointer fields; `datos64.py` writes
   the data image as ca65 segments and the linker's configuration (see [Memory map](Memory-map.md)).
3. **The scripts**: `guiones64.py` translates the monks' Z80 scripts into the VM's bytecode (see [The monks' minds](Monks.md)).
4. **The game**: ca65 and ld65 assemble and link the 6502 sources and the data into one 64 KiB image.
5. **The release**: the presentation and the ending (cc65), the stream or the crunched files, the menu, the tape or
   the disk image.

[`src/c64/juego_final/construye.sh`](../../src/c64/juego_final/construye.sh#L17-L27), lines 17–27:

```bash
# The 6502 game for the hybrid host's checks: juego.bin (the 64 KiB image from $0000: zero page, data, code from
# $0800) and juego.lbl (ld65's VICE label file: the routines' addresses; with PERFIL=1 also juego_todo.lbl,
# every label, the local ones too, for perfil64.py); with C64=1 the C64's game in c64/
# (the same image with the real platform layer, principal.s without its check hooks; FINAL is implied).
#   mapa64.py   bloques64.tsv + data/c64graf/graficos64.tsv -> mapa64.tsv, mapa64.inc (the memory map)
#   punteros64.py (tools)                       -> punteros64.tsv (the pointer fields)
#   datos64.py  the map, the pointers, the tape image, the converted graphics -> datos64.s, juego.cfg,
#               conversion64.tsv
#   stubs64.py  stubs64.s, stubs64.tsv: a trap for each function called but not translated (FINAL=1: none allowed)
# The graphics (data/c64graf) are made by tools/c64_graficos.py; the inventory checks by
# tools/inventario64.py (c64/NOTAS_MAPA.md).
```

The same sources build every variant through conditionals: `C64=1` the real machine (without it, the build for the
checking host), `CINTA=1` the tape, `DISCO=1` the C64 disk, `C128=1` the Commodore 128, `IDIOMA=en` English; the C128
build adds `-D COMPLETO` and `-D VELOZ`.

## Three levels of checking

**1. Every routine, at every call.**  The hybrid host (`src/juego/hibrido`) runs the original Z80 program, and at every
call of a function that has a 6502 translation it also runs the 6502 routine on a 6502 core (cc65's sim65), from the
same state converted to the C64's map, and compares: the registers and flags the function returns, and every data
block.  `comprueba.sh` does it for the eight recorded sessions (and `--largos` for sixteen long ones):

[`src/c64/juego_final/comprueba.sh`](../../src/c64/juego_final/comprueba.sh#L17-L24), lines 17–24:

```bash
# The checks of the integrated 6502 build (c64/TRADUCCION6502.md, "Check"): juego/hibrido with every translated
# routine in shadow (--6502 this directory --solo-6502), or with --juego the whole 6502 game from its entry in
# step with the Z80, its memory compared at every frame (--juego6502: juego6502.tsv says what is left out).
#   comprueba.sh [--juego] [--largos] [OUTDIR]
#     default: the 8 sessions data/cpc64/exploracion/azarN.txt to frame 4472; --largos: the 16 long scripts
#     data/guiones_largos/largo1NN.txt to frame 20472.  OUTDIR (default: a temporary directory): out_<script>.txt
#     (the host's output), ciclos_<script>.tsv (the 6502 cycles per routine).
# Prints the host's summary per run and the differences per routine; exits 1 if any.
```

**2. The whole game, frame by frame.**  With `--juego` the host runs the whole 6502 game from its entry in step with the
Z80, and compares the whole memory at every frame; `dias.sh` starts it at every day and hour of the game (49 states) and
plays to the 100 % ending.

**3. The real machine against the original.**  `src/c64/certifica/certifica.py` runs the real C64 build in VICE with the
same keys as the original Z80, the same random byte and the same interrupt model, and compares at every frame the C64's
whole RAM with the CPC's memory through the map:

[`src/c64/certifica/certifica.py`](../../src/c64/certifica/certifica.py#L1-L8), lines 1–8:

```python
"""The certification of the C64 game against the CPC 64 KiB original (the whole game
certified: the monks' behaviour of the Amstrad CPC 64 KiB original and of this C64 version the same, the objects
appearing where and when they must, every room walkable): the hybrid host runs the CPC's Z80 from a
start state with a key script, and in step with it the real C64 build in VICE (vice_cert.py) gets the same keys, the
same R and the host's interrupt model; at every frame the host compares the C64's whole RAM with the Z80's memory
through the build's own memory map (every data block of mapa64.tsv: the characters, their AI state and commands, the
objects and their holders, the doors, the clock, the scripts' variables, the sound state...), with the exclusions of
c64/juego_final/juego6502.tsv.
```

The C128's full game is certified the same way against the PC version's rebuild (`src/c64/certifica/pc/`), which plays
the full game and was itself verified frame by frame against the PC original: random sessions of 4000 frames, 0
differences.

## The tests of the releases

The releases themselves are tested in VICE, from the tape or the disk as a player would start them:

| Test | What it checks |
|---|---|
| `src/c64/cinta/prueba_cinta.py OUT [--opciones KEYS] [--final]` | the tape: the menu, every block loaded, the game's memory at its first instruction equal to its image, the options' NOPs, the ending loaded from the tape |
| `prueba_cinta.py OUT --disco [--unidad 1541\|1571]` | the same on the C64 disk, with each drive |
| `src/c64/disco128/prueba128.py OUT [--opciones 1234] [--final\|--guarda] [--unidad 1571\|1541]` | the C128 disk: the boot, both blocks of memory, the options, saving and loading, the ending; with each drive |
| `src/c64/presentacion/pruebas/disco_prueba/prueba.py` | the parchments' pages and music, the picture during the load |

`tools/genera_todo.sh --prueba` builds the three releases and runs these tests.
