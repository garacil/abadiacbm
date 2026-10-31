# Group camino on the 6502: notes (H4)

`camino.s`: the Z80 functions 0000-0982 of `traducidas_camino` (src/juego/f_camino.c, 26 entries) plus 08E5
`chr_room_distance_near` and the pilot 0944 `iso_grid_cell_ptr` (`traducidas_base`, src/juego/funciones.c, both in this
group's address range).  One 6502 routine per Z80 function, with the C names; the Z80's internal labels that the
C keeps as static helpers are local routines named `camino_*`: 03AC `camino_plan_route` (ai_plan_route), 0734
`camino_room_to_room`, 076D `camino_search_to_marks`, 078D `camino_check_result`, plus the drivers' common part
`camino_drive`, `camino_origin` / `camino_hbuf_dest` (the stores into chr_path_origin / chr_path_dest),
`camino_save_iy` / `camino_iy` and `camino_mark_band` (the shared loop 0910 of the four exit bands).

Zero page $9E-$A8 (11 of the group's 12 bytes, $A9 free): `cam_chr` the character of the search (IY kept across
the calls of other groups), `cam_tgt` chr_path_find's target, `cam_ptr` / `cam_n` the chr_table and door walks of
chr_path_build_grid, `cam_drv` the driver / the exit-table index, `cam_dx` / `cam_dy` the room distances,
`cam_o` the orientation in chr_path_add_target_beside.  No BSS.  Nothing runs in the 300 Hz interrupt.

## The routines

Bytes from the listing (`ca65 -l`); calls = the calls checked at the routine's own entry over the 8 sessions
(4472 frames each), in the build named in the last column; cycles = 6502 cycles a call, traps (other groups'
functions, run by the Z80) not counted.  The full build (V0) checks only the routines the Z80 enters from code
that is not this group's (the drivers, and iso_grid_cell_of / iso_grid_cell_ptr / iso_grid_set_origin from other
groups); the inner routines run there inside their callers.  To check each routine at its own entry, variant
builds rename the callers (`vh_` prefix: the host does not know them, so the Z80 runs them and its calls of the
inner routines are checked): V1 without the five drivers, V2 also without chr_path_find and
chr_path_add_targets_around, V3 also without chr_path_search_to_dest, chr_path_via_rooms, chr_path_build_grid,
chr_path_face_target, chr_path_restore_screen_grid, V4 like V3 but keeping the last three.

| Z80 | routine | bytes | calls | cycles | build |
|---|---|---|---|---|---|
| 036D 038E 04A0 04C1 | ai_update_malachi, _abbot, _berengar, _severin | 17 + camino_drive 132 (45 of tables, shared with 04EB) | 26960 each | 1658, 3015, 1705, 1136 | V0 |
| 03AC | camino_plan_route (ai_plan_route) | 191 | (inside the drivers) | | |
| 042D | chr_path_add_targets_around | 38 | 64419 | 1170 | V1 |
| 0442 | chr_path_add_target_beside | 181 | 257676 | 262 | V2 |
| 04E2 | ai_check_planned_move | 8 | 41866 | 15 | V1 |
| 04EB | ai_update_adso | 301 | 26960 | 7327 | V0 |
| 052E | chr_cmd_discard | 31 | 292 | 68 | V1 |
| 05FA | chr_path_find | 340 + 18 (camino_save_iy, camino_iy) | 64490 | 1386 | V1 |
| 06C8 | chr_path_face_target | 42 | 52771 | 41 | V2 |
| 06E3 | chr_cmd_rewind | 13 | 376 | 28 | V3 |
| 06FE | chr_room_coords | 20 | 3583 | 42 | V3 |
| 0713 | chr_path_clear_room_marks | 22 | 3583 | 4295 | V3 |
| 0724 | chr_path_via_rooms | 19 | 3583 | 9713 | V2 |
| 0734 | camino_room_to_room | 74 | (inside 0724, 05FA) | | |
| 076D | camino_search_to_marks | 12 + 39 (camino_origin, camino_hbuf_dest...) | (inside) | | |
| 077E | chr_path_search_to_dest | 9 | 2962 | 11345 | V2 |
| 078D | camino_check_result | 117 | (inside) | | |
| 07E6 | chr_path_restore_screen_grid | 48 | 6177 | 156 | V4 |
| 07FF | iso_grid_set_origin | 33 | 12456 | 76 | V3 |
| 081E | chr_path_clear_grid_marks | 101 | 28587 | 7773 | V3 |
| 082F | chr_path_build_grid | 263 | 6177 | 999 | V4 |
| 08E5 | chr_room_distance_near | 26 | 12624 | 49 | V3 |
| 090A 091C 0924 0929 | chr_path_mark_exit_up, _right, _left, _down | 11 + camino_mark_band 59 | 2072, 424, 284, 435 | 566, 566, 562, 554 | V3 |
| 092E | iso_grid_cell_of | 156 (40 of tables) | 521671 | 108 | V3 |
| 0944 | iso_grid_cell_ptr | 83 | 1456787 | 145 | V3 |
| 0959 | chr_cmd_write_bits | 74 | 31743 | 224 | V3 |
| | **total** | **2478** before the size pass; **2370** after it (budget 2740) | | | |

Bytes and cycles in the table are those of the build before the size pass (2478 bytes).  The size pass
(2478 -> 2370) made the drivers' table high bytes constants (asserted), kept places-3 on the stack in 03AC, shared
Adso's two pairs of chr_mark_hbuf calls (`marks`), the room-distance tests of 082F (`near`), the tail of 0442,
computed chr's floor once in 082F, set the camera's origin in 07E6 through `camino_set_origin` (no IY save), and
rewrote iso_grid_cell_ptr (59 bytes instead of 83, about 104 cycles instead of 145, same results for any L, H).

Checks: before the size pass every build (V0-V4) gives 0 differences in the 8 sessions, and the full build and V2
in the 16 long scripts (largo101-116, 20000 frames: V0 5.68 M calls, 0 differences).  After it: V0 0 differences
in the 8 sessions and in 14 forced-destination tests (a copy of the start state whose ai_malachi_think 52B4 is
patched to LD A,d / LD (37F7),A / RET, d = FC, FD, FE, the places 0-8, and FC / FD with the object held by
293Dh): they run the branches the sessions never reach (03FF-040C, the other-floor branch 0638-06A4 with both
the room graph and the stairs loop, the held conversion of 0442); only 062F (the room links of the second floor)
stays unrun.  The variants of the compacted code were still running at hand-over.  chr_path_find's 1386 cycles are the
mean over its calls, most of which return at once ([0600] odd, or a route already found in the iteration); a
search costs chr_path_search_to_dest's 11345 or chr_path_via_rooms' 9713 (6502 part: grid marks cleared per
candidate, the grid built, the screen grid restored), plus the searches themselves (logica_a).
chr_path_build_grid's 999-1107 cycles leave out chr_fill_height_buffer and the chr_mark_hbuf / door calls.

## The SP and the path queue

The group's own code never uses the stack as data.  The path searches that keep the Z80 stack as their queue
(3F92 chr_path_room_to_marked, 3F9E chr_path_room_search, 438F/4399 the room graph, 434F/41C9 the command
generator walking back from chr_path_solution) are group logica_a's: here they are traps, and the Z80 runs them
on the CPC memory as it is, queue included (877Eh down, through PATH_QUEUE_TOP, the mirror image buffers and the
sprite buffer: one region on the C64, the same relative layout).  The `sp` the C functions hand down is the Z80's
SP for those searches (chr_path_saved_sp 2901h, class `pila`, not compared): the 6502 routines need no
counterpart.  What this group does with the queue is store the entry a search returns in HL into
chr_path_solution 41D4h (zero page $61), which chr_cmd_generate 434F reads back (LD SP,(41D4) in 41C9): the
stubs declare `HL:` with the queue's blocks so the trap returns it as a C64 address, and the comparison of 41D4h
relocates the Z80's value the same way.  No `!BLOCK` exclusion is needed.

**Host fix needed** (src/juego/m6502/sombra6502.c, `reubica_inv`): when the search's HL lands in the mirror image
buffers 855Ch-874Fh (block D64_ISO_MIRROR_BUF_GUILLERMO, mode `nada`: not in `bloque_c64_de`), the C64 address
stored in 41D4h is not relocated back to the CPC at the next trap, so the Z80's 434F does `LD SP,<C64 address>`
and never returns ("llama_z80(434F) does not return" in session 1, frame ~100).  The forward relocation
(`reubica`) handles it through `datos_de`; the inverse must also accept a target block of the field's list that
is not a copied block.  The patch used for all the checks below (a copy of the host built in a scratch directory):

```diff
@@ reubica_inv, default:
         b = bloque_c64_de[v] - 1;
         if (b >= 0) return (uint16_t)((bloques[b].cpc + v - bloques[b].c64) | f);
+        if (c->clase == D_LISTA) {             /* a target block that is not copied (a 'nada' buffer: the mirror) */
+            int i;
+            for (i = 0; i < c->nlista; ++i) {
+                const bloque_t *t = &bloques[c->lista[i]];
+                if (t->cpc >= 0 && v >= t->c64 && v < t->c64 + t->len64 && t->len64 == t->len)
+                    return (uint16_t)((t->cpc + v - t->c64) | f);
+            }
+        }
         if (c->clase == D_LISTA && c->marca == 'v') {
```

## Pointers in registers, traps

Every register the Z80 code passes to another group's function is set as the Z80 sets it (the think routines get
IY, IX and A = 0 with Z set and C clear; chr_probe_ahead_flat gets sys_key_down's A, C and HL untouched; the
tail jumps 410D / 40EB get IY = Adso and IX = his cell, A = the probe bits).  The traps' pointer registers are
declared in `resultados.tsv` (`>IY:` / `>IX:` / `>HL:` at the entry, `IY:` / `IX:` / `HL:` at the exit).  IY is
also restored from `cam_chr` after the calls whose exit IY the code needs, so the routines do not depend on how
the callee leaves it.

## Speed

`iso_grid_cell_of` (779k calls in the sessions) has 2097 iso_floor_base, 22F0 chr_to_hbuf_coords and 0944
iso_grid_cell_ptr inline: within the window the coordinates are 2..15h, so 24 y + x comes from a 20-entry table
and 8 y + x needs no 16-bit work.  It still leaves every register as the Z80 (A, B, DE, HL, IX, CF; C and IY
kept), since other groups' callers (chr_mark_hbuf, obj_door_cells, Adso's driver) pass them on.  The other
calls of chr_to_hbuf_coords and iso_floor_base go to those groups' routines.  `chr_path_clear_grid_marks` (28.6k
calls, 576 cells) writes its three strip addresses into the code (absolute,X: 7.8k cycles a call).

## Things the Z80 does that the C does not show

* Berengar's door mask is the operand 04B0h (script variable A9), not a constant: the 6502 reads
  D64_AI_BERENGAR_DOOR_MASK.  src/juego/f_camino.c ai_update_berengar passes 3Fh (equal while no script writes A9;
  none does in the sessions).
* chr_path_add_target_beside reads the target's +2/+3 as x, y even when the target is an object held by a
  character (bit 7 of +0): those bytes are then the holder's address (punteros64 flag `held`, relocated to the
  C64).  The Z80 reads the CPC address's bytes, so the 6502 converts a held object's field back (C64 ->
  CPC, block D64_CHR_BACKUP) before using it.  Reached when Berengar's destination is the book (FD, day 3 at
  night) or the parchment (FC) while somebody carries it.
* chr_path_find's other-floor branch (0638-06A4) and the fixed destinations FC / FD / FE (03FF-040C) are never
  executed in the 8 sessions nor in the 16 long scripts: they were checked with the forced-destination tests
  above.

## Building

`construye.sh` runs `tools/punteros64.py`, which writes **src/c64/juego/punteros64.tsv** (not the
workspace's): every group's build rewrites that file (same content).  The checks here were built with the same
steps minus that one (the workspace's punteros64.tsv is the copy of src/c64/juego's).
