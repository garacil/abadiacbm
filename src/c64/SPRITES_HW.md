# Hardware sprites for the characters' black strokes (the SPRHW build)

**Rejected** after seeing it live: the mask and the fill separate while walking, the game
lost speed, the VIC-II and the CPU are not synchronised; back to the initial routine, without the VIC-II, or the
VIC-II with 3 colours.  Measured with the same walk
(the Up key held 60 frames, `vice/` capture script): the walking frames cost 105 000-190 000 cycles more than the
normal build (170 000 mean against 239 000; the standing frames within 2 000), and the black layer (VIC sprites,
set when a rectangle is blitted) and the body (bitmap, blitted over several raster frames) change at different
instants, so they separate while walking.  The normal build (`src/c64/`) is the game; this build stays only as the
record of the experiment (`HW=1`), not shipped.  The alternative, the whole character as
multicolour sprites (3 colours), is being studied.

The aim: the C64 characters must look like the PC EGA / CPC ones pixel for pixel.  The
multicolour bitmap halves the horizontal resolution (one C64 pixel = two CPC pixels), so a one-pixel black stroke
cannot survive in the bitmap.  The SPRHW build draws each character's body in the bitmap without its black
pixels (rule `cuerpo`, `tools/c64_mitad.py`) and its black layer, at the CPC's full width, with
hires hardware sprites (one colour, black, 24 x 21): Guillermo and Adso, who are tracked, plus their two
reflections in the mirror room.  The monks keep the rule `trazos` in the bitmap: the VIC has 8 sprites and a
character of 36 lines needs two (lines 0-20 and 21-35); 4 tracked sprites use them all.  A mock-up of the result
for every character: `tools/c64_compara_pc.py OUT --grupo protagonistas --columnas pc,sprite,trazos`.

Everything here is measured in VICE (`src/c64/juego_final/vice/arranca.py`, `vice/vivo.py`) and in the pure C engine
(`src/juego/f_logica_a.c`, `MEDIR_SCRATCH`); nothing of the normal build changes (its image is byte-identical to the
one before this work except for the code-size reductions of `src/c64/ANALISIS_TAMANO_6502.md`, applied to both).

## Build, run, test

* `HW=1 C64=1 ./construye.sh` in `src/c64/juego_final`: graphics `data/c64graf_hw` (converter `--hw`: the `cuerpo`
  frames, `negro`, the tile table in its EOR form), map `mapa64.py --hw`, `-D SPRHW`, output `c64hw/` (juego.bin,
  juego.lbl, juego.map, and the HW mapa64.tsv / mapa64.inc beside them); the directory's generated files are put
  back to the normal map at the end (the host and usados64.py read them there).  The normal build is untouched
  (`C64=1 ./construye.sh` -> `src/c64/`; the map `mapa64.tsv` keeps its md5).  The English edition: `src/c64/ingles/construye.sh`
  (the trees), then `HW=1 C64=1 ./construye.sh` in `src/c64/juego_final_en` and `src/c64/disco_en/construye.sh` with
  `JUEGO=.../juego_final_en/c64hw DISCO_SALIDA=.../abadia64ks_english_hw.d64 CONSTRUYE_JUEGO=0`; its test
  `src/c64/ingles/pruebas/prueba_en.py --disco ... --juego ... --sin-final OUT`.
* In VICE on Xvfb :99: `JUEGO_DIR=$PWD/c64hw python3 vice/arranca.py OUT 1 50 200 400 800` (screenshots and the
  cycles of every frame); live on a desktop: `VICE_DISPLAY=:1 JUEGO_DIR=$PWD/c64hw python3 vice/vivo.py -VICIIdsize`.
* The disk: `JUEGO=.../c64hw DISCO_SALIDA=.../abadia64ks_hw.d64 CONSTRUYE_JUEGO=0 src/c64/presentacion/pruebas/disco_prueba/construye.sh`; its test
  `src/c64/presentacion/pruebas/disco_prueba/prueba.py --disco abadia64ks_hw.d64 --juego .../c64hw --sin-final OUT` (the ending's state injection
  uses the normal map: not for this build).
* Cycles a frame over 800 frames of the start (Guillermo in the church, the abbot arriving): normal 94 495 (90 100
  from frame 100), SPRHW 95 960 (91 328): +1.4 %.

## The engine's hooks (`logica_a_spr.s`, `.ifdef SPRHW`)

The composition of a rectangle (spr_draw_all) is as on the CPC: a rectangle per changed sprite, the tiles behind,
the sprites in depth order, the tiles in front.  SPRHW adds, per rectangle:

1. `hw_rect_inicio` (after the rectangle is allocated and cleared): `hw_encuentro` tests the rectangle against the
   four tracked records (active, not vanishing, a reflection only with a graphic inside the mirror buffers); when
   it meets one, a **coverage buffer** of the rectangle's own C64 size (`w/2 x h`, cell-major like the rectangle)
   is allocated right after it in the composition pool and zeroed.  The pool's rectangles are allocated at their
   C64 size (half the CPC's), so pool + coverages fit the normal 2 048 bytes: measured maximum 2 016 over a whole
   game (pure C engine, `MEDIR_HW`), the coverage refused (the rectangle not tracked) only if it would reach the
   mirror copies.
2. `hw_tras_mezcla` (after each sprite merge): once a tracked sprite is merged, `hw_modo` = 55h (AAh after a
   second tracked one) and the merge loops record, for every destination byte written afterwards, the opaque
   pairs of what they merge (`hw_tramo_cov` through `la_hwj`, and la_baldosa's own loop): the coverage says which
   pixels of the tracked sprite are hidden by what is in front.
3. `hw_tras_blit` (step 5, after the rectangle is blitted): for each tracked sprite the rectangle met, in the
   sorted list's order, `hw_construye` rebuilds the part of its two slots inside the rectangle from its black layer
   (`negro`, `negro_tabla`: 4w bits a line, two lines per 5 bytes for w 5) and the coverage: S = ((old AND NOT
   valid) OR (F AND NOT C AND valid)) AND play, line by line (valid = the box's nibbles inside the rectangle, play
   = inside the play area, mirrored frames through `rev8`), then `hw_vic` sets X = 24 + 4 x, Y = y + 10 (+21 the
   lower slot), the MSB and the enable bits, with the I/O switched in (spr_draw_all keeps it out for the tiles).
   The reflections' frame copies are followed through `hw_refl_pon` (iso_mirror_draw_callback).

Costs: 18 cycles a tile byte and 30 a sprite byte inside tracked rectangles after the tracked merge; the rebuild
~2 000 cycles a tracked sprite a rectangle.

## Memory (the SPRHW map, `mapa64.py --hw`)

* Code: `CODEHW` 980 bytes at $C800 (hw_rect_inicio, hw_encuentro, hw_cual, hw_construye, hw_frame, hw_cobertura,
  hw_vic, the tables), ten pieces `CODEHW01..10` of 64 bytes in the bitmap's invisible cells (the short routines,
  and five small game routines moved there in this build), `hw_tras_blit` and `la_baldosa`'s coverage loop in CODE.
  The code area ends at the lowest datos block: 26 336 bytes; CODE 25 653 + RODATA 535 + DATA 31 + BSS 72.
* Data: the black layers `negro` (919 bytes) in datos, `negro_tabla` (48) in the gaps; the three animation tables
  split in three 32-byte blocks (the pointers into the split ones relocated by `datos64.py` HERMANOS); the merge
  tables reduced to `tabla_and_tile_a` ($C400) and `tabla_and_spr` ($C500), rebuilt by vid_init_stub (class B tiles
  stored EOR 55h, la_baldosa's EOR form; sprites merged with the AND table and EOR).
* Run-time only, neither in the image nor loaded by the disk: the 8 sprite slots at $C600-$C7FF, the sprite
  variables `hw_datos_a/b/c` in the zero page's free bytes ($86-$9D after the dropped Z80 operands, $C5-$CC,
  $F2-$F9: `zp_hw`, the free runs of 8 bytes or more of the groups' windows), the sprite scratch chain fixed at
  $B080-$BFFF (the composition pool with the path grid at +500, the mirror copies, the queue's top, then the tile
  buffer): the disk's loader uses $BB00-$BFFF and $C3E8-$C7FF while it loads (cargador.s MARCADOR, PAGINA2,
  PAGINA3), so nothing loaded may be there.  The height-buffer cache's high bytes (`hc_hi`, 12) leave $C3F4-$C3FF
  to the VIC's sprite pointers.
* Zero page: 21 Z80 operands the C64 never reads (their stores under PRUEBA) are dropped from the map (SIN_ZP_HW);
  $FE-$FF is `hw_cov`.
* Placement rules of the HW map (`mapa64.py`): blocks with page asserts placed without crossing a page
  (PAGINA_HW, PAGINA_GRUPO_HW), the low-byte rules of the path search's buffers and the faces table (BAJO_HW),
  the first two floors' height lists kept below the third (SIN_HUECO), later small blocks fill the gaps the
  alignments leave (never a fixed block stepped over).

## Bugs found while bringing it up (all fixed, the way to find them in `vice/` and the session's scripts)

Pointers into the split animation tables not relocated (Adso's and the monks' frames pointed at code) ·
`hw_mul` wrong (the coverage base landed in the screen RAM: pixel 1 of every byte lost) · the coverage walked
row-major in a cell-major buffer · hw_vic writing the VIC with the I/O out (the registers went to the tiles under
$D000) · `util_clip_span` clears X (hw_encuentro's loop index) · hw_tras_blit kept its list index in `hw_tmp2`,
which the rebuild uses · the height-buffer cache over the sprite pointers · zero-page variables placed in the
holes of the groups' windows (chr_hbuf_fill_room uses two unnamed bytes there) · the packer treating a stepped-over
fixed block as a gap · the disk's loader staging pages ($BB00-$BFFF) holding loaded data · booted from the disk
the game hung after its first frame: the module's zero-page variables and the slots are not loaded and held the
KERNAL's values (the image test writes zeros over them): hw_inicio zeroes them · the image's tile table was the
normal AND form while the stub rebuilds the EOR form (the disk test compares the rebuilt tables with the image).

## Disk tests

Both HW disks pass their VICE tests without the ending (the ending's state injection uses the normal map):
`src/c64/presentacion/pruebas/disco_prueba/prueba.py --disco abadia64ks_hw.d64 --juego c64hw --sin-final` 20 checks (disk 247496077dcb, image
063fd01e709f) and `src/c64/ingles/pruebas/prueba_en.py --disco abadia64ks_english_hw.d64 --juego juego_final_en/c64hw
--sin-final` 20 checks (disk f65bd9cc080b, image a6b825abe4c6): the loader, the introduction's pages and music, the
picture, the RAM at principal_inicio equal to the image over what is loaded, the merge tables rebuilt as in the
image, the game's first frames.  The normal disks are unchanged (abadia64ks.d64 cf66187ff3f3 40 checks,
abadia64ks_english.d64 6fb981ae203a 37 checks, both with the ending).

## Open

The monks (hardware sprites would need a raster
multiplexer: not for crowded scenes), the HW disk on real hardware.
