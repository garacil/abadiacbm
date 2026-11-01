<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# abadia64ks on the C64: notes on the memory map of the game's data (H3)

The map itself and the budget: `src/c64/MAPA.md`.  The graphics: `src/c64/NOTAS_GRAFICOS.md`.  This file says how the
inventory was made, what was decided and why, how the pointers are relocated, how the hybrid host checks the
6502 routines against the new layout, and what is still open.

## 1. The inventory

### How every byte of the CPC memory was classified

* `tools/particion64.py` -> `data/cpc64/particion64.tsv` / `.bin`: a recursive descent of the
  Z80 code of `data/cpc64/juego/ram.bin` (the tape's image at 20BEh) from the function entries
  (`funciones64.tsv`, the tables of `src/juego/f_*.c`), the instruction starts the sessions executed, the start-up
  (from 0400h: below it the start-up run executed the tape loader, which the game then overwrites), and the code
  pointers kept in tables (block opcodes 1BEEh, sound commands 0F76h, path exits 08FAh, camera rotations
  1E81h, chr_table).  The routines that read inline data after their CALL are followed by their rule (RST 08h /
  RST 10h script expressions, 1E6Eh CRTC pairs, 3A5Dh jump tables, 3C84h/3BE6h records, 3D07h, 4B71h, 4B7Ch,
  5129h bytes, 4B44h texts), and the opcodes the code switches between RET and NOP are followed both ways.
  Result for 0000h-60FFh: 16072 bytes of instructions, 2176 of inline data, the rest data or unused.  The code
  runs to 60F5h (the last monk scripts are at 6000h-60F5h, past the 5FFFh of the first notes).
* `tools/quien64.py` -> `data/cpc64/accesos/quien.tsv` (functions) and `quien_pc.tsv`
  (instruction addresses): who reads and writes each address as data in the 8 exploration sessions (a patched
  copy of `src/juego/hibrido.c` built in a temporary directory; `hibrido.c` itself is not touched).  **The Z80 core
  writes back on `BIT n,(HL)`** (superzazu's CB handler stores the value it tested): the plain `--accesos` files
  mark those bytes as written (e.g. the words B580h-B71Ch through txt_skip_words 3770h); quien64.py drops those
  writes.  The game is not affected (the same value is written).
* `src/c64/juego/bloques64.tsv` (hand-written): every block the C64 needs, its exact length from the code's use
  (records walked to their FF, tables by their index ranges, the 56 phrases the phrase-voice table covers, the
  239 words they use, the heights to their FF plus the mirror's 5 bytes, the floor maps by their row ranges...).
* `tools/inventario64.py` -> `data/datos64_inventario.tsv`: every block with the bytes the
  sessions read and wrote, the functions that did, the `D64_` names inside, its pointer fields; then every range
  of 0000h-FFFFh not needed, with its reason.  Its checks pass: no overlap, every `D64_` address inside a
  block, the code or a declared range, every byte the sessions accessed as data inside a block (0 problems).

### What the C64 needs

204 blocks (31040 bytes on the C64), by kind: the operands the Z80 code rewrites (93 blocks, 142 bytes: on the
C64 they are variables, in zero page), the 10 code pointers kept in operands (jump vectors), the variable
blocks (kept whole and in CPC order where the code walks or clears ranges, or the state blocks copy them:
28B9h-2967h, 2968h-2BE7h, 37D2h-3869h, the sound state 0C06h-0C54h), the tables, the record arrays, the room
table, the heights, the texts, the graphics (`data/c64graf/graficos64.tsv`), the buffers, and four
C64-only blocks (the block interpreter's stack and the sorted sprite list, which the Z80 kept on its own stack;
the C64 merge tables).

### What it does not need (and why)

* The Z80 code (16072 bytes) and its inline data (2176): they become 6502 code.  The inline data keeps its
  scheme on the 6502: a script is `JSR script_test` followed by the expression bytes, the helper reads them
  through the return address; the expressions hold variable numbers (80h + i of the table 386Ah), never
  addresses, so they need no relocation.  `CALL 3C84h <dw record> <5 bytes>` and `CALL 3A5Dh <dw targets>`
  hold addresses: in 6502 source they are written with symbols.
* The RST vectors and the firmware page (0000h-00FDh), the tape loader's leftovers (00FFh-0102h, 01AAh-0200h),
  dead code and dead bytes (21 small ranges, each with its reason in the inventory), 6128 leftovers nothing
  reads (3D2Ah, 446Fh, B570h, the zeros after the words and the phrases, 7F31h, 9F3Ah, A2F5h).
* The Z80 stack BF53h-BFFFh (the 6502 has its own; the structures the Z80 kept on its stack are C64 blocks).
* The tail of a dead copy of the robes: a new game copies AB59h-AE2Dh to AE2Eh (2126h) and flips it; the
  height buffer overwrites AE2Eh-B06Dh and nothing ever reads B06Eh-B102h (the robes are mirrored while drawing,
  bit 14 of their pointers).  The 6502 new game skips the copy; that range is not mapped, so it is not compared.
* The CPC pixel tables 8F00h-92FFh (built by vid_init_stub): replaced by the C64 merge tables.
* The CPC screen as such (16 KB): the visible part becomes the bitmap and the screen RAM; the hidden part's
  data (the tiles 00h-7Fh after the start-up, the score bar's source at load) are converted and placed directly.
* The initial-state copy 0103h **is kept** (167 bytes): a new game after "PULSA ESPACIO PARA EMPEZAR" (20C7h)
  restores the 16 state blocks from it; the alternative, reloading the game from disk, takes about a minute on
  a 1541.  It is filled at start-up by the 6502 code as on the CPC (game_snapshot_initial_state 310Eh), so it
  costs no disk space.
* The tape routines and their buffer: the save/load packs 1500 bytes of state into 7F80h (the path scratch,
  mapped) and writes them with the game's own tape code: on the C64 a disk call of the platform layer.

## 2. The layout and its decisions

* **Packed, not at the CPC addresses.**  Keeping 6100h-BFFFh at the same addresses would avoid relocating the
  pointers into the room table, the heights and the texts, but the low-area data (records, tables, variables
  at 0103h-5FFFh) must move anyway (they are where the 6502 code goes), and 459 of the 642 pointer fields are
  in those tables or point into them: the relocation tools are needed either way.  At the CPC addresses the
  code area would be $0800-$60FF (22.25 KB contiguous) plus ~6 KB of scattered holes left by the halved
  graphics; packed it is 26961 bytes contiguous.  Packed was chosen.
* **Zero page:** $02-$23 the registers (`zp.inc`); $24-$9D the 93 operands the Z80 code rewrites (they were
  operands of instructions: the hottest data of each routine); $9E-$FF free for the 6502 code.
* **$0200-$07FF:** the code pointers of the operands, then the variable blocks in CPC order; 99 bytes free plus a
  96-byte reserve.
* **The KERNAL:** the game runs with the KERNAL banked out and uses zero page and $0200-$03FF.  Loading the
  ending parchment and saving or loading a game need the KERNAL: the platform layer copies $0002-$03FF away
  (to the path scratch, free between frames), restores the KERNAL's vectors and file tables (RESTOR, CLALL),
  calls it, and copies the game's back; the ending is loaded only when the game is over.  The alternative,
  leaving $90-$FF and $0200-$03FF to the KERNAL, costs 624 bytes (to decide in H4).  With the KERNAL off, the
  NMI vector at $FFFA must point to an RTI.
* **The bitmap's invisible bytes:** pen 3 and the border are black in the three palettes, so $D021 is always
  black; the cells outside the 32 x 24 of the game keep black screen RAM and colour RAM and never show their
  bitmap bytes.  That gives 2042 bytes: 32 at $E000, 23 pieces of 64 (cells 36-39 of row r and 0-3 of row r+1),
  and $FDE0-$FFF9 (cells 36-39 of row 23, row 24, $FF40-$FFF9).  Used: 1171 (32 small tables and the sound
  data); 871 free.  The 6502 code must never clear or draw outside cells 4-35 of rows 0-23 (as the CPC never
  touched its hidden rows after the start-up), and a palette change fills only the game's cells.
* **Under the I/O ($D000-$DFFF):** the tiles (with the objects' graphics in free tile slots, `baldosas`, 3488
  bytes, tile n at $D000 + 16n), then the faces, the door leaf, the day numerals, the light pattern.  They are
  read (and the faces and the door flipped) only with the I/O switched off ($01 = $34): the room drawing
  (iso_draw_room_spiral, spr_tile_to_buffer), the sprite composition and blit, the flips (spr_flip_* 2F00h-2F30h,
  304Fh, obj_door_flip_graphics 0AD6h), hud_draw_objects 4D30h and hud_draw_day_numeral 50D9h.  The interrupt
  handler saves $01, sets $35 for the SID and restores it.  The loader must write this area with the I/O off.
* **$C400-$CFFF:** the four tile merge tables page-aligned at $C400, then the interpreter stack, the sprite list,
  the words, the height buffer, the animation tables.
* **Data below $C000:** packed down from $C000: the 256-byte tables page-aligned first, the graphics (the robes'
  pointers carry a flag in bit 14, so the robes must stay where bit 14 is 0: $8000-$BFFF; `mapa64.py` checks
  it), then the rest from the top in CPC order.  What does not fit a zone falls back here; what is left of the
  gaps, $0200-$07FF, $C400-$CFFF and $D000-$DFFF (graphics only) is filled with datos blocks, biggest first.
* **The path scratch stays one region with the tile buffer**, as on the CPC (7F80h-8EFFh): the sprite buffer and
  the path records at 7F80h, the 24 x 24 path grid at 8174h, the mirror image buffers at 855Ch / 8656h, the
  path queue growing down from 877Eh, then the tile buffer 8780h.  The path searches compute cells past the
  grid (chr_path_room_to_marked 3F92h marks bit 6 of the cell of chr_path_dest, which can be a far coordinate:
  in session 1 the cells land in the tile buffer, 894Fh): with the same relative layout the 6502 code writes
  the same byte.  Cells past 8EFFh would differ (not seen in the 8 sessions).
* **The score bar** is part of the data image: its 1024 C64 bytes go straight into the bitmap rows 20-23; the
  start-up's copy from the hidden rows (hud_rows_from_hidden 3598h) is not needed.  Likewise the tiles are
  placed at $D000 at once: the start-up's copy 8300h -> hidden rows is not needed.  The 6502 start-up keeps the
  rest of sys_startup_init 3568h: palette, initial-state snapshot, mirror, merge tables.

### Conventions for the 6502 code that follow from the map

* Variables keep the CPC's values and units: widths and offsets of graphics in CPC bytes (one CPC byte = one
  C64 nibble), screen positions as the CPC's x (bytes) and y (lines), opcodes the Z80 rewrites as Z80 opcodes
  (the 6502 tests them), tile numbers, room numbers.  Only addresses change (relocated, below).  So the 6502
  state can be compared with the Z80's byte for byte.
* Code pointers in data are 6502 routine addresses (the Z80 entry's routine).
* The structures the Z80 kept on its stack become software stacks: the path queue (in the scratch, as on the
  CPC), the block interpreter's frames (ISO_VM_STACK), the sorted sprite list (SPR_SORTED_LIST).  Their Z80
  stack-address variables (2901h, 2BE1h, 2BE3h, 4473h, 4475h) are class `pila`: not relocated, not compared.
* The screen addresses kept in variables (none found in the data: the CPC keeps positions as x/y, and the
  strip/row constants are code) map by the screen formula of `src/c64/MAPA.md`.

## 3. Pointer relocation (`src/c64/juego/punteros64.tsv`, 642 fields)

| Where | Fields |
|---|---|
| block table 11DDh (88) and block data: each block's tile list, CALL, CALL_KEEP, JUMP operands (182) | 270 |
| sound data: the arguments of the sequence commands F9h-FEh (49) and the 3 channels' sequence and envelope pointers (9) | 58 |
| script variable table 386Ah (65), state block table 3134h (16), chr_param_targets (5), the last assigned variable 390Dh | 87 (class var) |
| code: block opcode handlers (28), sound commands (6), path exits (4), camera rotations (4), chr_table behaviour and flip (12), the operands holding code (10) | 64 |
| graphics: animation tables (24), sprite records +7 (23), faces (4), robes (16, bit 14 a flag) | 67 |
| records and other data: chr_table sprite/record/animation, door permissions, object holders, character records' command buffers, chr_pos_ptrs, chr_record_ptrs, room, heights, room links, words, phrases, hour names, sprite offsets, height buffer, tile buffer, mirror, the operands holding data pointers | 77 + 14 in the initial-state copy |
| Z80 stack addresses (class pila) | 5 |

Rules (`datos64.py` for the image, `src/juego/m6502/sombra6502.c` for the checks): 0000h stays (no pointer); with
flag tagC0 a value C0xxh stays (the monks' animation field holds C000h + 2k, a tag); with flag bit14 bit 14 is
kept apart (the robes); class code -> the 6502 routine of the same Z80 entry when one exists (by name: the
routine is called as the C translation's function), else the value stays; class gfx -> the frame of
`data/c64graf/marcos64.tsv` (inside a frame: line x ceil(w/2) + byte / 2), the mirror image buffers by their
offset; class var or a block list -> the block holding the value, at the same offset; flag virtual -> up to 20h
before the block (the floor-map bases 1E79h, 1F09h, 1F11h point before the map data 1E89h); a value outside its
target stays (stale data: the tape image's sprite records, sound channels and loader leftovers hold such
values, 34 of them, listed by punteros64.py).

## 4. The data image

`src/c64/juego/datos64.py` writes `datos64.s` (one ca65 segment per block at its address: the tape image's bytes
with the pointer fields relocated, the code pointers as `.word routine` when the routine exists, the converted
graphics, the palettes as C64 colours, zeros for the buffers), `juego.cfg` (one 64 KiB image from $0000; the
code segments from $0800 up to the first data segment: ld65 fails if the code overflows) and `conversion64.tsv`.
`construye.sh` runs mapa64.py, punteros64.py, datos64.py, ca65 and ld65: `juego.bin` is the whole C64 memory
(the real game's loader will cut it into what it loads; the variables' initial values are in it).

The night palette needed C64 colours for CPC hardware colours 00h, 1Dh, 04h (added to `src/c64/datos/paleta.tsv`:
grey, purple, blue; Lab gives blue for both 1Dh and 04h, so 1Dh was taken as purple by hue to keep the pens
apart: to be confirmed).

## 5. The hybrid check against the new layout (`src/juego/m6502/sombra6502.c`)

* juego.bin is the 64 KiB image; mapa64.tsv has 8 columns: name, CPC, length, C64, C64 length, mode, zone, kind.
* Modes: copia (copied CPC -> 6502 with the pointer fields relocated; compared in C64 form: the Z80's result
  relocated must equal the 6502's; Z80 stack addresses skipped), graf (personajes, puerta, caras: the graphics
  the game flips in place, converted from the CPC memory at each call with the sprites' per-byte rule and the
  layout of `conversion64.tsv`, compared converted; a self-check at load converts the tape image and compares
  it with juego.bin), conv (C64 constants of the image: compared with the image, they must not change), nada.
  Fast path: a block the Z80 left alone is compared with the 6502 memory as the call started.
* resultados.tsv: `!BLOCK` leaves a block out of a routine's comparison (for the sprite routines, whose sprite
  buffer is C64-format while the CPC's is CPC-format); `>REG:target` relocates a register pair holding a pointer
  at the entry; `REG:target` compares it relocated at the exit (targets as in punteros64.tsv).
* Checked: the three pilot routines plus a fourth written for this, `iso_grid_cell_ptr` (0944h, `camino.s`),
  which reads the height-buffer pointer 28DBh (relocated) and returns IX (compared relocated): 0 differences in
  all 8 sessions (416707 to 1310357 calls each); a deliberate bug (the base's high byte taken constant) gives
  8312 differences in 1500 frames.  Session 1 takes 14 s.

## 6. Open questions

1. KERNAL calls with the game's zero page and $0200-$03FF in use: back them up around the call (planned) or
   give them to the KERNAL (624 bytes); H4.
2. The loader: the image covers $0002-$FFF9, including the area under the I/O and the bitmap (the score bar and
   the gaps' data); the first stage shows the loading screen from VIC bank 2 ($A000), which the game's data
   overwrite.  The loader must write $D000-$DFFF with the I/O off and finish the bitmap after the loading screen
   is gone (or show the loading screen in bank 3 as part of the image).  H4.
3. Room 00h (99 bytes) is in no floor map: if it can never be shown, emptying it saves 97 bytes.
4. Path cells computed past 8EFFh (none in the sessions) would hit different data on the C64.
5. The night palette's purple for 1Dh (above).
6. From the graphics conversion (`src/c64/NOTAS_GRAFICOS.md`): the score bar lettering and the 4-pixel font may want a
   hand-drawn C64 version; object 7's sprite (never in play) points into the library heights and is mapped to
   the lamp's graphic; tile slot 6Dh is converted but never placed by a room.
7. The optional merge tables (1280 bytes) are the first cut if the code does not fit (`src/c64/MAPA.md`, cuts).
