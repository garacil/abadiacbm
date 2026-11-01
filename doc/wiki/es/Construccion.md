<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Construccion.md: se edita la plantilla, no esta página. -->
# Construcción y certificación

[Inicio](Inicio.md) · anterior: [Presentación y final](Pergaminos.md) · siguiente: [Gráficos y herramientas](Graficos.md)

## La cadena de construcción

Todo se genera a partir de las fuentes y de los datos del juego original, de forma determinista: las mismas fuentes dan
la misma cinta y los mismos discos, byte a byte.

1. **Los gráficos**: `tools/c64_graficos.py` convierte cada gráfico del juego del CPC a los formatos del C64 (y aplica
   los retoques a mano de `src/c64/datos/editados64.txt`), en `data/c64graf/`.
2. **El mapa de memoria**: `mapa64.py` coloca cada bloque de datos; `punteros64.py` encuentra los campos de puntero;
   `datos64.py` escribe la imagen de los datos como segmentos de ca65 y la configuración del enlazador (ver
   [Mapa de memoria](Mapa-de-memoria.md)).
3. **Los guiones**: `guiones64.py` traduce los guiones del Z80 de los monjes al código de bytes de la máquina virtual
   (ver [La mente de los monjes](Monjes.md)).
4. **El juego**: ca65 y ld65 ensamblan y enlazan las fuentes 6502 y los datos en una sola imagen de 64 KiB.
5. **La edición**: la presentación y el final (cc65), el flujo o los ficheros comprimidos, el menú, la imagen de la
   cinta o del disco.

[`src/c64/juego_final/construye.sh`](../../../src/c64/juego_final/construye.sh#L17-L27), líneas 17–27:

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

Las mismas fuentes construyen todas las variantes con condicionales: `C64=1` la máquina real (sin él, la construcción
para el anfitrión de comprobación), `CINTA=1` la cinta, `DISCO=1` el disco del C64, `C128=1` el Commodore 128, `P500=1`
el Commodore P500, `IDIOMA=en` el inglés; las del C128 y del P500 añaden `-D COMPLETO` y `-D VELOZ`.

## Tres niveles de comprobación

**1. Cada rutina, en cada llamada.**  El anfitrión híbrido (`src/juego/hibrido`) ejecuta el programa original del Z80 y,
en cada llamada a una función que tiene traducción al 6502, ejecuta también la rutina 6502 en un núcleo 6502 (el sim65
de cc65), desde el mismo estado pasado al mapa del C64, y compara: los registros y las banderas que devuelve la función
y cada bloque de datos.  `comprueba.sh` lo hace con las ocho sesiones grabadas (y con `--largos`, con dieciséis largas):

[`src/c64/juego_final/comprueba.sh`](../../../src/c64/juego_final/comprueba.sh#L17-L24), líneas 17–24:

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

**2. El juego entero, fotograma a fotograma.**  Con `--juego` el anfitrión ejecuta todo el juego 6502 desde su entrada,
al paso del Z80, y compara toda la memoria en cada fotograma; `dias.sh` lo arranca en cada día y cada hora del juego (49
estados) y juega hasta el final del 100 %.

**3. La máquina real contra el original.**  `src/c64/certifica/certifica.py` ejecuta la construcción real del C64 en
VICE con las mismas teclas que el Z80 original, el mismo byte aleatorio y el mismo modelo de interrupción, y compara en
cada fotograma toda la RAM del C64 con la memoria del CPC a través del mapa:

[`src/c64/certifica/certifica.py`](../../../src/c64/certifica/certifica.py#L1-L8), líneas 1–8:

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

El juego completo del C128 se certifica igual contra mi reconstrucción de la versión de PC (`src/c64/certifica/pc/`),
que juega el juego completo y que a su vez verifiqué fotograma a fotograma contra el original de PC: sesiones al azar de
4000 fotogramas, 0 diferencias.  Y el del P500 también: `corre500.py` arranca el propio disco del P500 en el xcbm5x0 de
VICE como lo haría un jugador (el menú, el pergamino, el cargador, la etapa del banco 1) y después, en cada fotograma,
pone las mismas teclas y vuelca el banco 0 y los datos del banco 1.  Cuatro sesiones al azar de 6000 fotogramas (pasadas
las primeras completas, con el abad persiguiendo a Guillermo y las puertas abriéndose y cerrándose), 237 datos
comparados en cada fotograma, 0 diferencias: el P500 juega exactamente la misma partida que el PC original.

[`src/c64/certifica/pc/corre500.py`](../../../src/c64/certifica/pc/corre500.py#L17-L27), líneas 17–27:

```python
"""abadia128ks on the P500 against the PC (as corre128.py for the C128): the P500's own disk started in xcbm5x0 as a
player would (c64/video/sesion500.py's Visible: DLOAD"ABADIA" and RUN, the menu with everything on and Spanish, the
parchment, the loader, the stage in bank 1), up to the game's principal_inicio; then at every frame
(game_input_and_mirror's entry) bank 0 and bank 1's data from $1000 (juego.bin.banco1's length) are appended to OUT,
and right after sys_read_keyboard (game_input_and_mirror + 3) the CPC keys of the frame (KEYS: lines "f k k ...", as
arnes.c reads them) are held: their bits cleared in D64_SYS_KEYS_DOWN and, for a new press, in D64_SYS_KEYS_PENDING.
A frame not reached in 30 s ends the run (the game over's wait, or a hang: said so).  compara.py takes its dump as it
takes the C128's.

    corre500.py JUEGO_DIR KEYS FRAMES OUT       (JUEGO_DIR: c64/juego_final/p500; the disk: c64/discop500's .d80)
"""
```

## Las pruebas de las ediciones

Las propias ediciones se prueban en VICE, desde la cinta o el disco, como las arrancaría un jugador:

| Prueba | Qué comprueba |
|---|---|
| `src/c64/cinta/prueba_cinta.py SALIDA [--opciones TECLAS] [--final]` | la cinta: el menú, cada bloque cargado, la memoria del juego en su primera instrucción igual a su imagen, las opciones (las notas del paso y del pitido en silencio), el final cargado de la cinta |
| `prueba_cinta.py SALIDA --disco [--unidad 1541\|1571]` | lo mismo en el disco del C64, con cada unidad |
| `src/c64/disco128/prueba128.py SALIDA [--opciones 1234] [--final\|--guarda] [--unidad 1571\|1541]` | el disco del C128: el arranque, los dos bloques de memoria, las opciones, grabar y cargar, el final; con cada unidad |
| `src/c64/presentacion/pruebas/disco_prueba/prueba.py` | las páginas y la música de los pergaminos, la imagen durante la carga |

`tools/genera_todo.sh --prueba` construye las ediciones de C64 y C128 y ejecuta estas pruebas.
