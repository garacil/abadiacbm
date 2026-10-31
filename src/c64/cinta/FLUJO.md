# The game's stream and its loader (the tape and the C64 disk)

The game reaches the machine as a **stream**: the game's image cut into segments, each with its destination address,
read byte by byte by the loader (`src/c64/presentacion/cargador.s`, at $C3E8) while the loading picture stays on the
screen.  The tools of the stream live here because the tape and the C64 disk use them (the C128 disk loads crunched files
instead: `src/c64/disco128/NOTAS.md`):

| File | What |
|---|---|
| `flujo.py` | the stream of a game image; checks it at once with a model of the loader written from `cargador.s` |
| `lz64.c` | the stream encoder (literal runs in the builds; it also writes the former compressed format), built by `flujo.py` into a temporary directory |
| `libres.py [--tablas]` | the bytes of the image the game does not need at its start, checked with the hybrid host |
| `flujo_cinta.py` | the tape's blocks and the C64 disk's files (`--disco`), made with `flujo.py`'s stream and checked by its model |

The first C64 disk (the presentation, the stream "juego" and the ending, without the start menu) was
replaced by the tape's release on disk (`src/c64/disco64`).  Its build stays as the presentation's test
disk (`src/c64/presentacion/pruebas/disco_prueba/`: `construye.sh`, and `prueba.py`, which checks in VICE every page
and the music of both parchments, the picture during the load, the loader and the ending); its studies are in
`doc/revisiones/`.  At first the first stage was a port of the CPC's first stage (src/c64/pergamino: its
parchment, then the tape's loading picture converted, shown pink and built up in the CPC's byte order as the game
loaded); the description of that pink reveal is in `doc/ESTADO.md` ("The C64 loader and disk").

## The original's loading, measured

* The tape (`tools/tzx.py` on `original/archive.org/cdt/abadia.cdt`): block 20h is 65025 bytes (the
  flag and FE00h bytes stored from FFFFh down to 0200h) with bit pulses of 1229 / 2284 T-states (3.5 MHz): a pilot of
  2.68 s, then 499.16 s of data, **501.8 s** in all (1042 bit/s, 130 bytes/s).  The first stage (16h) and the ending
  (2Ah), 11265 bytes each: 82.1 s and 82.4 s.
* The screen comes first on the CPC: C000h-FFFFh are the first 16384 bytes of the block, the picture is complete after
  25.2 % of the load, then the rest loads under it.  On the C64 the picture is complete from the start (read by
  the program before the parchment) and stays; the game's data loads under it.

## The stream (`flujo.py`, read by `cargador.s`)

```
2 bytes   a load address ($C000; the file is a PRG, read as a data channel: ignored)
4 bytes   the header: principal_inicio, the address of plat_unidad
n bytes   the data: segments, then 00 00
2 bytes   the checksum: the 16-bit sum of every byte before it
```

* **The data** (`lz64.c`): the normal build uses literal runs only, with no back-references or decompression copies.
  The loader retains the former token format, described here for reference: segments, each its destination address
  (2 bytes) then tokens, bits read most significant
  first from bit bytes taken from the stream when needed:
  * `0` + gamma(n) + n bytes: literals;
  * `1` + gamma(h + 1) + byte l + gamma(k - 1): k >= 2 bytes copied from the destination - (256 h + l) (16 bits,
    wrapping: any address written before), byte by byte forwards;
  * `1` + gamma(257): the end of the segment;
  * gamma(v): for each bit of v below its leading 1 a 0 and the bit, then a 1 (Elias gamma, interlaced).
  The address 0 ends the data; the address 1 is **the mark** (no tokens): the loader blackens the picture's side cells.
  The former compressed parse is optimal for the format (dynamic programming over each segment; matches at any of the 255 near offsets
  and from the last 64 earlier positions with the same 3 bytes; a match is valid when every source byte was written
  before it is read).  55574 bytes -> 40935 (74 %).  (On the build: 55467 -> 40489; exomizer 2 raw
  38195, xz -9e 36080.)
* **The order**: every byte whose place the screen does not show, in the order of the game's addresses; the mark;
  the bytes of the side cells' bitmap (columns 0-3 and 36-39 of rows 0-23, row 24:
  the game's data that lives in the bitmap outside its screen, 1025 bytes in 14 segments).  So the picture stays whole until
  the mark, and its 768 middle cells (the game's screen, rows 0-23, cells 4-35) until the end of the data.
* What the data holds: every byte of the game's segments (`src/c64/juego_final/c64/juego.map`) but BSS and the merge
  tables, written where they belong, except what is held aside.

## What the loader leaves out (the game does not need it at its start: `libres.py`)

* `libres.py`: a copy of the checked build (src/c64/<scratch>, links to src/c64/juego_final but juego.bin) with those bytes
  garbled (a fixed pseudo-random XOR), the whole 6502 game against the Z80 (`hibrido --juego6502`), the 8 sessions
  to frame 4472: **0 differences** with 2806 bytes garbled: the zero page $02-$23 and $9E-$FF, the stack page,
  $079D-$07FF, the BSS and the gap up to $7150 ($707B-$7150 in the build measured; and the host build's own BSS), the
  screen RAM $C000-$C3FF, ISO_VM_STACK and SPR_SORTED_LIST $C800-$C86F, $CFFD-$CFFF, $DFEA-$DFFF, the bitmap's free
  invisible bytes, the vectors $FFFA-$FFFF.  (The host fills the play area and the copied blocks from the Z80's
  memory at its start, so those bytes cannot be tested this way; the play area is cleared by the loader anyway.)
* The merge tables ($BB00-$BFFF, $C400-$C7FF, $EA06-$EA15, 2320 bytes): `game_main` calls `sys_startup_init` first
  (the image's D64_SYS_STARTUP_DONE is not 0Dh), which ends with `vid_init_stub` (3607) rebuilding all of them before
  anything draws.  The host compares these 'conv' blocks with the image it read, so `libres.py --tablas` (them
  garbled) gives the expected differences in those blocks only, the 6502's byte being the original; in VICE the
  game's first frame has all 2320 bytes as the image (the test disk's `prueba.py`).

## Memory during the load

| Range | During the load | At the end |
|---|---|---|
| $02-$0C | the loader's variables | $02-$23 cleared (the image's 0) |
| $24-$8F | the game's (written as they come) | |
| $90-$9D | the KERNAL's; the game's held at $0100-$010D | copied back |
| $9E-$FF | the KERNAL's | cleared (the image's 0) |
| $0100-$01FF | $0100-$010D the held zero page; the stack from $01FF (the loader and the KERNAL) | |
| $0200-$03FF | the KERNAL's (vectors, file tables; NMI -> an RTI); the game's held at $BF00 and $C700 | copied back |
| $0400-$BAFF | the game's, as they come (the program, which lived at $0801-$BFFF, is overwritten) | |
| $BB00-$BEFF | the game's score bar (bitmap rows 20-23, cells 4-35: the picture is there) | copied to the bitmap |
| $BF00-$BFFF, $C700-$C7FF | the game's $0200-$02FF and $0300-$03FF | copied back |
| $C000-$C3E7 | the picture's screen RAM (abadia.koa's); the side cells' 0 after the mark | blackened by plat_inicio |
| $C3E8-$C642 | the loader (603 bytes; the sprite pointers and the tiles' merge tables: rebuilt by the game) | |
| $C800-$C86F | free (ISO_VM_STACK, SPR_SORTED_LIST: not loaded) | |
| $C870-$CFFC, $D000-$DFE9 | the game's ($D000-$DFE9 written with $01 = $34: the loader keeps the I/O out but around CHRIN) | |
| $D800-$DBE7 (colour RAM) | the picture's colours; the side cells' 0 after the mark | blackened by plat_inicio |
| $E000-$FF3F | the picture (all its cells) until the mark; then the side cells' bytes are the game's data; the middle cells the picture's until the end | play area cleared, score bar copied |
| $FF40-$FFF9 | the game's data (not shown) | |
| $FFFA-$FFFB | NMI -> the loader's RTI (RESTORE does nothing; set again by plat_inicio) | |

No interrupt during the load (CIA 1, CIA 2 and the VIC-II masked), so the KERNAL's IRQ never runs; its serial code
uses CIA 1's timer B by polling.  $01 = $34 except around CHRIN ($36: the KERNAL and the I/O; the BASIC ROM off, the
loader's held pages at $BB00-$BFFF stay RAM) and at the mark ($35: the colour RAM).  At the end: the checksum, CLRCHN
and CLOSE, `plat_unidad` := the device it loaded from ($BA, 8 if not a drive), the display blanked ($D011 = $0B), the
held pages copied, the play area cleared, the zero page put back, `JMP principal_inicio`; plat_inicio then blackens the
screen RAM and colour RAM and turns the display on.

## Historical compressed load times (VICE, the KERNAL's serial speed)

These measurements are of the first disk's former compressed build, not of the literal-only streams now used, which take
longer at the same serial speed.

"abadia" 29.3 s (LOAD to its main); the abadia.koa, text1.bin and pp.bin read: the parchment on the screen at 70.9 s
(the CPC's first stage: 82.1 s); "juego" 109.1 s (40943 bytes; 125.7 s with the old scheme, its picture interleaved;
the CPC's block 20h: 501.8 s); "final" 26.6 s, its parchment on the screen 44.5 s after plat_final (the CPC's ending
block: 82.4 s).

## Open

* The streams are literal runs.  The presentation's own files are loaded by the KERNAL's LOAD and the fread
  (the tape and both disks crunch the presentation and the ending with Exomizer instead). The KERNAL's serial speed is the limit (375-390 bytes/s); a fast
  loader is not used (JiffyDOS and cartridge speeders speed up CHRIN and LOAD as they are).
* PAL only, as the platform layer.
* plat_final's stub runs RAMTAS, which clears $BA: the ending's own files (text2.bin, pp.bin) are read from drive 8
  even when the game came from another drive (cc65's runtime takes 8 when $BA is 0).
