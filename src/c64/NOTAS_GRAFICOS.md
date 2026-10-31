# abadia64ks on the C64: the graphics (H3)

Every graphic the CPC 64 KiB game draws, where it is, who reads and writes it, what points into it, and its
Commodore 64 format.  The drawing routines themselves are not designed here, only the data they work on.
Tool: `tools/c64_graficos.py IMAGE OUTDIR [--comprueba PNGDIR]` (run on
`data/cpc64/juego/ram.bin` into `data/c64graf/`): one `<name>.bin` per block in its C64 format, the
start-up tables `tabla_*.bin` (for the host's checks), `graficos64.tsv` (the blocks) and `marcos64.tsv` (every
value a pointer of the game can hold into a converted block -> its C64 offset).  `--comprueba` checks the
in-place flips, the determinism (byte-identical on rerun, also checked by hashing the output files of two
runs) and renders CPC against C64 (rooms, sprite sheet, font, score bar) to PNG.

The addresses are the tape image's (`ram.bin`, the memory at 20BEh, before `sys_startup_init` 3568h has run:
the tiles 00h-7Fh are still at 8300h + 32n, the score bar's source is in the hidden screen rows).  After the
start-up the CPC keeps tiles 00h-7Fh in the screen's hidden gaps (C600h-C7FFh, CE00h-CFFFh, ... FE00h-FFFFh,
tile n at gap n >> 4, offset 32 (n & 15)); on the C64 there is no such move: the converted tiles are placed
once at their C64 address.

Adso's upward diagonals: the three 4-byte-wide CPC poses at A8C5h, A93Dh and A9B5h now use `sim`
instead of `aislado`, with a coherent cap/face and thin connected robe folds in `datos/retoques64.txt`. This avoids
large shape changes when the CPC's one-pixel features are halved. The three walking poses, timings, dimensions and
in-place mirrors remain; his downward poses, Guillermo and all other assets are unchanged. The normal
`juego_final/construye.sh` regenerates the graphics, so the retouches are included by the normal disk build.
`python3 juego_final/vice/adso.py ../../doc/revisiones/adso/despues --comprueba --vice` (from src/c64) checks all 16 native animation
frames in VICE, both horizontal alignments, the reflected source bytes and every composed bitmap pixel.

## Inventory

| Block (C64 name) | CPC range (tape image) | CPC bytes | C64 bytes | What | Read by | Written by | Pointers into it |
|---|---|---|---|---|---|---|---|
| `baldosas` | 8300h-9E3Fh (tile n at 8300h + 32n, n = 00h-D9h) | 6976 | 3488 | the room tiles, 4 bytes x 8 lines, and in free tile slots the objects' graphics | 49E5h spr_tile_to_buffer (to the sprite buffer and, from iso_draw_room_spiral 4A5Fh through iso_draw_tile 4AC8h, to the screen); 3568h start-up (moves 00h-7Fh to the gaps); the sprite merge (objects); 4D30h hud_draw_objects (objects, opaque) | start-up copy only | tile numbers (not pointers) in the room/block data; object graphics: spr_table +7 of sprites 13-21 |
| objects (inside `baldosas`) | D7A0h-D7FFh (slots 2Dh-2Fh; tape image 88A0h-88FFh), 9720h-97DFh (slots A1h-A6h) | 6 x 48 | 6 x 24 | lamp D7A0h, book D7D0h, glasses 9720h, object 1 9750h, keys 9780h (3 objects), parchment 97B0h; 4 bytes x 12 lines | sprite merge 4612h-4714h; hud_draw_objects 4D30h (opaque copy to the score bar slots C591h + 5k) | never | spr_table 2A6Ch..2B0Ch +7 (fixed in the table) |
| `personajes` | A300h-AA2Ch | 1837 | 1053 | Guillermo 5 x 174 lines (A300h), 4 x 33 (A666h); Adso 5 x 95 (A6EAh), 4 x 90 (A8C5h) | sprite merge; iso_mirror_draw_callback 4FC9h (copies a frame to a mirror buffer) | in place: spr_flip_guillermo 2F40h, spr_flip_adso 2EE7h (spr_flip_graphics_h 2F57h) | animation tables 2CF0h, 2D10h (16 words); spr_table +7 of sprites 0-5; code 2F48h, 2F51h, 2EEFh, 2EF8h |
| `puerta` | AA49h-AB38h | 240 | 120 | the door leaf, 6 x 40 | sprite merge | in place: obj_door_flip_graphics 0AD6h (state 28C9h) | spr_table +7 of sprites 6-12 (set by obj_door_sprite_update 0A42h); code 0A7Eh, 0AE6h |
| `romanos` | AB39h-AB58h | 32 | 16 | day numerals V (AB39h), I (AB49h), 2 x 8 | hud_draw_day_numeral 50D9h (opaque) | never | code 50E7h, 50E0h |
| `habitos` | AB59h-AE2Dh | 725 | 435 | the monks' robes, 6 of 5 x 26, 24, 24, 25, 23, 23 lines | sprite merge from line 10 of a monk (mirrored when bit 14 of the table word is set) | never in place (see "dead" below) | robe table 4431h (16 words, bit 14 = mirrored); code 2126h |
| `caras` | B103h-B3BEh | 700 | 420 | the monks' faces: 7 blocks of 2 faces of 5 x 10 (Severino B103h, abbot B167h, Malaquias B1CBh, Berengario B22Fh, Bernardo Gui B293h, Jorge B2F7h, hooded B35Bh) | sprite merge (lines 0-9 of a monk) | in place, 5 x 20: spr_flip_malachi/abbot/berengar/severin 2F00h-2F30h, spr_unflip_monk_faces 304Fh | faces table 2BE8h (4 words); monk animation table 2D30h (8 words: face or face + 32h, written by chr_select_frame 25B6h); code 3B9Fh, 3BAFh, 3BCBh, 3BDEh; the +32h at 25FAh |
| `fuente` | B400h-B56Fh | 368 | 184 | the font, codes 2Dh-5Ah, 8 x 8 one bit per pixel | txt_draw_char_masked 364Fh (txt_draw_char 364Dh, inverted 3649h) | never | code 3661h (base), the glyph address B400h + 8 (c - 2Dh) |
| `glifo_blanco` | 344Ch-3453h | 8 | 4 | the glyph of code 20h | 364Fh | never | code 3653h |
| `marcador` | C600h, D600h, E600h, F600h (4 x 512, the hidden rows of the tape image) | 2048 | 1024 | the score bar, character rows 20-23 (32 lines x 64 bytes) | hud_rows_from_hidden 3598h, once at start-up | never | code 3598h-35ADh |
| `luz` | 4451h-446Eh | 30 | 30 | the lamp's circle of light: 15 big-endian words, one bit per CPC byte | spr_draw_light (472Dh-47A9h, inside spr_draw_all 447Dh) | never | code 472Fh |
| `cola_obsequium` | 5180h-5183h | 4 | 4 | the partial byte of the obsequium bar (FF 7F 3F 1F) | hud_obsequium_sub 5129h | never | code 5143h |
| `fila_blanca` | 50D7h-50D8h | 2 | 1 | FF FF, the blank day numeral row | 50D9h | never | 50D9h (in its own code) |

Totals: 12970 CPC bytes -> **6779 C64 bytes**, of which the score bar's 1024 go straight into the bitmap (rows
20-23), so **5755 bytes** of graphics outside the screen.  By kind: tiles + objects 3488, characters and
monks 1908 (personajes 1053, habitos 435, caras 420), door 120, font 188, HUD pieces 51, score bar 1024 (in
the bitmap).

Not graphics, but drawn into: the sprite buffer 7F80h (composed rectangles), the mirror buffers 855Ch and
8656h (a frame copied and flipped by 4FC9h for the reflections), the screen.  They are buffers of the
parent map, in the C64 formats below.

### The tile slots

The rooms use 204 tiles (all 129 room records built with `bloques_base.py`, blocks reached by CALL/JUMP
included, the mirror entry 7ABCh in both states 11h and 51h).  Tile numbers never placed: 00h (no tile),
2Dh-2Fh (the lamp's and book's graphics), 6Dh (in some blocks' tile lists, never placed by any room), 73h,
85h, 86h, A1h-A6h (four object graphics), DAh-FFh (9E40h-A2FFh: the first floor's heights 9E40h, the
library's 9F60h, and A006h, see "garbage").  The C64 tile block keeps slots 00h-D9h (tile n at +16n) with the
objects where the CPC has them, at half their CPC offset; **free C64 slots: 00h, 73h, 85h, 86h (16 bytes
each, 64 bytes)**; 6Dh is converted anyway (16 bytes; free if the parent prefers, the room data never draws
it).

### Dead or garbage data found

* AA2Dh-AA48h (28 bytes between Adso's frames and the door): never read; not converted.
* 2126h-2138h (the new game): copies the robes AB59h (2D5h bytes) to AE2Eh and flips the copy (B = 91h
  lines, C = 5).  Nothing reads it: AE2Eh-B06Dh is the height buffer (refilled before use) and B06Eh-B102h is
  never read.  On the C64: drop the copy and the flip; do not compare AE2Eh-B102h after it.
* spr_table entry 20 (2AF8h, object 7, record 2B7Ch at x 8, y 8, never in a room) has graphics pointer
  A006h, inside the library's height list: garbage.  `marcos64.tsv` maps it to the lamp's graphic.
* The doors' sprites (6-12) hold 3A98h in the tape image: set to AA49h by 0A42h before any use.
* The characters' sprites (0-5) hold old pointers (38B4h, 38AAh, 3A2Ah) until their first animation.

## The pixels

A CPC mode 1 byte (4 pixels, pixel i = bit 7-i + 2 bit 3-i) becomes one C64 multicolour nibble (2 pixels):
each pair of CPC pixels one C64 pixel.  Pens -> bit pairs as `c64_sala.py` (BITS): **pen 3 = 00 ($D021),
pen 0 = 01, pen 1 = 10, pen 2 = 11**.  A uniform CPC byte becomes: 00h (pen 0) -> nibble 5, F0h (pen 1) ->
A, 0Fh (pen 2) -> F, FFh (pen 3) -> 0; so the constants the code writes (slot clear 00h, the light's and
the bar's FFh, the bar's 0Fh, the spiral's 00h/FFh, vid_fill_play_area's FFh) are C64 55h, 00h, FFh, 00h per
byte (one per two CPC bytes).

Which pixel of a pair survives (rendered and compared, see the PNGs of `--comprueba`):

| Rule | Used for | Why |
|---|---|---|
| `sim`: the pen first in 1, 2, 3, 0 (orange, yellow, black, transparent) | characters, faces, robes, door, objects | closest look among right / left / detail / 8 priority orders on all frames; **mirror-symmetric and per byte**, so the game's in-place flips and the robes' mirrored drawing give exactly the conversion of the flipped CPC graphic (checked on all 18 flipped blocks).  The shadow check can then compare the converted CPC bytes with the C64's whatever the flip state. |
| `detalle` (`c64_sala.py`: right pixel, keeps one-pixel vertical lines and the fluting) | tiles (each tile alone), roman numerals | the room look decided in src/c64/poc.  Per tile instead of per room: rooms 16h, 00h, 64h, 72h differ from the whole-room conversion in 142, 284, 174, 126 of 20480 pixels (0.7-1.4 %). |
| `izq` (left pixel) | the score bar | the only rule that keeps the gothic "OBSEQUIUM" and "Dia" readable |
| `der` (right pixel) | the font, the obsequium tail | the font: right pixel is by far the most legible (OR too bold, left loses strokes); its two collisions fixed: N redrawn as `#..# ##.# ##.# #.## #.## #..# #..#` (else N = H), ';' from the left pixels (else ';' = ':').  The tail: floor(k/2) lit pixels for k = 0-3. |

## The C64 formats

* **Tiles** (`baldosas`): tile n at +16n, 16 bytes **column-major**: the 8 lines of the left C64 byte
  column, then the 8 of the right one (a tile is 2 bitmap cells, so drawing to the screen is 8 consecutive
  bytes per cell).  Tile x positions are multiples of 4 CPC bytes, so tiles are always byte-aligned.
* **Sprite graphics** (characters, faces, robes, door, objects, and the mirror buffers' copies): **row-major**,
  ceil(w/2) bytes a line for a width of w CPC bytes; for an odd w (the 5-byte characters, faces and robes)
  the low nibble of each line's last byte is padding = **pen 0, bit pairs 01 01 (nibble 5)**, transparent
  for the sprite merge.  A frame of w x h is ceil(w/2) x h bytes; a pointer to line L of a block of width w
  becomes block + L ceil(w/2).
  Deviation from the column-major draft: the CPC flips whole blocks of frames of different heights as one
  w x H block (Guillermo's 174 lines, the faces' 2 x 10 lines as 5 x 20), points at lines inside them
  (face + 32h, frame starts) and skips lines by multiplying by the width; with column-major frames the
  column stride would be the containing block's height, which no sprite record holds.  Row-major keeps the
  CPC's arithmetic: stride = ceil(w/2) instead of w, face + 1Eh instead of + 32h.
* **In-place flip** (spr_flip_graphics_h on the C64 format): per line the w nibbles in reverse order, each
  nibble's two pixels swapped, the padding nibble (odd w) staying last.  Even w: bytes reversed and each
  byte through `espejo_byte`; odd w: new byte k = high nibble of espejo_nibble(old byte ceil(w/2)-1-k) |
  low nibble of espejo_nibble(old byte ceil(w/2)-2-k) (the last byte keeps its padding).
* **The robes mirrored at draw time** (bit 14): read the line from its end in nibbles with the same rule.
* **Sprite x positions** are in CPC bytes = C64 nibbles: a sprite at an odd CPC x is half a byte off; the
  composed rectangle is tile-aligned (x & FCh, widths multiple of 4 CPC bytes), so the sprite buffer holds
  rectangles of w/2 bytes a line and only the sprite's own bytes need the nibble shift (`nibbles` table or 4
  shifts).  The light (14h CPC bytes wide) is 10 C64 bytes.
* **The font** (`fuente`, codes 2Dh-5Ah): 4 bytes a glyph, byte k = row 2k in the high nibble, row 2k+1 in
  the low, bit 3 of a nibble = the left pixel (8 rows x 4 pixels, 1 bit each); glyph c at +4 (c - 2Dh).
  Drawn opaque through `fuente_nibble` (set pixel pen 3 = 00, clear pen 2 = 11), the inverted text (mask
  FFh) = EOR FFh.  The text cursor's x is in CPC bytes and can be odd (hour name B40Dh, yes/no A41Dh), so a
  glyph can straddle two C64 bytes.  Blank glyph: 4 zero bytes.
* **The score bar** (`marcador`): already in the bitmap's order: 4 character rows x 32 cells x 8 bytes, the
  bytes of bitmap rows 20-23, cells 4-35 (the play area is centred, 4 cells from the left).  It is not kept
  anywhere else: the C64 image of the bitmap carries it.
* **The light** (`luz`): unchanged, one bit per CPC byte = per C64 nibble (0 = dark: nibble 0, pen 3).
* **Obsequium tail** (`cola_obsequium`): 4 nibbles (low 4 bits) for obsequium & 3; full nibble F (pen 2),
  empty 0 (pen 3).  **Blank numeral row** (`fila_blanca`): one byte 00h.
* The animation tables' width and height bytes (2CF0h +2, +3, ...), the sprite records' widths and the
  hud_draw_objects widths stay in CPC units (bytes = nibbles); the 6502 code derives the C64 stride.

## Merging and the start-up tables (c64_graficos.py `tablas`, 256 bytes each unless said)

| CPC | Rule | C64 table(s) |
|---|---|---|
| tiles 01h-0Ah | opaque copy | none |
| tiles 0Bh-7Fh, OR 8F00h / AND 9000h (vid_init_stub 3607h) | pen 2 transparent | `and_tile_a` (11 where the pair is 11), `or_tile_a` (the byte with those pairs cleared; = byte EOR and_tile_a) |
| tiles 80h-FFh, OR 9100h / AND 9200h | pen 1 transparent | `and_tile_b` (11 where 10), `or_tile_b` |
| sprites, 46B2h-46C2h (byte 0 skipped, m = b OR swap(b)) | pen 0 transparent | `and_spr` (11 where 01), `or_spr`; a byte 55h (all pen 0) can be skipped |
| spr_mirror_byte 4717h (robes), flip_byte (in-place flips) | mirror | `espejo_nibble` (each nibble's 2 pixels swapped), `espejo_byte` (4 pixels reversed) |
| — | odd nibble position | `nibbles` (high <-> low nibble) |
| txt 364Fh (nibble XOR 0Fh / FFh) | font | `fuente_nibble` (16 bytes) |

Built at start-up by the 6502 code (as vid_init_stub builds 8F00h-92FFh) in a buffer, or stored.  Needed:
`and_tile_a`, `and_tile_b`, `and_spr`, `espejo_nibble`, `fuente_nibble` = **1040 bytes**; the three OR tables,
`espejo_byte` and `nibbles` (**1280 bytes**) only buy speed (OR = byte AND NOT and, espejo_byte = nibble swap
of espejo_nibble, shifts).  The CPC's 4 tables (1 KB) are not needed on the C64.

## Pointers into the graphics (for punteros64.tsv)

Every CPC value they can hold is a row of `data/c64graf/marcos64.tsv` (block, CPC value, C64 offset).

| Field (CPC address) | Size | Points into | Notes |
|---|---|---|---|
| 2CF0h + 4k, k = 0-7 (Guillermo's animation) | word | personajes | the entry's +2, +3 (w, h) are not pointers |
| 2D10h + 4k, k = 0-7 (Adso's animation) | word | personajes | |
| 2D30h + 4k, k = 0-7 (the monks' frames) | word | caras | written at run time by chr_select_frame 25B6h: [2BE8h + slot] or that + 32h (C64: + 1Eh) |
| 2BE8h, 2BEAh, 2BECh, 2BEEh (faces of the 4 monk slots) | word | caras | written by 3BE6h / 3BD8h from code constants B293h, B2F7h, B35Bh |
| 4431h + 2k, k = 0-15 (robes) | word | habitos | **bit 14 = drawn mirrored** (pointer = value AND BFFFh): the C64 robes must lie where bit 14 of the address is 0 ($0000-$3FFF, $8000-$BFFF) or the flag must move (e.g. to bit 15 below $8000) |
| 2968h + 14h k + 7, k = 0-5 (characters' sprites) | word | personajes, caras (monks through 2D30h), the mirror buffers 855Ch/8656h (reflections, set by 4FC9h) | dynamic |
| 2968h + 14h k + 7, k = 6-12 (doors) | word | puerta (AA49h) | set by 0A42h; 3A98h in the tape image |
| 2968h + 14h k + 7, k = 13-21 (objects) | word | baldosas (objects) | fixed: D7D0h, 9750h, 9720h, 97B0h, 9780h x 3, A006h (garbage), D7A0h |
| 2968h + 14h k + 7, k = 22 (the light) | word | none | 0000h = draw the light |

Code operands (for the 6502 writers, as symbols): A300h 2F48h, A666h 2F51h, A6EAh 2EEFh, A8C5h 2EF8h (flip
routines, with the line counts AEh, 21h, 5Fh, 5Ah and widths 5, 4 kept), AA49h 0A7Eh 0AE6h, AB39h 50E7h,
AB49h 50E0h, 50D7h (50D9h), AB59h/AE2Eh 2126h/2129h (dead copy), B293h 3B9Fh, B2F7h 3BAFh 3BCBh, B35Bh 3BDEh,
the face offset 32h at 25FAh (-> 1Eh), B400h 3661h (and the glyph size 8 -> 4), 344Ch 3653h, 4451h 472Fh,
5180h 5143h, C600h/D600h/E600h/F600h 357Ah 3598h 35A1h 35A7h 35ADh, 8300h 357Dh (the start-up tile move,
not needed on the C64), the tile address arithmetic 49E5h-4A08h (32n -> 16n, no gap mapping).

## Open questions

1. The score bar halved loses detail in its gothic lettering even with the left pixel ("OBSEQUIUM" readable,
   thin), and the font at 4 pixels is readable but rough (N redrawn by hand): perhaps a hand-drawn
   C64 score bar and font, or hires sprites over the text strip.
2. The robes' bit 14 flag constrains the robes' C64 address (see the table) or the 6502 code's flag test.
3. Object 7's graphic (A006h, garbage): confirm it is never shown (record 2B7Ch never moves into play in the
   scripts read so far); then its sprite needs no graphic.
4. The mirror buffers 855Ch (Guillermo) and 8656h (Adso) hold flipped frame copies: C64 sizes at most
   3 x 36 = 108 and 3 x 32 = 96 bytes (CPC 180 and 160).
5. Tile 6Dh is in some blocks' tile lists but no room draws it: keep (16 bytes) or free.

## The rule `trazos` for the characters and the monks

I compared the C64 characters with the PC EGA ones (the CPC inks; pixel for pixel the same drawings as the tape's,
checked for the 12 frames of Guillermo and Adso, the 14 faces and the 6 robes: 0 differences) and wanted the same shape
on the C64, although the resolution differs; 1:1 (every PC pixel one C64 pixel, twice as wide) was rejected after seeing it,
and the engine is not to be touched (no hardware sprites).  The rows `sim` / `aislado` of the table above and the hand
retouches of `src/c64/datos/retoques64.txt` now apply only to the door and the objects (`sim`); Guillermo, Adso, the faces and
the robes use `trazos` (`tools/c64_mitad.py`):

* each C64 pixel takes one of its two CPC pixels, never a third pen; the choice for a whole line is the least-cost one,
  found exactly by dynamic programming over the pairs;
* losing a stroke costs 100 (+ its contrast with its neighbours): a run of any pen that is darker or lighter than both
  its opaque neighbours (lines, folds, outlines, eyes; Guillermo's black strokes on orange, the monks' orange strokes on
  black); losing an inner transparent run (a gap between two parts of the figure) costs 60; losing a one-pixel run whose
  pen lies between its neighbours in brightness (black-orange-yellow: a step of shading) costs 0.4; a surviving run costs
  |pixels - length / 2| (steps of 0.5), so widths stay as near as the half resolution allows; keeping the transparent
  pixel of a half-transparent pair costs 0.1 (the silhouette grows outward, never shifts); differing from the C64 line
  above costs 0.25 (a tie-break: vertical coherence);
* not mirror-symmetric: the game flips the C64 data in place (the characters, the faces 5 x 20) or reads the robes
  backwards, which is the exact mirror of the converted graphic; the host's checks take flipped units from the image;
  the converter's flip check keeps only the door.

Comparison tool: `tools/c64_compara_pc.py OUTDIR --grupo protagonistas|caras|habitos|monjes [--escala N]
[--columnas pc,antes,trazos,1a1]`: the PC EGA graphic decoded as the PC game draws it (`../abadia`, read only), the C64
graphic of the conversion kept in `data/c64graf_sim` (the rules before `trazos`) and the new one, on a
sheet with the colodore colours, with the measures per graphic (strokes lost by kind, silhouette differences; the count
of differing pixels is the same for every rule, one per mixed pair, and says nothing).  The samples I judged are on
hal9000c's desktop (`muestra_graficos_c64/`).

## The hardware-sprite build (`--hw`, src/c64/SPRITES_HW.md)

With `--hw` the converter writes `data/c64graf_hw`: the characters' frames by the rule `cuerpo` (a pair with one
black pixel takes the other pixel, both black stays black, the rest as `trazos`: the black goes to a hardware sprite),
their black layers in `negro` (one bit a CPC pixel, 4w bits a line packed, two lines per 5 bytes for w 5) with
`negro_tabla` (16 entries: offset and whether the frame starts at a low nibble), the class B tiles stored EOR 55h (one
AND table for both classes), and only the tables that build keeps (`tabla_and_tile_a`, `tabla_and_spr`, the font
nibbles).  The faces, robes, door and objects are as the normal build (`trazos` / `sim`).  The mock-up of what the
C64 shows: `c64_compara_pc.py ... --columnas pc,sprite,trazos` (the column `sprite`).

## Darksoft's C64 version, measured from its video

A crop of another C64 version, made after this one: Darksoft's, announced
(Commodore News item 15151, "99 % finished", no file released), demo video youtube.com/watch?v=tJjmm17gs-Y
(384 x 272 at 25 fps: one video pixel per C64 hires pixel; `yt-dlp`, frames with ffmpeg).  The crop matches frame
t = 20 s at scale 3 (normalised correlation 0.90).  Measured on the real pixels, snapped to VICE's palette: the
background and the characters are MULTICOLOUR (strong luma edges on the even columns 97 % in the play area; the
characters' black runs start on even columns 85-90 %, the rest compression noise; black, yellow and orange runs
2 pixels wide): three colours per character (black, orange, yellow), 16-22 x 26-37 pixels, the floor grey, steps
of 2-6 pixels every 3-4 video frames.  Nothing hires: the same resolution as the `trazos`; their characters are a
chunkier redrawn design, and the mask and the fill never separate because they are one layer.  Sheets on both
desktops: `muestra_graficos_c64/muestra6/` (comparacion_darksoft.png, guillermo_adso_x8.png, LEEME.txt).

## The rule `contorno` and the tiles by class (after Darksoft's version)

I dropped the hardware sprites and tried the precise conversion again to reach Darksoft's look, for the characters
and for every background graphic too, very precisely.  What Darksoft's characters have (measured on the
video, above) is a continuous outer contour at the half resolution; ours lost pieces of it because `trazos` keeps
every stroke run but each as one C64 pixel, so the contour broke where two black runs competed in a pair.

* `c64_mitad.contorno(rows, pen=None, pesos=None, tr=0)`: the stroke pen (`pen_trazo`: the opaque pen with the most
  one-pixel runs, ties to the darkest: black for Guillermo, Adso, the faces, the door and the objects; orange for
  the monks' robes) is kept whole wherever it touches the outside (a transparent pixel left, right, above or below,
  or the edge): that pair becomes the stroke pen; everything else is `trazos`.  A pure function of the pens.  A
  first version that gave the stroke pen EVERY pair containing it flooded the figures black (the PC's folds are
  1-pixel lines 1 pixel apart) and was dropped.
* `tr`: the transparent pen is now a parameter of `trazos`, `contorno`, `compara` and `pen_trazo` (0 for the
  characters, faces, door and objects; the tiles 0Bh-7Fh pen 2, 80h-D9h pen 1, 01h-0Ah none).
* Applied in `c64_graficos.py`: characters, faces, robes (`regla = M.contorno`), the door and the objects
  (`M.contorno`).  The tiles were switched to `M.trazos` with the class's pen and PUT BACK on `detalle` the same
  hour: seen live, the rooms looked worse; the tiles form continuous
  surfaces and the per-tile, per-line choices broke the brick courses and the floor patterns, which the measure
  of lost runs does not see.  The flip check keeps the rule `sim` as its own reference (it tests the flip, not the
  door's data).
* Measures (`c64_compara_pc.py --columnas pc,trazos,contorno`, `c64_compara_baldosas.py`, sheets in the
  `muestra_graficos_c64/muestra7/`): the 218 tiles lose 807 runs of the source with `trazos` against 1373 with
  `detalle` (black runs 233 against 684; `contorno` 940, worse on orange and yellow, so not for tiles); Guillermo 0
  loses 5 black runs with `contorno` against 15 with `trazos`, at the price of 7 yellow runs against 1 (the forced
  black pairs eat the neighbouring highlight pixels).  Still a conversion, not a redrawing: Darksoft's figures are
  hand-drawn at that resolution.
* `contorno` put back too, for every graphic (back to the previous rules): Adso walking
  right-down loses his eyes in some frames (the measure said it: Guillermo 0 lost 7 yellow runs against 1 with
  `trazos`; a forced contour pair overrides the highlight pixel beside it).  The build is as it was before these rules
  (characters, faces and robes `trazos`; door and objects `sim`; tiles `detalle`); the rule stays in
  `c64_mitad.py` and the comparator as a tool.  Conclusion: Darksoft's look is a redrawing at the half resolution,
  not a conversion rule; a rule that keeps every contour whole at 160 pixels must drop highlights, and one that
  keeps every stroke run thins and breaks the contours (`trazos`).

