# abadia128ks: the full game (milestone H10)

how to add the 128 KiB rooms.  The choice: the full game (the map *and* the logic of the full game,
certified), taken from the PC EGA version rather than the CPC 6128 one (they are the same game, and I already have
the PC one): the PC version is the reference.  So the reference and the data source are the PC version: the rebuild
`/home/german/Proyectos/abadia/c` (verified frame by frame against the original) and its resources (`/home/german/Proyectos/abadia/c/res/`).

The 6502 game stays the translation of the 64 KiB code (certified against the CPC 64 KiB); abadia128ks adds, under
its own assembler condition, every difference of the full game.  abadia64ks (C64 tape and disk) stays byte for byte
as it is.

## What differs (measured)

Tools (deterministic, outputs in this directory):

* `tools/difiere_funciones.py` → `difiere_funciones.tsv`: the Z80 differences of the 64 KiB code
  against the 6128's (`data/cpc64/dif_total.txt`, 16-bit operands normalised) given to the 64 KiB function that
  holds them: 441 differences in 102 functions; most are the platform (interrupts, tape, the 6128's memory banks,
  drawing) or data inside the monks' scripts.
* `tools/compara_datos_pc.py` → `datos_pc.tsv`: every datum of the 64 KiB map (`D64_NAME`, CPC
  address) against the PC's datum of the same name (`include/direcciones.h`), initial values: 404 data, 71 differ,
  most by a relocated pointer or because they are run-time buffers.

Found so far:

| What | 64 KiB | Full (PC) | Where |
|---|---|---|---|
| start square | Guillermo x 88h, y **9Ch** (the cloister, room 16h), z 0 | x 88h, y **A8h** (the entrance, room 17h), z 0 | 64K: data `GAME_START_POS` BF50h (read by game_main 2110); PC: code 1000:1F41 |
| start day, hour | 1, nona (`GAME_START_DAY/HOUR` BF4Fh/BF4Eh) | 1, nona (ai_clock_init) | same |
| the 16 state blocks (characters, objects, doors, places reached) | | | same values; only relocated pointers differ |
| the hour events (ai_hour_change_events) | | | same logic; the 64 KiB calls a stub for the hour bells (7Ch → 10h at 5A9F, 5AEA, 5B10) |
| room table | 6808 bytes, 129 records, 7 rooms emptied (17h, 27h, 32h, 33h, 35h, 36h, 4Bh) | 9392 bytes | `res/estado/82c2_iso_room_table.bin` |
| heights | ground 921, first 250, library 917 bytes | 1097, 269, 922 (+ the mirror's closing entry `20 62 0B FF`, kept apart on the PC) | `res/pantallas/4ea3`, `56a4`, `res/estado/5aa5`, `bd04` |
| blocks | table 11DDh + data 12F5h/16CEh/1804h | table B71Dh (96 words) + data AECCh (2126 bytes), PC pointers | `res/pantallas/b71d`, `aecc` |
| room links | 304 bytes | 304 bytes, 11 differ | `res/estado/aafd_chr_room_links.bin` |
| tiles | 218 (00h-D9h), 202 shown | 256, 229 shown: 175 the same image at the same number, 22 the same image at another number, **32 new** | `res/graficos/2b22` (PC pens 0,1,2,3 = CPC 3,1,2,0) |
| Berengar's places | | 1 byte differs | `AI_BERENGAR_PLACES` |

The data, read one by one (`datos_pc.tsv`, column «real»: the bytes left once every 16-bit value of the PC that
names the same datum or function as the 64 KiB's is taken as equal): beyond the map, only `AI_BERENGAR_PLACES` +13
(9Ch → A8h: the start square again).  The rest are pointers into graphics (no shared name), run-time buffers and
self-modified operands whose values at load mean nothing.

The code (`difiere_funciones_detalle.txt`, every Z80 difference with both sides; `tools/par_funcion.py
NAME` prints the 64 KiB C and the PC's C of a function side by side):

| Function | Difference | For abadia128ks |
|---|---|---|
| game_init_new_game 3176 | the six characters' orientation (+1) := **0** on the full game, 1 on the 64 KiB | port |
| chr_hbuf_fill_list 346E, chr_hbuf_fill_room 3456 | the full game's height fill is written differently: kinds 0, 6, 7 end the list (the 64 KiB fills them flat), a record wholly outside the window skipped, slopes through chr_hbuf_fill_slope and its deltas, three window origins.  But no list of the PC has a kind 0, 6 or 7 record (the mirror's closing record is `F5`: kind 5), and both algorithms give the same buffer on the PC's three lists (and the library's with the mirror closed) for **all 65536 window origins** (`tools/compara_alturas.py 1` → `compara_alturas.txt`) | nothing to port |
| ai_hour_change_events 5A4F | the same logic; the 64 KiB calls a stub where the full game rings the hour bells (5A9F, 5AEA, 5B10) | sound: later |
| game_compute_percentage 3DA8, game_check_end 3E29 | the ending's flow | this project's own (the ending program) |
| the scripts 4D00h-6214h | byte for byte the same once relocated (the only value: Berengar's place above) | — |
| iso_*, spr_*, vid_*, chr_project, chr_backup_args, chr_path_build_grid... | the block data interleaved with the code (map data), the 6128's bank switching (`OUT 7FCxh`), the 64 KiB's own tile addressing (its DAh-FFh held the heights) and spiral table | data; the C64 has its own drawing (256 tiles now) |
| sys_*, snd_*, tape_*, game_main's start | the machine | ours |

Found by the certification against the PC (below), all ported under `-D COMPLETO`:

| Where | The 64 KiB game | The full game (PC) | Port |
|---|---|---|---|
| obj_set_door_permissions 39F1 (PC 1000:5D0F): ai_random := the first byte of the command buffers | the buffers' order is Malachi, the abbot, Berengar, Severin, Adso (45 bytes each): Malachi's command | Adso first (48 bytes each; the 6128 too): **Adso's** command (it picks Berengar's and the abbot's destinations) | estado_texto.s: `D64_CHR_COMMAND_BUFFERS+4*45` |
| game_main 20EA | `JP` (C3h) written at 4AFCh, which is inside ai_hour_durations: **day 7's tercia lasts C3h x 256 frames** | that entry is 0 (only the scripts end the hour) | principal.s: the C3h not written |
| game_input_and_mirror 2D99 (PC 1000:2DD8) | Q+R on a mirror step: nothing more | ai_hour_frames_left := 0 (the hour ends) | personajes.s |

Known difference kept: the mirror's numeral is random on the CPC (LD A,R, 6128 and 64 KiB) and fixed (1) on the PC,
whose version replaced the read by a RET; the C128 keeps the CPC's.  Also the machine's: the frame budget in ticks,
the sound (the full game's hour bells are a stub on the 64 KiB game), the ending's flow (the ending program).

## The certification against the PC

`src/c64/certifica/pc/`: `construye.sh DIR` builds a copy of the PC rebuild (left untouched) with the two hooks of
`arnes.c` in game_input_and_mirror (the data space dumped at every frame's input step; the CPC keys of the frame held
in sys_keys_down / sys_keys_pending right after the key routine); `corre128.py` runs the C128 build in x128 the same
way (block 0 and the room table dumped, the same keys held after sys_read_keyboard); `compara.py` compares, frame by
frame, every datum with a shared name (237), a 16-bit value being equal when on both sides it names the same datum,
function, command buffer (by its owner) or place of the search queue; 36 data are the machine's and not compared
(listed with their reason).  `lote.sh` runs random sessions (tools/guion_azar.py) of both.

the walk of cabezas_anda.py, 4000 frames: 0 differences.

## The work

1. The data blocks of the full game for the C128 build, generated from `/home/german/Proyectos/abadia/c/res` by a tool: the room table (block 1),
   the three height lists (the library's with the mirror's closing entry as the 64 KiB keeps it), the block table and
   data (their PC pointers relocated: the pointer fields found by `bloques_base.py`'s disassembler), the room links,
   the start square (`GAME_START_POS` = 88h, A8h) and Berengar's place.
2. The 256 tiles: the 64 KiB tile's C64 graphic wherever the image is the same (the edits included), the 32 new
   images converted by the same rule (c64_graficos.py), the masks by the same classes (01-0A opaque, 0B-7F, 80-FF);
   the objects' graphics that the C64 keeps in unused tile slots moved to slots the full rooms do not show.
3. The code differences above under `-D COMPLETO` (set for the C128 and the P500), the C64 images byte for byte the
   same.
4. The certification against the PC rebuild (its headless run, the same keys, the data compared by the shared names).
