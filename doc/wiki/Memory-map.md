<!-- Made by tools/wiki.py from doc/wiki/fuentes/Memory-map.md: edit the template, not this page. -->
# Memory map

[Home](Home.md) · previous: [From the Z80 to the 6502](From-Z80-to-6502.md) · next: [Main loop and timing](Main-loop.md)

The CPC 64 KiB game fills almost all of its 64 KiB: 16 KiB of screen, about 16 KiB of Z80 code and the rest data.
The C64 has the same 64 KiB, but its picture is a different format and the game's 6502 code is larger than the Z80's.
Everything fits because the map is computed, block by block, and because the C64's own screen leaves room for data.

## The C64 during the game

The BASIC and KERNAL ROMs are switched off (`$01 = $35`: RAM everywhere except the I/O at `$D000-$DFFF`); the KERNAL
comes back only to load or save from disk.

| C64 range | Use |
|---|---|
| `$0000-$0001` | the 6510's port |
| `$0002-$0023` | the Z80's registers as zero-page pairs and the scratch bytes (`zp.inc`) |
| `$0024-$009D` | the operands the Z80 code rewrites: the hottest variables |
| `$009E-$00FF` | 12 bytes for each group of routines (`camino`, `objetos_sonido`, `motor_iso`, ...) |
| `$0100-$01FF` | the 6502 stack |
| `$0200-$07FF` | the CPC's variable blocks kept whole and in CPC order (characters, sprites, doors, objects, the logic's variables, the sound's state, the keyboard), and a little 6502 code |
| `$0800-$7150` | **the code**: all the game's 6502 routines, contiguous |
| `$7151-$BFFF` | data packed downwards from `$C000`: the room table, the heights of the three floors, the blocks, the texts, the characters' graphics, the buffers, five page-aligned merge tables |
| `$C000-$C3E7` | screen RAM of the multicolour bitmap (two of the four pens of every cell) |
| `$C400-$CFFF` | the tiles' merge tables, the block interpreter's stack, the words, the height buffer |
| `$D000-$DFFF` | **under the I/O**: the tiles, the faces, the door, the day numerals, the light; read with the I/O switched off |
| `$D800-$DBE7` | (I/O) colour RAM: the third pen of every cell |
| `$E000-$FF3F` | the multicolour bitmap: the game's 256 x 192 picture |
| inside `$E000-$FFF9` | the bitmap's invisible bytes: 2042 bytes that never show, used for small tables and the sound data |
| `$FFFA-$FFFF` | the NMI, RESET and IRQ vectors (RAM: the KERNAL is off) |

## How the map is made

Nothing is placed by hand.  A table lists every data block the game needs, with its CPC address, its length, its kind
and the zone it should go to (the zero-page operands of the previous page are such rows); a generator places them:

[`src/c64/juego_final/mapa64.py`](../../src/c64/juego_final/mapa64.py#L29-L33), lines 29–33:

```python
and prints the budget.  Zones: zp from $24 (zp.inc keeps $02-$23), var $0200-$07FF, c4 $C400-$CFFF,
io $D000-$DFFF, hueco = the invisible cells of the bitmap (columns 0-3 and 36-39 of rows 0-23, row 24 and
$FF40-$FFF9: their screen RAM and colour RAM stay black, so their bytes never show), datos = packed down
from $C000; a block that does not fit its zone goes to datos.  The code lives from $0800 to the lowest datos.
"""
```

[`src/c64/juego_final/mapa64.py`](../../src/c64/juego_final/mapa64.py#L41-L48), lines 41–48:

```python
BITMAP = 0xE000
CODIGO = 0x0800
ARRIBA = 0xC000
MARCADOR = BITMAP + 320 * 20 + 32      # the score bar: bitmap rows 20-23, cells 4-35 (4 runs of 256 bytes, 320 apart)
TABLAS_C4 = ["tabla_and_tile_a", "tabla_or_tile_a", "tabla_and_tile_b", "tabla_or_tile_b"]
# graphics that also go under the I/O, after the tiles (read and flipped only with the I/O switched off)
BAJO_IO = ["caras", "puerta", "luz", "romanos"]
RESERVA_VAR = 96                       # bytes of $0200-$07FF kept free for the 6502 code's own variables
```

Its outputs are `mapa64.tsv` (one row per block: the CPC and the C64 address, and how the checks treat it) and
`mapa64.inc`, which gives every `D64_` name of the C headers its C64 address, for example
`D64_CHR_GUILLERMO = $055B ; CPC 2B87h` (Guillermo's record) or `D64_GAME_HOUR = $02A6 ; CPC 28D2h` (the hour).  Then
`datos64.py` turns the image into ca65 segments at those addresses and ld65 links code and data into one 64 KiB
image.  Every pointer field inside the data (642 of them, found by `tools/punteros64.py`) is relocated to the C64
address it points to.

On the C128 the same generator moves the room table and the texts into the second 64 KiB bank (block 1), which frees
room in block 0 for speed and for the high-resolution heads (see [The Commodore 128](C128.md)):

[`src/c64/juego_final/mapa64.py`](../../src/c64/juego_final/mapa64.py#L53-L54), lines 53–54:

```python
C128 = os.environ.get("C64_MAQUINA") in ("c128", "p500")
P500 = os.environ.get("C64_MAQUINA") == "p500"   # the P500 (CBM-II 510): the C128's layout, its own reserved bytes
```

## The screen

The CPC game draws in mode 1: 256 x 192 pixels of four colours, a byte holding four pixels, 64 bytes a line.  On
the C64 that picture becomes 128 x 192 multicolour pixels — one C64 pixel for each pair of CPC pixels, so a CPC byte
becomes a C64 nibble — centred in the 160 pixels of the screen, four cells from the left:

[`src/c64/plataforma/pantalla.s`](../../src/c64/plataforma/pantalla.s#L16-L25), lines 16–25:

```asm
; The CPC screen on the C64: wscr(addr, v) writes the CPC mode 1 byte v at CPC screen address addr
; (C000h-FFFFh, 64 bytes a line: the game's CRTC setting) into the C64 multicolour bitmap.
;
; CPC address: line in the character row (a >> 11) & 7, row ((a & 7FFh) >> 6), byte column xb = a & 63.
; C64: the 256 CPC pixels are 128 multicolour pixels centred in 160 (4 cells from the left), so the
; byte goes to cell column xb / 2 + 4, high half when xb is even; bitmap address = BITMAP + 320 row +
; 8 column + line.  The byte's 4 pixels become 2 (tabla_pantalla.inc).  Rows 25-31 (outside the
; 200 lines) are ignored.
;
; void __fastcall__ wscr(unsigned int addr, unsigned char v)
```

The four CPC pens become the four bit pairs of a multicolour cell.  A CPC ink change rewrites no pixel, as on the CPC:
it changes the background register or fills the screen RAM or the colour RAM of the game's 32 x 24 cells:

[`src/c64/plataforma/tinta.s`](../../src/c64/plataforma/tinta.s#L18-L29), lines 18–29:

```asm
; plat_tinta: A = pen 0-16 (16 = the border), X = the C64 colour (the game's palette tables hold C64 colours,
; c64/datos/paleta.tsv).  A and X kept, Y clobbered.  Needs the I/O visible ($01 = $35).
;   pen 3  -> $D021 (bit pair 00)
;   pen 0  -> the high nibble of the screen RAM of the game's 32 x 24 cells (bit pair 01)
;   pen 1  -> their low nibble (bit pair 10)
;   pen 2  -> their colour RAM (bit pair 11)
;   pen 16 -> $D020;  pens 4-15: nothing (mode 1 has four pens).
; As on the CPC no pixel is redrawn: the CPC's palette is global, so every game cell gets the same byte (the
; screen RAM byte holds both pens 0 and 1: their colours are kept here).  The cells outside columns 4-35 and
; rows 0-23 are not touched (they stay black: their bitmap bytes are data).  The fill is unrolled by rows: 24
; STA abs,X per column, 32 columns: 4000 cycles; one routine for both targets, its 24 operands' high bytes
; switched between the screen RAM ($C0-$C3) and the colour RAM ($D8-$DB) by EOR $18 when the target changes.
```

Pen 3 and the border are black in all of the game's palettes, so the cells outside the game's area, whose screen RAM
and colour RAM stay black, never show their bitmap bytes: they hold data, exactly as the CPC kept data in the hidden
part of its own screen.
