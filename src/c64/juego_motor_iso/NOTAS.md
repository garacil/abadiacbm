# abadia64ks, H4: group motor_iso in 6502 (Z80 128F-2225) — notes

Source: `motor_iso.s` (all 24 functions of `traducidas_motor_iso` but one, plus the interpreter's internals),
`motor_iso_spr.s.pendiente` (spr_update_char_sprite, see "Pending"), `resultados.tsv` (the group's lines),
`sombra6502_trampa_pantalla.patch` (the host change this group needed; applied to the master).
Zero page of the group: $B6-$BF used (`mi_cell` 2, `mi_oldx`, `mi_oldy`, `mi_ptr` 2, `mi_t0`-`mi_t3`),
$C0-$C1 free.  No BSS.  None of these routines runs in the interrupt.

## Design

* **The block interpreter keeps its frames on the 6502 stack**, word for word as the Z80 kept them on its
  own: the return tag, the saved IX, the loop frames (IX, BC), the positions of PUSH_POS, the CALL frames
  (HL, the SMC bytes, the depth, p1/p2, AF, tag).  END pops IX and does an RTS to its tag, as the Z80's RET:
  the tag of a room entry is `iso_build_room` itself (163Fh is the function's entry), the tag of a called
  block is `mi_call_return` (1DFEh).  The deepest room needs 28 words (56 bytes; model below), on top of a
  shallow call chain.  So the map's `ISO_VM_STACK` ($C800, 64 bytes) is not used.
* **Dispatch**: op = [IX++], `EOR #$FF` is the Z80's index (~op), a split table of handler-1 and an RTS (the
  Z80's PUSH DE / RET); 39 cycles.  The map's copy of the opcode table (`D64_ISO_BLOCK_OPCODE_TABLE`, $E3A0,
  56 bytes) is not used: 14 of its 28 handlers have no name in any table, so their words could never be
  relocated to 6502 addresses.
* **Variables keep the CPC values**: the step opcodes 24h/25h/2Ch/2Dh at 1C60h, 1C66h, 1D06h, 1D29h; the code
  words 12C0h (12C9h / 12C2h) and 1DFCh (17F1h / 17EEh) hold the CPC addresses (no 6502 routine has those
  entries, so the host keeps them as they are); 2013h holds the C64 floor map base (floor 0: 10h before
  `D64_ISO_FLOOR_MAPS`); 2656h the 6502 camera transform from `D64_ISO_CAMERA_ROTATIONS` (relocated by name).
* **iso_tile_run** keeps the Z80's interface (the step opcode after the JSR, return past it); the handlers
  enter `mi_tile_run` with the step in A (TILES_RIGHT reads the SMC byte 1D06h), so the inline prologue
  (23 bytes) only serves the host's check.  **vid_set_crtc** reads its pairs after the JSR and calls
  `plat_crtc` (A = register, X = value).
* **iso_put_tile**: tables of the tile buffer's rows (indexed by y - 8, with 8 zero bytes before them for y
  below 8) and of 6 (x - 8) + 3 (8 bytes FFh before them); the cell through (mi_cell),y.  The 12C2h form
  (after building) is never reached in the game (iso_put_tile runs only while a room is built); it returns A
  as the Z80 does but does not write cell + 780h (CPC 8F00h, the pixel tables, not on the C64 map).
* **The fill**: the CPC byte becomes one C64 byte: a uniform CPC byte (its four pixels of one pen; the game
  fills with 00h and FFh only) gives that pen's bit pair four times (a non-uniform byte would take its first
  pixel's pen; the general `sim` conversion was 36 bytes more and was dropped in the size pass).  The play area
  is bitmap rows 0-19, 256 contiguous bytes each from $E020 + 320 r: 20 `STA abs,Y` per index, 27 000 cycles.
  The tile buffer clear: 8 stores per index, 240 indexes, 10 800 cycles.
* Register results not set because nothing reads them: DE of iso_put_tile; BC after NEXT and after a called
  block's return (every reader sets C first, B only travels in loop frames); HL, DE, BC of the fills and of vid_set_crtc; the
  registers iso_draw_room, iso_build_room and iso_update_camera_room leave (callers read none).  Declared
  results in `resultados.tsv`.
* `iso_fetch_word` does not declare its IX at the exit: a JUMP whose operand ends block data 1 (CPC 160Fh-1610h)
  leaves IX = 1611h, one past the block, which the checker cannot relocate (on the C64 it is the next block's
  start, $76F4); the JUMP overwrites it.

## Size

`motor_iso.o` CODE: 1945 bytes after the first version, **1835 after the size pass** (budget 4300), plus 35 in
`motor_iso_spr.s.pendiente`.  The pass: the fill byte for uniform bytes only (-36), the CALL frame's five
1BE9h-1BEDh bytes and their return by loops (-24), iso_update_camera_room (the x / y test, the orientation by
bit 4 of 28C6h / 28C7h, the chr_table entry copy by loops: -26), iso_build_room's x / y decoding by a loop
(-6), iso_rotate_cam2 as orientation 1 twice (-9), vid_set_crtc (-6).  The speed paths were kept: the tile
buffer row / column tables with their 16 guard bytes, the inline tile operand of the tile runs, the unrolled
clear (8 stores) and fill (20 stores).  Possible further savings, not taken: the dispatch tables (56 bytes) could
live in a bitmap gap (the map's unused copy of the opcode table at $E3A0 has exactly that size) if the map gave
the 6502 code a segment there; iso_tile_run's inline prologue (23 bytes) is only used by the host's check (the
handlers enter mi_tile_run with the step in A); the fill as a loop over rows (-38 bytes, +24 000 cycles a room).

## Pending: spr_update_char_sprite (208C)

It calls chr_project (2632h), which returns to its caller's caller when the character is visible (POP DE at
267Dh), and ends with JP 2589h into chr_animate (chr_show_frame).  Neither has a table entry, so stubs64.py
cannot make traps for them (and a trap could not follow chr_project's return anyway).  The routine is written
(`motor_iso_spr.s.pendiente`, 35 bytes; assembles) with the Z80's conventions: chr_project's 6502 routine must
drop its own return address (PLA PLA) and RTS when the character is visible.  Rename it to `motor_iso_spr.s`
when personajes exports `chr_project` and `chr_show_frame` (HL = the frame, C = the depth, IX, IY); until then
iso_update_camera_room calls it as a trap (the Z80's 208C).

## Checking

* The 8 sessions (`--hasta 4472`), master host: 0 differences, 6502 routines 369518-1293428 calls each.
* Routines nested in iso_draw_room are not seen on their own when iso_draw_room is a 6502 routine (the Z80
  runs it whole), so variants of the workspace with fewer exports were run on the 8 sessions (scratch tree at
  the same depth, `variantes.sh`): v2 without iso_draw_room (checks iso_build_room, iso_clear_tile_buffer),
  v3 also without iso_build_room (iso_tile_run, iso_expression, iso_fetch_word, iso_fetch_operand,
  iso_operand_value, iso_block_depth), v4 also without iso_tile_run (iso_put_tile_step), v5 also without
  iso_put_tile_step (iso_put_tile at all its 64240 calls): 0 differences everywhere.
* The 16 long scripts (20000 frames, master host): 0 differences in the full build (490 rooms drawn,
  3.7-6.8 million 6502 calls each) and in v5 (iso_put_tile checked at 308 606 calls, iso_fetch_operand at
  382 558, iso_expression 38 330, iso_block_depth 20 923, iso_fetch_word 30 340).
* A Python model of the room builder (`modelo_salas.py`, after f_motor_iso.c) run on all 129 rooms in both
  states of the mirror entry, on the CPC tape image and on the C64 image (relocated block pointers): identical
  tile buffers (the loop skip's byte scan meets no relocated pointer byte that would change it); operand codes
  used: below 60h, 61h-71h, 82h; opcodes used: E4, E9, EA, EC, EF-FF (never EB TILES_LEFT, ED/EE P_DEC,
  E5-E8, the count form of a tile run); deepest stack 28 words (room 04h).
* Never called in the sessions nor the long scripts: iso_rotate_cam2 (no room of orientation 2 is entered), iso_put_tile_times
  (no block uses the count form), the 12C2h form of iso_put_tile.

## Cycles (8 sessions)

| routine | calls | cycles/call |
|---|---|---|
| iso_draw_room (without iso_draw_room_spiral, a trap) | 102 | 339 409 |
| iso_build_room | 102 | 301 616 |
| iso_clear_tile_buffer (+ the fill) | 102 | 37 727 |
| vid_fill_play_area / _ff | 42 / 13 | 26 920 |
| iso_tile_run | 44 268 | 358 |
| iso_put_tile | 64 240 | 134 |
| iso_put_tile_step | 63 610 | 160 |
| iso_expression | 8 435 | 180 |
| iso_fetch_operand / iso_operand_value | 80 606 / 18 257 | 71 / 56 |
| iso_fetch_word | 6 919 | 39 |
| iso_block_depth | 4 703 | 32 |
| iso_update_camera_room | 26 960 | 125 |
| iso_floor_base | 1 164 709 | 20.6 |
| util_add_bx_al | 2 232 755 | 20.0 |
| iso_orient_relative | 120 266 | 13 |
| iso_rotate_cam0 / 1 / 3 | 23 108 / 11 431 / 2 719 | 6 / 22 / 22 |
| vid_set_crtc | 46 | 234 |

A room (session 1 profile, 18 rooms): put_tile 26 %, dispatch 21 % (1 850 opcodes a room), the tile runs'
own work 12 %, the fill and clear 11 %, the steps 5 %, NEXT 3 %, expressions 3 %, block entries 3 %.

## Tools (scratch, not part of the build)

A temporary directory, not kept:
`modelo_salas.py` (the room model), `variantes.sh` (the export variants on the 8 sessions), `largos.sh` (the
long scripts), `perfil.sh` + `perfil.py` (cycles per label with a host whose 6502 loop counts cycles per PC,
`PERFIL6502=file`).
