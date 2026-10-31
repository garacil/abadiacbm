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

{{code src/c64/juego_final/mapa64.py | ^and prints the budget\.  Zones | +5}}

{{code src/c64/juego_final/mapa64.py | ^BITMAP = 0xE000 | ^RESERVA_VAR}}

Its outputs are `mapa64.tsv` (one row per block: the CPC and the C64 address, and how the checks treat it) and
`mapa64.inc`, which gives every `D64_` name of the C headers its C64 address, for example
`D64_CHR_GUILLERMO = $055B ; CPC 2B87h` (Guillermo's record) or `D64_GAME_HOUR = $02A6 ; CPC 28D2h` (the hour).  Then
`datos64.py` turns the image into ca65 segments at those addresses and ld65 links code and data into one 64 KiB
image.  Every pointer field inside the data (642 of them, found by `tools/punteros64.py`) is relocated to the C64
address it points to.

On the C128 the same generator moves the room table and the texts into the second 64 KiB bank (block 1), which frees
room in block 0 for speed and for the high-resolution heads (see [The Commodore 128](C128.md)):

{{code src/c64/juego_final/mapa64.py | ^C128 = os.environ.get | +2}}

## The screen

The CPC game draws in mode 1: 256 x 192 pixels of four colours, a byte holding four pixels, 64 bytes a line.  On
the C64 that picture becomes 128 x 192 multicolour pixels — one C64 pixel for each pair of CPC pixels, so a CPC byte
becomes a C64 nibble — centred in the 160 pixels of the screen, four cells from the left:

{{code src/c64/plataforma/pantalla.s | ^; The CPC screen on the C64 | ^; void __fastcall__}}

The four CPC pens become the four bit pairs of a multicolour cell.  A CPC ink change rewrites no pixel, as on the CPC:
it changes the background register or fills the screen RAM or the colour RAM of the game's 32 x 24 cells:

{{code src/c64/plataforma/tinta.s | ^; plat_tinta: A = pen 0-16 | ^; switched between}}

Pen 3 and the border are black in all of the game's palettes, so the cells outside the game's area, whose screen RAM
and colour RAM stay black, never show their bitmap bytes: they hold data, exactly as the CPC kept data in the hidden
part of its own screen.
