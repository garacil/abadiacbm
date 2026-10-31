# The loading picture, CPC against C64

The abbey's loading picture could be better: compared with the Amstrad's.

## The reference

`cpc_pantalla.py` shows the tape's picture in the Caprice32 (control socket, Xvfb :99): the memory of the block
20h (`data/cpc64/cinta/juego.bin`, the screen C000h-FFFFh) with the loader's display (mode 0, the inks of its table
at 0103h, `tintas.txt`; R1 = 32, R2 = 43, R6 = 24 as 01E9h writes them), the Z80 held in a JR $: `cpc_caprice32.png`.

## What was wrong

1. **The picture's pens were decoded wrong.**  `pantalla.py` read a mode 0 pixel as pen bits 0-3 = byte bits 7-i,
   5-i, 3-i, 1-i; the CPC's are 7-i, **3-i, 5-i**, 1-i (bits 1 and 2 the other way round).  Measured:
   `analiza.py` finds Caprice32's screenshot to hold, pixel for pixel, the 24 576 pixels decoded the CPC's way; the old
   way matched 63 % of a sample.  So every pen with bit 1 different from bit 2 was another pen: the dark red (1C) of
   the letters and the monk's sleeve came out as mauve (light blue on the C64), the bright red (0C) of the cloth as
   pastel yellow (yellow), the grey (00) as orange, the white as dark cyan (cyan), ...: 9671 of the 24 576 pixels
   (39 %) were not the nearest colour of their true pen.
   (The same swap is in the GNU front-end's `dibuja()`, src/juego/gnu/abadia64ks.c, and in
   tools/cpc_carga.py's screenshots: not changed here, outside src/c64/disco.)
2. **The colours were judged on VICE's pepto palette with CIE Lab distances (CIE76)**, which sends saturated colours
   to the wrong hues; a real C64 is closer to colodore (`colodore.vpl`), and CIEDE2000 weighs hue and chroma as the eye
   does (checked against Sharma's test data, pair 1: 2.0425).

## The conversion now (`doc/revisiones/pantalla_carga/pantalla.py`)

* The pens decoded as the CPC does.
* Each CPC pen one C64 colour for the whole picture (`asignacion`): the nearest by CIEDE2000 on colodore, but where
  two pens drawn side by side would become one colour, the choice that loses the least (the sum over the pixels of
  their distance plus, for each pair of neighbouring pixels of different pens made one colour, the distance between
  the two CPC colours).  It changes one thing: the robe's dark cyan (06, 1106 pixels; nearest C64 colour grey) is dark
  grey, else it merges with the robe's grey (00) along 379 edges and the folds go.  The three CPC reds (dark red 1C,
  red 0C, pink 07) have two C64 colours: the dark red red, the red and the pink both light red (their 258 shared
  edges, on the hands and the face, are lost: giving the red C64 red instead loses the cloth's and the bricks' shading
  against the dark red, and costs more).
* $D021 black: the picture's most used colour (48 %), and the best of the 16 (`analiza.py`: the mean distance with
  each colour as $D021 and every cell's best 3 others: black 5.83, red 5.92, light red 5.93, cyan 5.94); it must be
  black anyway for the cells outside the picture, which hold the game's data while it loads.
* Each 4 x 8 cell: the 3 colours (black is $D021) that keep its pens' colours, and in a cell with more (68) the
  substitutes that add the least distance (each pixel then the nearest of the 4).  No dithering.
* The load's look is the same scheme: pink in a free slot or lent by the cell's least used colour (82 cells now, 97
  before), the fixes when the picture is complete (165 bytes of the stream, 195 before); `flujo.py`'s model of the
  loader and `prueba.py` check it (the screen memory at each stop equal to the model's).

## The numbers (`analiza.py`, `analisis.txt`)

On colodore, against the CPC picture (128 x 192 pixels):

| | before | after |
|---|---|---|
| mean CIEDE2000 of the pixels | 18.83 | 6.05 |
| pixels whose colour is not the nearest of their CPC pen's | 9671 | 1223 (1046 of them the robe's dark cyan as dark grey, on purpose; 203 substitutes in the 68 crowded cells) |
| cells whose pens' nearest colours are more than 3 besides black | (65, counted with the wrong pens) | 61 (68 with the robe's dark grey) |
| CPC edges lost (neighbouring pixels of different pens made one colour) | 246 of 12 683 | 468 of 12 683 (the pink and red: 258) |
| cells lending a colour to the pink while loading | 97 | 82 |

(Before lost fewer edges only because its colours were scrambled: different pens rarely fell on one colour.)

Each pen's C64 colour (most of its pixels), before -> after: 1C dark red light blue -> red; 0C red yellow -> light red;
07 pink light red -> light red; 00 grey orange -> grey; 0B white cyan -> white; 06 dark cyan white -> dark grey; 1B
pastel cyan cyan -> cyan; 0E orange grey -> orange; 04 blue blue -> blue; 1F pastel blue light blue -> light blue; 03
pastel yellow light red -> yellow; 14 black black -> black.

## Pictures

* `comparacion.png`: the CPC (its colours) | the C64 before | the C64 after, 3 x, the C64's on colodore.vpl's colours.
* `detalle.png`: the face and the hand, 6 x, in the same order.
* `cpc_caprice32.png`: Caprice32's screenshot.
* `antes_6_imagen_completa_vice_por_defecto.png`, `despues_6_imagen_completa_vice_por_defecto.png`: `prueba.py`'s
  VICE picture of the complete picture before and after (VICE's own default palette, which is neither pepto nor
  colodore: its red shows as 175,60,88).

## What still differs, and why

* The C64 has two reds for the CPC's three, no dark teal, no saturated red: light red stands for the bright red
  (CIEDE2000 16.5), dark grey for the dark teal (26.7).
* 68 cells hold more than 3 colours besides black: 203 pixels take a substitute.

## The tools

| | |
|---|---|
| `cpc_pantalla.py OUT.png` | the CPC's picture in Caprice32 |
| `analiza.py OUTDIR [CPC.png]` | the numbers above, the pictures; CPC.png is checked pixel for pixel |
| `color.py` | CIE Lab, CIEDE2000, the palettes |
| `antes/` | `pantalla.py` and `carga.c` before the change |
