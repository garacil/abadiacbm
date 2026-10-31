# abadia64ks — state of the work

Read `HITOS.md` first (the milestones and the rules).  This file keeps what has been learnt and the
next steps, newest first inside each section.

## Where things are

| Path | Contents |
|---|---|
| `HITOS.md` | milestones H0–H5 and the rules |
| `original/archive.org/` | `amstrad_abadia_del_crimen_64.dsk` (archive.org item `amstrad_abadia_del_crimen_64`, "transtape from the original cassette, 64k", md5 7c54c569e500b784cb67e9d59deb1cbe) and its metadata |
| `tools/terceros/cc65/` | cc65 from GitHub, built (`bin/cl65`, `ca65`, `ld65`, …) |
| `tools/terceros/exomizer/exomizer2/src/exomizer` | exomizer 2 (the bitbucket download of 3.1.2 is gone; built from the github archive bitshifters/exomizer) |
| `data/.venv` | Python venv with SkoolKit 10.1 (Z80 simulator and disassembler) |
| `tools/` | the tools (see HITOS.md) |
| `data/cpc64/` | outputs on the CPC 64 KiB version: `disco/` (files of the disk), `src/juego/ram.bin` (memory when the game starts, PC=20BE), `run4/` (a run to the first room, screenshots), `diferencias_codigo.txt`, `dif_total.txt` |
| `data/cpc128/` | `pistas.bin`/`pistas_rev.bin` (sector stream of the CPC 6128 disk of the reference copies, forward and reversed), `memoria.bin` (the 128 KiB game's main memory view rebuilt from it) |
| (removed) | the copy of the full C rebuild, the starting point of H2: the rebuild lives in `/home/german/proyectos/abadia/c` |

System packages installed for the project: `vice-sdl2` (x64sc, c1541, petcat), `atari800` 7.2.1
(AUR), `cc1541` 4.2 (AUR), `dir2atr` (AUR, AtariSIO tools), `asciidoc`, `lame`.  AUR builds in
`/home/german/.cache/aurbuild-abadia64ks/`.

## The lamp, the ending and the parchments' pace

* The ending says `CARGANDO EL FINAL`, not the cassette instruction.  Both parchments halve the per-pixel busy wait,
  from 352 to 176 iterations (0x160 -> 0xB0); the font, the picture, the graphics modes, the page turns and the
  music's tempo are unchanged.  The ending keeps all twelve original pages, then adds the Commodore credits and the
  dedication to all of Opera Soft's team: `text2.bin` is 2598 bytes and fourteen pages.
* The light mask in `logica_a_spr.s` processes two nibbles a byte and reuses a ten-byte row mask four times: the
  same BSS, 80 bytes less code, the game still in 64 KiB.  `src/c64/juego_final/prueba_lampara.py` compares the old
  and new assembled routines against an independent pixel model: 512 cases (clipping, both sides, all four
  horizontal offsets, the line counter's wrap), identical pixels; the mask takes 5.14 times fewer cycles over that
  sample, the whole drawing routine 2.41 times fewer in eight variants of the mirror room's state with the lamp's
  drawing enabled (CPU benchmarks, not whole-game frame rates).
* The test disk's VICE test passes every page and music check of both parchments, the loading picture's mode, the
  loaded RAM and frames 50 and 200: the introduction takes 341.7 emulated seconds instead of 534.2, the fourteen-page
  ending 696.4 against 1001.2 for the earlier twelve.  Eight 4001-frame sessions of the 6502 game: 0 differences.
* The idle melody became a soft SID triangle on voice 3 with no filter resonance; the footsteps and the beeps keep
  the pulse; the bells on voices 1 and 2, the notes' frequencies, the timing and the envelope rates are unchanged
  (`src/c64/juego_final/vice/flauta.py`, `doc/revisiones/flauta/`).
* The automatic player of the videos waits before Adso's locked door and keeps him opening it until Guillermo is
  close enough for both to cross; its seven regression tests pass, victory with all three mirror numerals included,
  and a complete rehearsal won at 100 % (frame 36871) with all nine introduction and fourteen ending pages shown.
  The recordings use VICE's CRT emulation (`-VICIIfilter 1`, double scan on, OpenGL filtering off) at full speed;
  the rehearsals use filter 0 and warp.

## The sound and the interrupt, every version

* The notes started with something like a hard blow.  Comparing by ear a discarded build and the
  current one, both did the same, so the instrument had to change a little, towards a recorder.  Measured first: the SID writes (VICE's sound device `dump`) of the discarded build, the 64ks and the 128ks
  were the same writes in the same order; the strike was the voicing (src/c64/plataforma/psg.s): every tone a pulse with
  an 8 ms attack to the top and a 24 ms decay to its level.  Now every tone is the **triangle** with one rate 3
  (`RATE`: 24 ms up, 72 ms down and release; one rate, so the SID's envelope delay bug never comes in); the footsteps
  keep their pulse and their envelope (psg_paso: voice 3's attack and decay 8 / 24 ms while it plays them).
* The interrupt routines brought back in their most optimised form: round 5's interrupt (IRQ-1, IRQ-2) and the
  sound's hot path (SND-1) re-applied by hand on the restored base (not round 5's code moves): plat_irq with sys_tick
  inline and the sound's call as a self-modified JSR / BIT (`-D JUEGO`, every game build; objetos_sonido.s writes the
  opcode where a channel starts, the last one ends and at snd_silence_all), plat_psg_tono, s_interrupcion's X and Y in
  $C5-$C6.  The SID's writes stay the same (the 128ks: 1235 writes over 2000 frames, identical).  The keyboard's
  round-5 change was left out (it broke the project's VICE tests).  Found on the way: on the C128 plat_irq fell
  through into plat_nmi's body (2 MHz switch) at every tick; each has its own RTI now.

## Speed, round 5: twice the CPC's speed with no keys

* The aim of this round: a bigger gain; more efficient interrupts (the music is not complex, its cost can come down,
  and the keyboard scan needs only O, P, Q, A, SPACE and the game's option keys, not the cursors); Severin's fix as soon
  as it is verified, the interrupts, and everything else that makes it faster.  The notes, measurements and tools of
  the round were in `src/c64/optimizacion/ronda5/` (removed with old/).
* **The real frame, measured in VICE** (stops at checkpoints, a CIA 2 cycle counter; frames 1-2000, no keys, before
  this round): the game's own work 95.7 %, the 300 Hz interrupt path 3.1 % (a tick with nothing to do costs **96
  cycles**: the "~850 cycles a tick" written below in round 2 was wrong), the keyboard scan 0.8 % (~1 070 cycles a
  frame), the idle wait 1.0 % (only in frames 5-50, where the 36-tick budget binds; from frame 51 the budget is 0 and
  every cycle saved shortens the frame); the VIC-II's bad lines take 5.47 % of every clock figure.  In real play (keys,
  footsteps) the interrupt path is ~23 % of the frame, mostly the sound.
* **The biggest single block**: with no keys, from VICE frame 674 Severin repeats every frame the SAME failing route
  search (1 328 calls with identical inputs, 91 152 cycles each: 52 % of the no-keys run; the Z80 does the same;
  azar5 has it too, azar8 the Abbot's same-room searches).
* **Done** (all measured on sim65 / the host / VICE, each result reproduced twice from scratch, then re-checked):
  - **M4, the route-search memo** (`src/c64/juego_final/camino_memo.s`, hooks at camino_room_to_room's first and last
    instructions in camino.s): the last failing search's inputs (a 93-byte key: the destination, the character, the
    floor's map and target test, the doors, +2..+5 of the six records, the camera room, la_busca's square check, the
    12 door bytes of the room links) and the compared bytes it left (its outputs); a call whose key equals the stored
    one replays the outputs and returns.  Its exactness rests on two invariants proven by reading every writer and
    checked dynamically (census of 2 x 75 runs, 0 violations): the room links' bits 0-5 change only in the 12 door
    bytes (only obj_set_door_permissions writes them), and their bits 6-7 are 0 outside a floor search.  A new writer
    would break exactness and the whole-game check would show it.
  - **PCG, Adso's marks cleared in proportion** (`camino_limpia.s`, called instead of chr_path_clear_grid_marks after
    his search on the screen's height buffer): only the cells his search queued, the border and chr_path_dest's cell,
    when the buffer is known clean apart from them (`m_limpio`; the first clear and any after Adso's step test are
    full ones).  One proportional clear can cost up to 19 355 cycles against the 7 226 of a full one (244 of 20 677
    single-clear frames in azar1-8; none with no keys); the net is a saving in every session.
  - Their 14 pieces (code and state, 781 bytes) live in the bitmap's invisible bytes, declared in `mapa64.py`
    (`PIEZAS_CAMINO`: fixed places, each block its whole row so the rest of the map does not move) and turned into the
    segments CODEMEMO01-10 / CODELIMPIA01-04 by `datos64.py` (every map block named `codigo_*`, as SPRHW's
    `codigo_hw*`); the code area is untouched by them.  (The first packaging edited the generated
    juego.cfg by hand and broke the project's construye.sh: rebuilt through the generators, the images are
    byte-identical to the verified ones: C64 b67ac089… and checked 558a274f… for M4+PCG alone.)
  - **C2b, the interrupt, the keyboard and the sound** (+32 bytes; `-D JUEGO` in construye.sh's C64 branch):
    IRQ-2: `plat_irq` (interrupcion.s) does sys_tick's work inline, the sound's test as a self-modified opcode
    (`BIT s_interrupcion` while no channel plays, `JSR` while one does: objetos_sonido.s writes it where a channel
    starts or the last one ends; an empty tick 96 -> 69 cycles); KBD-1b: `teclado.s` scans only the keys whose CPC code
    the game reads (Q A O P, SPACE, R, S N, Y, L, CTRL + `<-`, RUN/STOP, INST/DEL, the digits of the save slot) and
    joystick port 2; one read with every scanned column selected returns at once when nothing is down (1 097 -> 239
    cycles a frame); the cursor keys, SHIFT, K and Z (the CPC's own aliases of turning and of Adso), C=, RETURN, the
    F-keys and the other letters and signs are not read any more (`src/c64/plataforma/TECLADO.md`); SND-1: the AY period's
    two writes at once (`plat_psg_tono`, psg.s), s_interrupcion's X/Y in zero page $C5/$C6.  Verified: the SID write
    sequence identical to the previous build's (pasos.py), every tick identical on 49 states, the keyboard bitmaps
    identical in every frame of azar1 and of a script of every kept key.  KBD-2 (a fast path in sys_key_down,
    −2 000 cycles a frame with no keys, −64 in play) is assembled only with `-D CON_K3`: the project's VICE tools
    that hold keys by writing the bitmaps (pasos.py, flauta.py, src/c64/ingles/partida/sesion_en.py) would need one line.
* **Checks of the combined build** (scratch tree with the project's sources and tools): comprueba.sh default, --juego,
  --largos, --juego --largos, dias.sh --rutinas and dias.sh: **0 differences everywhere**; the Spanish disk's VICE
  test 40/40 and the English 37/37 passed; the platform's keyboard test passed with the new map (its 94 cases;
  `pruebas/teclado_mapa.py` LEIDAS); pasos.py (the sound and the ticks, both scenes): all checks passed (14 checks: the ticks over 899 frames in both scenes with none lost, the footsteps, the music's start and end).
* **Measured in VICE** (`vice/arranca.py OUT 1 400 2000`, PAL C64, no keys): frames 1-400 31.2 -> **29.6 s**,
  1-1000 99.1 -> **64.3 s**, 1-2000 255.7 -> **122.5 s**; CPC 6128 33.8 / 112.8 / 294.2 s: **C64/CPC 0.88 / 0.57 /
  0.42**.  In real play the gain is smaller (host, whole game: −2.3 to −3.3 % of the frame in the sessions, −29 % in
  azar5 where Severin's search repeats; the interrupt part −3 % in play, −2.6 % with music).  The frame budget is 0
  from frame 51, as on the CPC: the C64 runs as fast as it can, now much faster than the CPC in those scenes.
* Memory: the code area ends at $714D (3 bytes free below $7151; English $714E, 2); the gap pieces take 781 of the
  bitmap's 871 free invisible bytes (90 left).
* **Found and not caused by this work** (open):
  - With the no-keys script driven from the 49 day/hour states (a pairing dias.sh never runs), the whole-game check
    differs in 22 states: D64_ISO_KEEP_FLAG (CPC 1BE5h) 90h/80h from frames 824-2844 and D64_SPR_TABLE (2AF6h) 00h/01h
    from frames 1033 or 1801; the same with the sources before that work: an old
    latent difference of the 6502 port, to be investigated.
  - `src/c64/plataforma/pruebas/prueba.py sid` does not compile against the current src/juego/m6502/6502.c (MemUsados, the memory
    tracer's array, is not declared in its memoria_gancho.h).
  - The SPRHW build (record only) does not link (659 bytes over its CODIGO_FIN) and la_busca's LAB-B assumes
    D64_PATH_QUEUE's low byte odd, false in the HW map.
  - pasos.py's walk held over frames 10-277 loses 4 ticks in the previous build too (a DI span; not investigated).
* Measured, verified, not integrated (need the room of the 392 dead data bytes or a decision): HB1 + DP1 (the height
  buffer: −8 200 host cycles a frame with no keys before the memo, worth nothing after it), LAB-C (−337 after the
  memo), S-P1 (sprites, −1 450 in the sessions), M2 (the Abbot's searches, azar8 −22 300: ~230 bytes beyond the gaps).
  **D64_AI_UNUSED_3CAD is NOT dead**: Jorge's book scene stores 0 through the script variable that points at it
  (logica_b_guiones.s:805); removing it would corrupt code.  The loader change M3 breaks the HW disk.

## Speed, round 4: the C64 ahead of the CPC

* The goal: to beat the CPC itself in speed.  The sprite drawing optimised as far as it goes, loops
  avoided where possible, jumps avoided by placing routines one after the other when it can be done, the RAM recovered
  earlier kept for these improvements, and any improvement found applied.  The rules for it: no VIC-II sprites; cycles
  only from the official sources (cc65's sim65 core `src/juego/m6502/6502.c`, the host's instrument; cc65 docs); every
  change MEASURED on sim65 with real game memory and reproduced twice from scratch; the full check chain at 0
  differences before anything is integrated.
* **Premise corrected first**: OPTIMIZACION6502.md's "frames 1-2000: 294.2 s CPC / 373.2 s C64 (1.27)" was round 2's
  figure; after round 3 ESTADO.md already said 296.87 s (1.009), and VICE (`vice/arranca.py OUT 1 400 2000`,
  the image) gave 34.3 s / 112.8 s / 294.7 s for frames 1-400 / 1-1000 / 1-2000 against the CPC's
  33.8 / 112.8 / 294.2 s: the C64 was already at the CPC's speed.
* **Done (all measured, all verified, integrated):**
  - personajes.s / estado_texto.s, nine changes (+335 bytes): sys_key_down / sys_key_pressed inline (no sys_test_key /
    sys_key_bit calls), chr_load_params unrolled, spr_save_old_rect unrolled, chr_mark_hbuf's marks inline,
    chr_probe_cells' rows unrolled, chr_fill_height_buffer's 576-byte clear as 72 x 8 `sta abs,y` with the operands
    re-patched when the buffer pointer changes, hb_span with util_clip_span inline, hb_draw's flat records by a tight loop,
    obj_set_door_permissions straight from the 5-byte table (the proposal notes: `propuestas/personajes.md`).
  - logica_a_cam.s, la_busca "LAB-B" (+286 bytes): the floor's own loop, the exact-mode test as a 3-byte JMP patch,
    la_c = cell - 49, the y-neighbours of the room expansion inline (the x-neighbours through the generic `cuadro`), the
    queue read indexed by X with self-modified page bytes, the slopes as subroutines, a flat fast path.  LAB-C (the four
    neighbours inline, +482 bytes, ~1 800 cycles per frame more) did not fit: it needs the 392 dead data bytes.
  - camino.s: chr_path_clear_grid_marks and chr_path_clear_room_marks unrolled x2 (+67 bytes).
  - logica_a_spr.s: la_tramo's last-line operand set once per column, la_baldosa's opaque-tile copy four bytes a step
    (+15 bytes).  The big sprite change (la_capas inline + the tile-buffer test hoisted per rectangle, -7.5 % per
    composed rectangle, +185 bytes) was left out for the bytes: it saves nothing in the no-keys window.
  - Placement (the `colocacion/saltos6502.py`, deterministic): 13 tail `jmp X` turned
    into fall-throughs by moving X after its caller (same file, the previous routine ending in RTS/JMP), 1 `jsr/rts`
    tail call, 23 branches to an RTS inverted over an `rts` in place, 1 `jmp` inserted where a fall-through was broken;
    branches checked in range in BOTH builds (the checked build's extra bytes made one `beq/jmp` pair 147 bytes apart:
    excluded).  -16 bytes, ~225 cycles per frame.  The ordering changed in camino, estado_texto, logica_a_cam,
    logica_a, logica_a_spr, logica_b, motor_iso, objetos_sonido, personajes, principal.
  - Memory: the build ends at $712D, 35 bytes below CODIGO_FIN $7151 (722 before).
* **Checks (the scratch tree with symlinks to the project, the sources identical to these):** comprueba.sh (8 sessions,
  routine by routine, 1 472 210 calls), --juego (8 x 4001 frames), --largos (16), --juego --largos (16), dias.sh
  --rutinas (49 states + the ending), dias.sh (49 + the ending): **0 differences everywhere**.  The ending needed one
  fix in the instrument, not the game: the whole-game check compared D64_TXT_CURSOR at plat_final, where the CPC has
  printed "PON EL CASSETTE EN MARCHA" (25 characters, x = 38h) and the C64 "CARGANDO EL FINAL" (17, x = 28h) by design;
  `juego6502.tsv` now has `final @28E8 1` (sombra6502.c: `final @XXXX N` = not compared at the ending only).  That
  difference was there before this work (the restored base's sources and the earlier host give it too).
* **Measured (host, sum of the checked routines' cycles):** no keys frames 1-2000: -12.9 %; the 8 sessions: -7.9 % mean.
  **Measured in VICE** (`vice/arranca.py OUT 1 400 2000`, PAL C64, no keys): frames 1-400 34.3 -> **31.2 s**, 1-1000
  112.8 -> **99.1 s**, 1-2000 294.7 -> **255.7 s**; CPC 6128 (Caprice32) 33.8 / 112.8 / 294.2 s: **C64/CPC 0.92 /
  0.88 / 0.87**; the screens at frames 400 and 2000 identical to the previous image's.
* Not integrated, measured and verified, for later (they need the 392 dead data bytes freed):
  LAB-C instead of LAB-B (+196 bytes, ~1 800 cycles per frame no keys), the sprite la_capas change (+185 bytes, -2 450
  cycles per composed rectangle, 1.1 % of a session frame), chr_probe_cells x4 and the x4 unrollings.  The SPRHW
  (rejected, record only) build: the la_busca change assumes D64_PATH_QUEUE odd (false in the HW map) and the sprite
  change does not link there (28 free bytes): the HW build is not maintained by this round.
* Milestone H7 (HITOS.md): only the characters' HEADS as VIC-II hires sprites with a black mask, later.

## The pixel editor of the C64 graphics

* The aim: a program that shows the characters' graphics of the CPC / PC EGA on one side and the
  Commodore 64's on the other, to edit them by hand pixel by pixel, every sprite of each character, switching from one
  to another, with save and undo; a blinking pixel-sized pointer, the colour chosen with the digits, SPACE paints, O
  left, P right, Q up, A down; the scenery too (the previous background graphics, retouched by hand).
  `tools/c64_editor.py` (PySide6 6.12 from
  pacman, on both machines): left the PC EGA graphic (c64_compara_pc.py's decoder; the tape image for the tiles), right
  the C64 one as the build makes it (trazos for Guillermo, Adso, faces, robes; detalle per tile) plus the hand-edited
  lines; groups Guillermo, Adso, Monjes·caras, Monjes·hábitos, Escenario (208 tiles 01h-D9h but the object slots).
  Keys O P Q A / arrows, Space, 0-3, U/Ctrl+Z, Ctrl+Y, S, N/M, Tab, R / Shift+R, D (difference marks), + -, H.
  `--hoja OUT.png [--grupo G]` contact sheet without a window; `--lista`.
* Animation (added after trying the editor: an animation option and its speed):
  V plays / stops Guillermo's or Adso's walk cycle exactly as the game selects frames (chr_select_frame on the tape's
  tables 2CF0h / 2D10h: counter n = 0..3 -> entries 0-3 for camera-relative orientations 0 and 3, entries 4-7 for 1
  and 2; orientations 2 and 3 mirrored, as the game flips the graphic in place), G changes the orientation, , and .
  change the speed (40-1000 ms a frame, 150 by default); the tables are read from ram.bin, not copied by hand.  A
  mirrored frame can be edited: the cursor, the mouse and the keys map to the stored, unmirrored graphic.  The monks
  are not animated (their body/face/robe selection was not read yet).
* The edits: `src/c64/datos/editados64.txt` (the format of retoques64.txt: CPC address of the graphic's first line, line,
  one character a C64 pixel; only the lines that differ from the rule; atomic, deterministic write).  `c64_graficos.py`
  puts them over the rule in the normal build (not --hw; `C64_EDITADOS` names another file) and stops the build on a
  line of the wrong length, outside its graphic or at an address that is not editable (the door, the objects, the
  font...).  The tiles' key is the tape address 8300h + 32n.  Offscreen test (QT_QPA_PLATFORM=offscreen, in a
  scratch directory): keys, paint, undo/redo, restore, switching, mouse, save/reload, the sheet, the build changing
  only the edited lines' bytes (14 + the two tiles) and rejecting bad files; the English tape image has the same
  graphics at the same addresses (characters, robes, faces, tiles).
* The tiles are the ones (`baldosas.bin` md5 b4acba4b…, the same in data/c64graf_sim, in
  the restored base and at $D000 of the current image); one Spanish disk (b6fd6942…) differs from the
  morning's (cf66187f…, on hal9000c) only in the stream `juego`: the same needed bytes (0 differences after the
  loader's model), the older one also carried 3953 unneeded bytes at $9CCD-$AC4C of an older map.
* Verified by running: hand edits outside the CPC pair do not break the checks.  A scratch tree with
  symlinks to the project (herramientas, juego, data/* but a fresh c64graf) and a copy of src/c64/juego_final as
  src/c64/v_editor was built with an edits file that puts, in every one of the 232 editable graphics with an interior
  pair (12 character frames, 14 faces, 6 robes, 200 tiles), one pixel of a pen in neither CPC pixel of the pair;
  `./comprueba.sh` (8 sessions, 1 472 210 calls) and `./comprueba.sh --juego` (8 x 4001 frames) gave 0 differences.
  (The routines checked with `PANTALLA:par` — spr_blit_to_screen, spr_tile_to_buffer, iso_draw_tile — are entered
  from the CPC's own buffers converted by the host, so the edited pixels never reach that comparison; the whole-game
  check compares the memory with the C64's own graphics.)  The edits take no byte of memory.
* The decision: the memory recovered by the size analysis (722 bytes free, 392 dead) is reserved for the
  speed work; the edits take no byte.

## The characters' and monks' graphics, rule `trazos`

* The rule: the C64 graphics must have the same shape as the PC EGA ones (the CPC inks), compared pixel for
  pixel, by a deterministic program; the engine is not to be touched; the colours stay.  Verified: PC EGA and tape frames
  are the same pixels (characters, faces, robes).  New rule `trazos` (`tools/c64_mitad.py`, in
  `c64_graficos.py` for Guillermo, Adso, faces and robes; `src/c64/NOTAS_GRAFICOS.md`): exact least-cost choice per line that
  keeps every stroke of the drawing whatever its pen (the monks are black with orange strokes, Guillermo orange with black
  ones) and drops one-pixel shading steps; replaces `aislado` and the hand retouches (kept, unused).  Comparison and
  sheets: `tools/c64_compara_pc.py`; the previous conversion kept in `data/c64graf_sim`.
* Rejected after samples on hal9000c's desktop: 1:1 (every PC pixel a C64 pixel, twice as wide); hardware hires sprites
  for the black strokes (an engine change).  Another C64 conversion (video frames) was measured: its thin
  lines are 2 hires pixels, multicolour like ours.
* Both disks rebuilt (`src/c64/presentacion/pruebas/disco_prueba/construye.sh`, `src/c64/ingles/construye.sh`); `src/c64/presentacion/pruebas/disco_prueba/prueba.py` and
  `src/c64/ingles/pruebas/prueba_en.py` pass (logs `resultados_prueba_trazos*.log`).  The door and the objects still use `sim`.
* The English full-playthrough recording was stopped at 38 min for this work
  (an interrupted recording, not kept); to be recorded again with the new graphics
  (`src/c64/ingles/partida/graba.sh`, then `entrega_en.py`).

## The English (British) release (src/c64/ingles)

`src/c64/ingles/construye.sh` makes `src/c64/disco/abadia64ks_english.d64` beside the Spanish disk (untouched): the 56 phrases and their dictionary, the hour
names, a real W in the font, "Day" in the score bar, the end-of-game screen, Y:N (the key Y gives yes), the two parchments (a fresh translation, new
glyphs I F W w), the loading picture's title "The Abbey of Crime", English file names.  Everything English fits where the Spanish fitted (words 1193 of
1257 bytes, phrases 748 of 924, text1.bin 1452 of 1491, text2.bin 2510 of 2598, the same page counts).  Checked in VICE (introduction pages 9 of 9 and the
ending's 14 of 14 as the page model, music as the CPC's, the loader reading GAME, the game's frames).  What it is, how it is made, what it leaves out and
what still needs a visual review: `src/c64/ingles/NOTAS.md`.  Not translated: the repository's own Spanish directory names, file names and the few Spanish words in
comments and notes (measured and reported separately).

## What is known (H1, measured)

### The C64 pictures: every graphic and the map (src/c64/mapa)

`src/c64/mapa/graficos_c64.png` (every graphic in its C64 format, address and colours) and `src/c64/mapa/mapa_c64.png` (a
plan per floor and the 95 screens drawn by the 6502 game itself on the host's 6502 core, passages and staircases
marked); how they are made: `src/c64/mapa/README.md`.  Measured there: the 64 KiB version's emptied rooms (17h, 27h,
32h, 33h, 35h, 36h, 4Bh) also have heights no character can reach, so the cloister is an L of its north and west
walks; the doors and the door table are the full game's.

### The original cassette is the reference

The disk image used at first is a 2006 repack of the tape version; the original cassette (two dumps,
byte-identical) is the reference: `data/cpc64/juego/ram.bin` and
`data/cpc64/inicio_juego/` were replaced by the tape's (`data/cpc64/cinta/`,
`tools/cinta64.py`); the repack's images are in `data/cpc64/dsk_cngsoft/`.  They
differ in 446 bytes of code (the tape routines and 3EC6h-3EE9h); from the start, the 8 sessions give
the same memory outside them, with the same instruction counts, and `prueba.sh` still gives 0
differences.  See RECORTES.md, "Loading".  The first stage, the ending and the loading picture are the
same; the loading screen's look is not (the original builds the picture up as it loads, the repack
opens it from the centre: the C64 first stage still imitates the repack and must change).

### The loading screen of the original, and its C64 plan

* Measured (cpc_carga.py from 0133h of `cinta/primera_etapa.bin`): after the parchment (which leaves the
  screen memory at 0) the loader sets mode 0, the border black (14h) and pens 15..0 from its table, so
  pen 0 is pink (07h): the screen shows pink until the picture's bytes arrive, FFFFh downwards (the 8th
  line of every row, bottom to top and right to left, then the 7th...).  The GNU front-end does exactly
  this; so does the C64 ("The C64 loader and disk" below).
* C64 plan (with the game's loader, H4, since the game's screen will be in VIC bank 3 and the game must
  load around it): during the load, $D021 = pink and every cell re-encoded so that black is a cell
  colour (pattern swap per cell, computed at run time from the stored black-background picture; 111 of
  800 cells lose a colour while loading, against 68 for the final picture); the nibbles revealed in the
  CPC's byte order at a pace tied to the load; at the end the stored black-background picture and
  $D021 = black.  (Done the other way round: $D021 black, pink a cell colour while the cell loads; below.)

### How the disk repack loads (tools/cpc_carga.py)

* Disk `ABADIA64`: `ABADIA64.BAS` (13426 bytes at 0170h: one BASIC line `CALL &1A0` plus the packed
  first stage), `ABADIA64.BIN` (39048 bytes at 0100h, packed game), `ABADIA64.BN1` (6466 bytes at
  0100h, packed; not loaded at start).  Packer: CNGSoft's LZ2PACKER (2006), a backwards LZ whose
  bit buffer lives in register I (unpacker at EF0E).
* Order: the BAS stage unpacks and runs **the intro parchment first** (code at
  6000h, PSG music, text written slowly, space skips it), then sets mode 0, shows the loading screen
  (32×24 characters: CRTC R1=32) and loads `ABADIA64.BIN`, unpacks it from BFFFh downwards and starts
  the game at 20BEh with SP=C000h.  `BN1` is presumably the ending parchment (to confirm: the game
  keeps the name `ABADIA64.BIN` at 343Ah and must patch it to `.BN1`).
* The simulator needed: no ROM write block (SkoolKit is a Spectrum tool, `z80sim.py`), the HALT
  return address after the HALT, the 300 Hz IM 1 interrupt, the firmware ink calls, the keyboard
  matrix through the PSG, CRTC geometry in the screenshots.

### What the 64 KiB version removed (compared with the full game's data)

* Room table: 129 records at 6100h–7B98h (6808 bytes) against 9392 bytes in the full game.
  **Rooms emptied** (record `02 FF`): 17h (the full game's start room), 27h, 32h, 33h, 35h, 36h, 4Bh.
  Almost every other room lost decoration (20–30 % fewer block entries); the library rooms
  64h–73h are untouched or nearly (66h, 68h, 69h, 6Ah, 6Bh, 6Eh identical).
* Floor grids (room numbers per cell): identical to the full game.
* Height maps of the ground and first floors changed (816/1097 and 192/269 bytes differ in the
  aligned comparison; to be decoded), the second floor (library) barely.
* Room links (`chr_room_links`): 11/304 bytes differ.
* Start: Guillermo starts in the cloister at x=88h y=9Ch (Adso 86h,9Dh), not at the entrance.
* Texts (words, phrases), font, route-search tables: identical.  Graphics: CPC format, to be
  compared with the 6128 graphics (tiles removed, e.g. the skulls of the secret passage and the
  crosses of the windows according to other sources).
* Code: 12724 of 14819 instructions identical to the 6128 code after normalising 16-bit operands
  (`dif_total.txt`); the remaining blocks are data noise, relocation and real changes, to review.

### Graphics and rooms of the 64 KiB version (tools/salas64.py)

* Tiles at 8300h: tile n = 32 bytes at 8300h + 32n, CPC mode 1, 4 bytes × 8 lines (same place as in
  the 6128 game).  76 of the 256 tiles differ from the full game's (rearranged/replaced), so the
  64 KiB version must be drawn with its own tiles, blocks and rooms as one set.
* Block table at 11DDh (96 pointers), block opcode handlers at 1BEEh (28 words, same handlers in
  the same order as the PC's B7F4h), opcode dispatch at 1C2Dh (`LD A,(IX+0); INC IX; CPL; ADD A,A`).
  Room table at 6100h.  Height lists: ground floor 7B98h (215 entries), first floor 9E40h (59),
  library 9F60h (222), chosen by the code at 2883h.
* Drawing (measured: room 16h built by the model equals the real CPC screen in 40439/40960 pixels,
  the rest are the two characters): tiles 0Bh–7Fh pen 2 transparent, tiles 80h–FFh pen 1
  transparent, opaque tiles 01h–0Ah draw pen 2 as pen 3; PC colour c = CPC pen (3,1,2,0)[c] in the
  tile data.
* In-game day palette: pen 0 = hw 06 (cyan 0,128,128), pen 1 = hw 0E (orange), pen 2 = hw 03 (pastel
  yellow), pen 3 = hw 14 (black), border black.  Night and other palettes still to record.
* Start room of the 64 KiB version: 16h (the cloister), Guillermo at 88h,9Ch.

### C64 display proof of concept (src/c64/poc)

* `src/c64/poc/prueba.sh [ROOM]`: room → C64 multicolour bitmap (each CPC pixel pair → one multicolour
  pixel, the right one), CPC inks → C64 colours from `src/c64/datos/paleta.tsv` (cyan 3, orange 8,
  yellow 7, black 0), cc65 program, `.d64` with c1541, VICE on Xvfb :99, `captura.png`.  Works.
* Hires (2 colours per 8×8 cell) is not an option: 399 of the 640 cells of room 16h have 3 colours.
* VICE needs `HOME` with `.local/state/vice` (it crashes when it cannot open its log file) and
  `-sounddev dummy`; `-limitcycles N -exitscreenshot F` ends the run with exit code 1 and the image.

### The introduction parchment on the C64 (src/c64/pergamino): done

* `src/c64/pergamino/prueba.sh [CYCLES...]` builds the first stage with the whole disk (`src/c64/presentacion/pruebas/disco_prueba/construye.sh`:
  `src/c64/disco/abadia64ks.d64`, which replaced `pergamino.d64`) and takes VICE screenshots;
  `CFLAGS=-DSALTA_TRAS=n` stops the parchment after n characters (as if space were pressed),
  `AUTOSTART="-autostart ../disco/abadia64ks.d64"` boots from the disk instead of injecting the PRG.
* A direct port of the CPC first stage: the text (8400h), the gothic glyphs (6772h), the borders,
  the page turn (686Ch, phases of 65FDh), the same delays as the CPC measured in the simulator
  (glyph pixel 7.3 ms, space 27 ms, line 0.55 s, page 1.8 s), as deadlines on a CIA timer
  (`espera.s`), so the drawing time is absorbed.  Hires bitmap with two colours per cell resolved as
  the pixels arrive (`pixel.s`); the red capitals are hardware sprites that what is drawn over them
  clears; the CPC parchment inks (pink, dark red, black, red) as C64 light red, red, black, red.
* Music: the CPC's AY player translated to C (`musica.c`, the reference) and to 6502 (`musica.s`);
  both produce exactly the CPC's 2828 register writes over 19130 ticks (64 s), checked by
  `data/pruebas/prueba_musica.sh` (host gcc and cc65's sim65 against the CPC log).  `sid.s` plays
  the AY registers on the SID (pulse 50 %, AY period -> SID frequency through a table of the 96 note
  periods, the AY's logarithmic volume -> sustain level, a gate on increases); a 300 Hz CIA interrupt
  that skips the KERNAL's own work (else ticks were lost: 587 of 600 in 2 s; now 600).  A recording
  from VICE agrees with the CPC's notes in 96 % of 50 ms windows (`compara_audio.py`; the rest are
  note boundaries); `src/c64/pergamino/audio/` has the CPC reference (synthesised from its register
  writes, `ay_a_wav.py`) and the C64 recording to listen to.
* **SID voicing** (the music given a SID touch, making the most of this magnificent chip;
  merged from src/c64/optimizacion/sid/, NOTAS.md there): the same notes, frequencies bit for bit and every gate
  change on the same AY write of the same tick (checked: `prueba.py sid`, `pruebas/sid_pergamino.sh`).  Parchments
  (`sid.s`): the melody a pulse sweeping 25-50 %, the bass a pulse through a resonant low-pass that opens on each
  note and closes in ~0.4 s, the ending's vibrato line a thin pulse with a softer attack and release, the intro's
  chord notes on the triangle; the vibrato periods in the table (`sid_tabla.py`).  Game (`plataforma/psg.s`):
  pulse-width modulation on every tone (stepped at the period writes the game makes: no per-tick cost), voice 3
  (music, footsteps, beep) through a resonant low-pass, envelope 8/24/24 ms; noise unchanged; +7 bytes, the
  interrupt -1 cycle a tick with the music.  Recordings before/after (VICE 6581, and 8580):
  `src/c64/optimizacion/sid/audio/`.
* After space: the loading screen of the CPC 64 KiB version (a mode 0 picture of 32x24 characters,
  converted 1:1 to C64 multicolour, `c64_pantalla_carga.py`), opened from the centre in 17 steps like
  the CPC's CRTC effect (the CPC also shows the picture re-laid while the width grows; here the final
  picture shows through the growing window), then a loader in the cassette buffer loads "juego" with
  the KERNAL and starts it.  (Replaced by the tape's look: "The C64 loader and disk" below.)
* Timings on the C64: writing pace within ~2 % of the CPC.
* **The page turn** (the page turns were bad and slow, and the previous page's red capitals showed
  through; `src/c64/pergamino/revision_pagina/NOTAS.md`, pictures CPC / C64 before / after there): measured in
  Caprice32 (control socket, a reading every frame) the CPC's turn takes 3.035 s, the C64's took 20.3 s and left the
  red capitals (sprites) on the new page (pixel.s's `mira_capitales` read the capital bits the wrong way round, so
  nothing cleared them until the end).  Now `pagina.s` (assembled at the end of pixel.s): the corner in three passes
  in assembly, the borders put back as the blank parchment's cells, the capitals cleared after each step where the
  corner has passed (exactly the CPC's), and each step waiting with espera.s's deadline for the CPC's measured step
  (20.00 / 18.47 ms + 0.569 ms a band): 3.037 s, the same pace frame for frame; the least wait left 1.8 ms (the
  ending's music takes 40 % of the CPU).  sid.s's interrupt saves the zero page unrolled (388 -> 168 cycles a tick).
  Still different: 74 border cells show the CPC's black outline red (the data generator's colour rule, 993 pixels;
  a majority rule would leave 661: tools/c64_pergamino_datos.py, proposed).
* Loading from disk at the 1541's normal speed: the first stage (27 KB) takes ~65 s; compression
  (exomizer) or a fast loader to be decided.
* The first stage ends at $7600; VIC bank 2 ($8000 cells, $8400 sprites, $A000 bitmap under the BASIC
  ROM); the game it loads must stay below $A000 while the loading screen is shown (to revisit when
  the game's memory map is fixed).
* The ending parchment: done as a separate program (below); the game must load it at its end.

### The ending parchment (src/c64/pergamino, -DFINAL): done

* On the CPC 64 KiB version `ABADIA64.BN1` is the ending, loaded from tape by 3346h when the game is
  solved (100 %), run at 6000h for ever; the same parchment code as the first stage with another text,
  another tune and the borders elsewhere (RECORTES.md, "The ending").  Simulated with
  `cpc_carga.py --imagen cpc64/juego/ram.bin --call 3346 --ret BE80` (new options: start from a memory
  image; a call that returns at once, here the firmware restart copied to BE80h).
* `tools/c64_pergamino_datos.py` now reads every data address from the stage's own code
  (text at [6028h], borders at [655Bh] [6567h] [6573h] [657Fh], music at [601Ah]), so the same tool
  makes `datos.c` (intro, `perg_inicial`) and `datos_final.c` (ending, `final_6000`).
* `main.c -DFINAL` = the ending: the CPC's loop (text until space; music stopped; black; music
  restarted with `musica_reinicia`, 6019h-6022h, channel A only; blank parchment; text again).
  `final.prg` (ends at $5117) is on the disk as "final"; `PRG=final.prg prueba.sh CYCLES`.
* Music: `data/pruebas/prueba_musica.sh final` runs the CPC ending with space pressed at 30 s (one
  stop and one re-entry) and compares tick by tick: musica.c and musica.s identical to the CPC
  (14584 register writes over 19521 ticks); `prueba_musica.sh inicial` still identical (2827 writes).
* The blank parchment is no longer drawn byte by byte at run time (1536 calls of pon_byte, 3 s against
  the CPC's 0.2 s): the generator emulates pixel.s's colour rule and writes the 92 border cells
  (bitmap and colours); VICE screenshots of the blank parchment and of 40 characters are identical to
  the old build's.  Start to screen on: 0.5 s (CPC: first character at 0.41 s after 3346h).  Writing
  pace: 2-3 characters behind the CPC after 32 s (~2 %, as the intro).
* Test builds: `-DSALTA_TRAS=n` (as if space after n characters), `-DCONGELA_TRAS=n` (stop there for
  ever, for screenshots).  VICE autostart (prgmode 1) reaches `main` at 3.08 M cycles.

### The characters' graphics on the C64 (as close to the CPC's as possible)

* Adso's C64 frames had no eyes.  Cause: the C64's multicolour pixel is two CPC pixels and the rule
  sim keeps the pen first in orange, yellow, black: the faces' one-pixel black features (eyes, mouth) vanish into
  the skin, and the robes' fold lines into the orange.  Tried (renders in a scratch directory, not kept): black first
  (too dark), the rarer pen of the neighbourhood (noise), a blurred best-match search (stripes): no pair rule or
  optimiser draws a face 2-3 C64 pixels wide.
* Done in the tools, landed after the speed work (the optimisers build from data/c64graf): rule **aislado** for
  Guillermo and Adso (sim, but a black pixel with orange or yellow on both sides in its line wins: folds, arms'
  outlines, eyes) and **hand retouches** `src/c64/datos/retoques64.txt` (whole C64 lines of a frame; now Adso's faces:
  forehead, an eye, cheek, mouth in his 6 frames), in `tools/c64_graficos.py`.  The host no longer
  recomputes the flipped graphics from the CPC bytes: each unit the game flips in place (conversion64.tsv's new
  6th column: the characters' sub-blocks, the door, the faces 20 lines at a time) is the image's, or the image's
  flipped as the 6502 flips it (src/juego/m6502/sombra6502.c, convierte); 0 differences before and after.  With the new
  graphics in a link tree: 0 differences routine by routine and frame by frame (sessions 1, 5, 8), VICE frame 400
  compared with Caprice32's.
* Next (after the speed work): review the main characters (Guillermo's face, the monks' faces and robes)
  against Amstrad captures, more hand retouches; and the colours as they look: the CPC's teal floor and bright
  orange have no C64 equal (the hue choice of src/c64/datos/paleta.tsv gives cyan and orange; VICE's default palette
  shows the cyan much lighter than a real C64's colodore one: take the comparison captures with colodore).

### The play reports (to look into)

1. Pressing walk and then, without releasing it, turning right or left, Guillermo seems to turn the wrong way;
   releasing advance and pressing the turn arrow, he turns correctly.  Likely the C64's keyboard (playing the C64
   build in VICE with the PC's arrows): up is SHIFT + CRSR down and left is SHIFT + CRSR right
   (src/c64/plataforma/TECLADO.md), so while up is held SHIFT is down and CRSR right reads as left; up+left and
   up+right give the same matrix.  The game's own letters (A walk, K left, L right, Z Adso) and joystick port 2
   have no such ambiguity.  To see: confirm which build was played; whether anything better is possible on the C64
   (e.g. VICE's keymap flags, another key layout) without leaving the CPC's controls.
2. Trying to take the key in the library, the monk never steps aside in the one position where Adso may pass and
   take it for Guillermo, not even after the meal of the second day.  To see: which key and
   monk, the scripts' conditions (src/juego/f_logica_b.c, f_logica_a.c), and whether the CPC 64K original does the same
   (the C64 and GNU builds equal the Z80 frame by frame, so a difference would show only on paths no check reached).
   Malachi's script (52B4 ai_malachi_think, src/juego/f_logica_b.c): key 3 lies on his table (record 2B72: 35h, 35h,
   height 13h) and is Adso's key (bit 1 of his objects).  Malachi is at his desk in every hour but these: noche and
   completas (his cell), prima (the church), tercia of day 5 (Severino's cell), visperas (he goes to the table,
   takes key 3 himself, sends Guillermo out of the upper floors, warns the abbot, closes the left wing).  At sexta
   (the meal) and nona he stays.  At his desk, when Guillermo is close and presses "andar" he moves to block the
   passage (destination 3) and back to the desk (2) when Guillermo goes.  The first reading was that the key could only
   be taken while Malachi is away: WRONG (an inference from part of one routine, not verified).  In fact the key is
   taken with Malachi there: Guillermo stands so that Malachi moves against the table and lets Adso pass, and Adso
   picks it up; at night it is never there because Malachi takes it at visperas.  In the game Malachi never
   stepped aside in that one position, even after the second day's meal.  To do: reproduce the manoeuvre on
   the original (the hybrid host's pure Z80 with a key script from a day-2 state, and Caprice32), with every script
   and object rule involved read first (Malachi's places, Adso's movement and pick-up, the take masks), then the
   same on the builds.
   **Verified (data/llave3/NOTAS.md, prueba.sh)**: key 3 is record 2B77 (object 6, Adso's take mask 02 only) on
   the table at 35,35; Adso takes it from 35,37 facing north, the corner of a bay whose entrance Malachi closes
   from his desk.  With Guillermo on the scriptorium's lower floor under the west end of the long table (31,3E,
   day 2 nona), one press of "andar" sends Malachi off his desk (52B4, 5402-5461: destination 3); when he turns
   back and Guillermo stands still he stops against the table (37,37) and the way is open; holding Adso's key and
   only turning Guillermo, Adso goes round the table into the corner and takes the key (frame 1212 from
   data/puro/estados/ram_d2h4.bin).  Any later "andar" sends Malachi back to block.  Eight standing places
   work (barrido.tsv).  The original (hybrid --solo nada, and Caprice32 with the script injected), the C64 game
   (--juego6502: 0 frames with differences), pure C and the GNU build do exactly the same.  The C64 difference
   is the keyboard: SHIFT turns cursor down (Adso's key) into cursor up, so turning left with SHIFT + CRSR right
   (VICE's PC left arrow) while holding Adso's key reads as "andar" and Malachi blocks again; with Q A O P, Z K L
   or the joystick it works.
   The GNU build needs no change for this (checked): src/juego/gnu/abadia64ks.c reads each PC arrow as
   its own CPC cursor key (SDL scancodes UP, RIGHT, DOWN, LEFT -> keys 00h, 01h, 02h, 08h), no SHIFT involved, and
   the manoeuvre gives the original's result pixel for pixel.  Still to do: the manoeuvre with real key presses
   (the runs injected the key script), in GNU and in VICE on the disk.

### The presentation and parchments on the disk (src/c64/presentacion): done

* The parchment's own C code (cc65, September 2016: "/home/german/classic computers/Commodore/abadia": abadia.c, io.c, manuscrito.c, the
  pp.bin, text1.bin, abadia.koa) for the parchments and the loading picture, as it was: the parchment first, then on
  space the picture while the game loads; the ending the parchment too; the credit on the introduction.
  `src/c64/presentacion/NOTAS.md` has every change as a diff with its reason; the files as they were in `original/`.
* "abadia" (the first stage) is the program built with the line (cl65 --register-vars -Cl -Ois; the c64.cfg rewritten
  in cc65 2.19's form with the values: no cc65 since 2.13 links the file).  Changed in the code: the order in abadia.c
  (the picture read first, shown after the parchment by `gameload` on the game's screen), `musicstart()` after
  manusini, one `kbhit()` test a character (a key ends the parchment at once, as space on the CPC), `free(ytoscreen)`
  (the ending runs it over and over), the sizes of the two grown files.  io.h is not changed (the parchment stays in the
  layout, bitmap $C000).  sid.s calls the KERNAL's keyboard scan every fifth tick, so the conio key tests work with the
  300 Hz music interrupt.
* The text1.bin is the tape's introduction text byte for byte, and the pp.bin's font the tape's; the ending's text
  (text2.bin, 2409 bytes) is the tape's (final.bin at [6028h] = 7400h) in the same codes.  The credits ("version
  commodore: / German Luis / Aracil Boned / garacilb@gmail.com / 2016 - 2026") on a page of their own after the tape's;
  the font lacked 0, 6, @ and B: drawn in its style and appended to pp.bin (datos.py).
* The load: the picture stays on the game's screen; the stream loads first what the screen does not show, then a mark
  (the loader blackens the side cells: columns 0-3, 36-39, row 24) and the game's data in them; no pink, no CPC picture.
* Checked (`src/c64/presentacion/pruebas/disco_prueba/prueba.py`, VICE, three runs): every page of both parchments equal to the page model, which is
  the CPC's page for page (`src/c64/presentacion/pruebas/paginas_cpc.py`, the GNU build's screen at every frame: intro 8
  pages, ending 12, exact); the music's AY writes as the CPC's and as musica.c's; the picture on the game's screen
  through the load; the RAM at principal_inicio as juego.bin; the game's frames; the ending reached by the game's own
  code from a state one step from 100 %, loaded from the disk, written, stopped and restarted by keys.  Figures and
  pictures: src/c64/presentacion/NOTAS.md, `src/c64/presentacion/resultados/`.  Times: "abadia" 29.3 s, the parchment on the
  screen at 70.9 s, "juego" 109.1 s (the CPC 501.8 s), "final" 26.6 s.
* Left to decide (NOTAS.md, "Original timing observations and remaining choices"): with the music the busy-loop pace is slower (page 1: 74 s against
  54 s without music and the CPC's 52 s; the ending x1.6); any key ends the parchment; the ending re-reads pp.bin each
  pass (~10 s).  Found on the way: the C64 game's end screen showed the percentage with one digit short ("10 POR
  CIENTO" at 100 %): principal.s's game_check_end copied 2 of the 3 digit bytes the CPC writes (3E61-3E63); fixed
  (the third copied too), and plat_final's stub sets the drive the ending came from as cc65's current
  one ($BA): from drive 9 the ending's program looked for its files on drive 8.

### The music on the C64: lost ticks, the footsteps

While the abbot walks, the music at the meal of the second day sounds bad, as if the interrupts and the sprite drawing
were in the way; the same happens now and then while walking.  Then: while the music plays the footsteps are better
silent (or, once the music starts, until it stops), and the footsteps at half: they were too loud.

* Measured in VICE (the C64 build from data/puro/estados/ram_d2h3.bin, day 2 sexta, 30 s, every DI span and every
  interrupt timed): the music lost ticks.  `chr_cmd_write_path` (a monk's path rebuilt, the Z80's DI ... EI around
  its queue walk) ran up to 16907 cycles with the interrupts off (24 times in 30 s, all over a tick: up to five ticks
  lost); `t_frase` inside the interrupt (a phrase's character: the abbot talks while he walks) up to 9590 cycles (50
  times over a tick); `hud_say_now` 4783 once.  Fixed, the C64 build only (the checked build keeps the Z80's DI / EI
  for the IFF the host compares): chr_cmd_write_path and hud_say_now without their DI (the 6502 reads the queue
  through la_s; the phrase is inactive while its line is cleared), t_frase with a CLI after its beep starts (the
  Z80's EI there, snd_start's): a tick that falls due while the character is drawn comes nested, once.
* Verified in the original (the C reference and the sound data, not from memory): the footstep (21DD, Guillermo's
  only) takes channel C whatever plays there; the music starts on channel C only when it is idle, after 50 frames
  without a movement key (3CEA), and never ends on its own (F9 at 106Eh + 7Eh jumps back to its start); the phrases'
  beep (t_frase) takes channel C too.  So on the CPC walking cuts the music, and it starts again from the beginning.
* On the C64 (objetos_sonido.s, segment BAJO): while the music plays no footstep starts; the first
  one left out makes the music end at its end (its F9 byte becomes FFh until the music starts again), then the
  footsteps come back; standing still it loops as on the CPC.  The beep of the phrases is as on the CPC.
* The footsteps at half (psg.s psg_paso / paso_c): their volume rises 0 -> 12 a step a tick, and the SID voicing
  gated voice 3 again at each rise, so it stayed at the attack's top all the rise.  Now the footstep is gated once,
  with the sustain level 4, and its falls set half the usual sustain level; the rates unchanged (the SID's envelope
  delay bug).  It need not be exactly half.
* Room: segment BAJO in the free $079D-$07FF (datos64.py writes it into juego.cfg; the disk's loader loads every
  segment): 88 bytes used.  Code + data + BSS end at $714C (limit $7150).  The checked build keeps its platform
  mirrors at $07C0-$07FF (plataforma.inc, sombra6502.c PLAT_*), so a C64 memory converted from a CPC state by the
  host (src/c64/presentacion/pruebas/estado_final.py) had them over BAJO's code and hung: estado_final.py now puts the
  C64 image's BAJO back after the host's dump (found by the disk test's ending run).
* Checks: the checked build unchanged (comprueba.sh, --juego, dias.sh, --largos: 0 differences).  In VICE,
  src/c64/juego_final/vice/pasos.py (the interrupts counted against CIA 1's underflows; the SID's writes from VICE's dump
  device, voice 3's envelope computed with reSID's algorithm: the monitor's ENV3 reads are stale): the game-start
  scene (a step or two, stop, the music starts but sounds bad, as if distorted), 105.7 s: 57 ticks
  lost before (all through the first minute, while the abbot walks to Guillermo and talks), 0 now; the lunch scene,
  125.3 s: 0 lost, the music uncut by 73 footstep calls, ended at its end (58.3 s, loop byte FFh), 17 footsteps
  after it; the footsteps' RMS 73 against 132 with the earlier voicing (-5.1 dB; mean 47 against 95).
  src/c64/presentacion/pruebas/disco_prueba/prueba.py on the new disk: 38 checks pass.  On the way: the interrupt instrument
  (src/c64/plataforma/pruebas/interrupcion/medida) was broken (its variables at $C3F0, which the game writes) and would
  have overwritten BAJO: moved to the stack page's bottom with a guard the run checks; it measures again (empty window
  36.4 cycles, frames 1-400 107.5 a tick).  src/c64/presentacion/pruebas/disco_prueba/prueba.py's music check assumed the music restarts in the tick
  it stopped; an interrupt can come between musicstop's musica_para and its musica_irq_off: the re-entry is now
  logged at the tick before the next window.
* Not done: the GNU build keeps the CPC's footsteps (the change was for the C64; the GNU build still to decide).

### The C64 loader and disk: done (the first stage is now the presentation: above)

* `src/c64/disco/` (`NOTAS.md`): `construye.sh` makes **`src/c64/disco/abadia64ks.d64`**: "abadia" (the first stage: the
  introduction parchment, then the loading screen and the game's loader), "juego" (the game's image as a stream with
  the loading picture interleaved), "final" (the ending, loaded by the game's plat_final).  `prueba.py` runs it in
  VICE (1541 with true drive emulation, Xvfb :99, binary monitor only while stopped); all checks pass.
* The loading as the tape's: after space the screen is pink (VIC bank 3, the picture's place = the game's cells 4-35 of
  rows 0-23, as the CPC's loader sets the game's CRTC geometry), then the picture's nibbles appear in the CPC's byte
  order (line 7 of every row, bottom to top, right to left, then line 6...), paced by the load: a counter of the CPC
  block's position moves 65024 / (bytes of the stream) a byte read, so the picture is complete at 26.1 % of the load
  (CPC 25.2 %); then the game loads under it; then the display goes black and the game starts (principal_inicio).
  $D021 stays black and pink is one of each cell's three colours while it loads (97 of 768 cells lend their least
  used colour to the pink and get it back, one screen RAM byte each, when the picture is complete), so the picture's
  bytes are the final ones and the cells outside it stay black with the game's data in them (`pantalla.py`).
* The loader (`src/c64/pergamino/cargador.s`, 769 bytes at $C3E8, in the tiles' merge tables, which the game's start-up
  3607 rebuilds) reads "juego" with OPEN/CHKIN/CHRIN, no interrupts, $01 = $34 but around CHRIN; it holds $0200-$03FF,
  $90-$9D and the score bar (where the picture is) at $BB00-$BFFF/$C700 and the stack page, and puts them in place at
  the end.  The bytes left out (the game needs none at its start: `libres.py`, the hybrid with them garbled, 0
  differences in the 8 sessions): BSS, the free zero page, the stack page, the screen RAM, $C800-$C86F, the bitmap's
  free bytes, the merge tables (rebuilt: compared in VICE at the game's first frame).
* The stream (`flujo.py`): data compressed by its own LZ (`lz64.c`, optimal parse, Elias gamma; 55467 -> 40489
  bytes; exomizer would give 38195), the picture's 6144 bytes, the colour fixes, a checksum; checked by a model of
  the loader.  In VICE: the RAM at principal_inicio equals `src/c64/juego_final/c64/juego.bin` over the 60719 bytes the
  game needs; frames 50 and 200 pixel for pixel as the image written straight into the RAM.
* The picture's colours (the loading picture could be better, compared with the Amstrad's;
  `doc/revisiones/pantalla_carga/NOTAS.md`): `pantalla.py` decoded the mode 0 pens with bits 1 and 2 swapped (checked
  pixel for pixel against Caprice32's display of the same memory), so 39 % of the pixels had the wrong colour (red
  letters blue, the red cloth yellow, ...).  Now the CPC's decoding, colodore with CIEDE2000, one C64 colour a pen
  (the robe's dark cyan dark grey, to keep it apart from its grey), the substitutes chosen by distance: the mean
  distance to the CPC 18.8 -> 6.1; 82 cells lend a colour to the pink while loading (97).  The same swap is in
  src/juego/gnu/abadia64ks.c's `dibuja()` and tools/cpc_carga.py's screenshots (to fix there).
* Load times (VICE, the KERNAL's serial speed, ~380 bytes/s): "abadia" (20053 bytes; 20880 then)
  51.4 s (53.5 s), the CPC's first stage 82.1 s; "juego" 124.7 s (160.6 s without compression), the CPC's block 20h
  501.8 s (65025 bytes at 130 bytes/s, `tzx.py`); "final" 48.8 s, the CPC's 82.4 s.

## Size measurement (H3 input)

### The translated game measured with cc65 (`tools/mide_juego.py`)

* `mide_juego.py src/juego/` compiles every `f_*.c` with cc65 (-O -Os -Cl -t c64) through a shim juego.h
  (`tools/mide_juego/`: ds[] external, accessors as macros) and counts the CODE bytes of
  each function, the hybrid host's wrappers and checks apart; `data/mide_juego.tsv`.
* Four groups merged (camino, objetos_sonido, motor_iso, personajes): 30.6 KB of game code from 11.1 KB
  of Z80 listing (ratio 1.9-3.4 against the listings, which include inline data; 4.8-6.2 against the
  instructions the sessions execute).  Example: snd_channel_tick, 229 bytes of Z80, 1335 bytes of 6502:
  every `rb(ch + OFF)` with `ch` a parameter on cc65's C stack costs ~20 bytes where the Z80 spends 3.
* The whole game in C (7 groups + f_principal.c, the pure C build: `mide_juego.py` with -DJUEGO_PURO),
  **65378 bytes** of cc65 code (logica_a 16418, logica_b 13429, personajes 9005,
  objetos_sonido 6695, estado_texto 6353, motor_iso 6092, camino 5542, principal 1844) against the 26961
  of the C64's code area.
* The whole game's Z80 functions are 22.3 KB of listing (11.4 KB of instructions executed in the 8
  sessions): in this style the C64 code would be ~60 KB, and about 30-34 KB are left for code on the
  C64 once the screen (9 KB) and the data (~20 KB in C64 format) are placed.
* Decision (H3): the C stays the reference (the GNU build, checked against the Z80); the C64 and Atari
  code is 6502 assembly (ca65, the cc65 suite; one source for both machines, only the platform layer
  differs), written function by function from the C and the Z80, mostly at ~1.2-1.5x the Z80 size, and
  checked in shadow like the C: a 6502 core in the host runs each function on the C64 memory layout and
  is compared with the C/Z80 result.  Cold code may stay in cc65 C if the space allows.  This needs
  first the C64 memory map with the data relocated (where each D64_ datum lives on the C64).

* `tools/mide_cc65.py C_DIR FILES` measures what cc65 would produce without touching
  the sources (gcc -E with fake libc headers and a shim, pycparser, automatic C89 rewrite, cl65 -t c64
  -O -Os -Cl, od65 sizes).  As the copy stands: chr 16583, ai 10672, spr 6898, iso 6743,
  obj 5899, parch 2414, snd 1848, hud 1793, txt 1122, util 856 bytes of CODE = 54.8 KB for 11 files;
  sys, vid, game still fail in the shim (designated initializers, non-constant array initializers);
  by their x86 sizes the whole game would be 63–65 KB of 6502 code.  cc65/x86-32 ratio 0.9–1.4.
* Per function (`MIDE_FUNCIONES=1 mide_cc65.py`): chr_project 1270 bytes, chr_cmd_write_path 821,
  chr_hbuf_fill_list 687, chr_path_find 661, …; an 8-line function such as chr_set_sprite_frame
  takes 219 bytes (the Z80 original about 40).  cc65 computes every `p[k]` with `jsr incaxk` and a
  pointer in ptr1, even for zero-page register variables: ~5x the Z80 size in this style.
* llvm-mos SDK v23.2.0 (`tools/terceros/llvm-mos`, sha256 4d6c9f18…ae9e61) compiles the C11 sources as
  they are, but its code is not smaller: -Oz 61.5 KB against cc65's 54.8 KB for the same 10 files
  (-Os 73.7 KB).  So the compiler is not the answer; the style is.  cc65 stays.
* How it fits (target): screen ~9 KB; data of the 64 KiB version ~23 KB (CPC graphics at half
  horizontal resolution in C64 multicolour, the rest as is); renderers in ca65 ~4 KB; game logic in
  C ≤ 27 KB (a compact rewrite in 6502-friendly C89: 8-bit arithmetic wherever the original is 8-bit,
  static locals, no x86 emulation artefacts); parchments as overlays loaded from disk (as the tape did).

* The full C rebuild's game code (13 files, without the platform layer) is 58 KB of x86-32 code
  with gcc -Os; cc65 6502 code is usually 1.5–2× that.  As it is, it does not fit.
* cc65 2.19 rejects it: C99 constructs (declarations in `for`, mixed declarations and code,
  `inline`, `_Noreturn`, `__has_include`, 64-bit integers) and a 64 KiB `ds[]` array.
* C64 budget: ~54 KB of RAM once BASIC and the KERNAL are banked out (minus zero page/stack, 8 KB
  bitmap and 1 KB screen RAM).  Data of the 64 KiB version ≈ 28 KB with the graphics converted to
  C64 multicolour (half horizontal resolution) → ~26 KB left for code, about what the CPC 64 KiB
  version's Z80 code takes.

## The game: method decided

The PC data space was reorganised by the PC port, so the full game's data cannot simply be looked up
in the CPC 64 KiB memory (39 of 548 data found by content, `mapa64.py`; the code-operand alignment of
`mapa_por_codigo.py` confirms pieces, e.g. Guillermo's graphics PC 1322h = CPC 64K A300h, but is
noisy).  So the game is rebuilt the way the PC one was, from the CPC 64 KiB binary itself:
1. the function map of the 64K Z80 code (entries from call tracing in the simulator, `--llamadas`;
   names from the PC functions through their CPC 6128 addresses, 246 of 444 annotated, and the
   6128 -> 64K code alignment of `difcodigo_total.py`);
2. call captures in the simulator (state at entry, at exit, interrupts in between), with interrupts
   delivered only at the program's wait points (as the PC's synchronous mode);
3. each function translated to C on the CPC memory model (ds = the CPC 64K address space), with the
   PC C function as the guide, and tested against its captures, bottom-up;
4. the whole program against the simulator, frame by frame;
5. the C64 layer (renderers in ca65, memory map, data relocation).
The simulator plays the 64K game interactively with key scripts (`--guion`: frame row:bit frames;
cursor up 0:0, right 0:1, down 0:2, left 1:0, space 5:7): Guillermo walks, the abbot's welcome
phrases scroll (`data/cpc64/explora1`).

### The hybrid host (src/juego/)

* `src/juego/hibrido`: the CPC 64K game run by a C Z80 core (`src/juego/z80/`, superzazu/z80, MIT, commit
  d64fe10a, ports widened to 16 bits) on a minimal CPC, in the synchronous mode, from the state the
  simulator dumped at the game's start (`data/cpc64/inicio_juego/ram.bin`, `estado.txt`, frame 471).
  Cross-checked: the same session gives the same RAM, frame by frame, as `cpc_carga.py` (SkoolKit):
  229 frames identical (FNV-1a 64 of the 64 KiB), 100x faster.
* Synchronous mode (`data/sincrono/puntos64.txt`): `espera 21D6 21DB` (the main loop's wait for
  the tick counter at 289Ch, speed value 42 from BF49h), `pausa 3EB8 3EC0` ("PULSA ESPACIO PARA
  EMPEZAR"), `pausa 20C7 20DD` (new game, space released); a `pausa` pass also counts as a frame.  A
  frame is a main-loop iteration (2179h).  The path search (41C9h) disables interrupts and sets the
  counter to FFh, so the next iteration does not wait (the PC does the same, chr.c:1650).
  `--limite N` reports a run with no frame for N instructions (the PCs and the stack): new wait
  points are found that way.
* The interrupt handler is 2899h (sys_tick, PC 281E): counter 289Ch saturating at FFh, then 0CD0h
  (sound) and 368Ah (txt_phrase_tick).  RST 08h -> 391Eh and RST 10h -> 38FCh are patched at 20EAh.
* The game reads the refresh register R at 518Ah to choose the mirror numeral (the PC replaced it by
  a RET: always 1); in C it will be a platform input (the core's R in the hybrid, a hardware random
  value on the C64).
* Translated functions are checked in shadow (`src/juego/funciones.c`, table `traducidas`): for every
  call the C function and the Z80 original run from the same state and are compared (all the RAM,
  SP, PC, the declared results).  `--sustituye` lets the C results go on.  First two functions
  (08E5 chr_room_distance_near, 0944 iso_grid_cell_ptr): 0 differences over 8 exploration sessions
  (up to 776 390 calls), after the first run caught a translation mistake.
* Exploration sessions: `tools/guion_azar.py SEED 472 4000` (seeded random keys:
  walk, turns, cursor down, space) -> `data/cpc64/exploracion/azar1..8.txt`; with `--llamadas`
  and `--cobertura` they give 275 called functions and 6195 executed instruction starts.
* Function map: `tools/funciones64.py` -> `data/cpc64/funciones64.tsv` (64K
  address, PC name when known: 115 of the called ones, PC address, CPC 6128 address, times, callers).

## Plan (next steps)

### The translation

The game's Z80 functions were translated to C group by group in separate working copies (since removed),
each checked in shadow; merged into `src/juego/` as they finished (`f_<grupo>.c`, `datos_<grupo>.h`, the
group's extra checks in `src/juego/pruebas_<grupo>/`, all run by `src/juego/pruebas_extra.sh`).  Merged:
motor_iso, camino, personajes, estado_texto, objetos_sonido, logica_a; `prueba.sh` 0 differences in the
8 sessions, and with `--sustituye` the per-frame RAM hashes (dead stack left out, `--hash-pila 0xAD`)
are identical to the pure Z80 run over 4001 frames of each session.  Host conventions settled for all the
groups: dead stack not compared; a function returns when an exit instruction leaves SP = entry SP + 2
unless it goes to the address a nested CALL/RST of the run pushed into that slot; SET_xx evaluate once;
platform calls plat_crtc/tinta/modo/teclado_fila/psg/di/ei.

### GNU front-end (H2): `src/juego/gnu/`

* `src/juego/gnu/abadia64ks` (SDL2, `make -C src/juego/gnu`): the game in a window in real time.  It includes
  hibrido.c (main renamed) and runs it in the new `--solo-c` mode: every translated function in C alone,
  no Z80 run and no check (the 8 sessions in this mode give per-frame hashes identical to the pure Z80
  run; the Z80 core still runs ~200 instructions a frame: the main loop and what logica_b has not
  merged).  The screen drawn from the memory as the CRTC (R1, R6, R9, R12/R13) and the gate array show
  it, mode 1/0/2, the CPC's 32 hardware colours; the PC keyboard mapped onto the CPC matrix
  (`teclas_vivas`); every AY write (`al_psg`) played by an AY synthesiser (1 MHz, tones, noise, MAME's
  levels, envelope) tick by tick; the pace: a frame is shown when its 300 Hz ticks (3328 us each) have
  elapsed.  Test options: `--guion KEYS --hasta FRAME --captura OUT.bmp --wav OUT.wav --rapido`.
* hibrido.c refactored for it (same results, checked: per-frame hashes unchanged, 0 differences):
  `corre_frame()` runs to the next frame point, hooks `en_frame`, `al_psg`, `teclas_vivas`, the video
  state (mode, palette, CRTC) read from estado.txt.
* From start to end (merged): `src/juego/pergamino.c` (the tape's parchment
  code 6000h-68A8h in C, the same bytes into the CPC screen memory, timed in Z80 T-states) and
  `src/juego/musica.c` (the music player with its T-states); the loading screen built up in the tape's byte
  order (FFFFh down; 4 s for the 16 KiB here); the game; at 100 % "PON EL CASSETTE EN MARCHA" (the host
  stops at 31CFh, `parada`), the ending parchment for ever.  `src/juego/gnu/prueba.sh`: both parchments
  against the CPC simulator, every frame (screen memory, inks, mode, CRTC), every AY write and 8 pictures
  each: identical (introduction 4510 frames, ending 4500 frames with ~15 passes while space is held).
  README: `src/juego/gnu/README.md`; pictures: `src/juego/gnu/recorrido.png`.  The game part is still the
  hybrid (Z80 core for the main loop) until the pure C build.

### The 6502 code and its check (H3/H4 pipeline)

* Conventions: `src/c64/CODIGO6502.md` (one 6502 routine per Z80 function, the Z80 registers as zero-page
  pairs `zbc zde zhl zix ziy`, A in A, the Z80's CF/ZF in the 6502's C/Z at the RTS); the memory map
  draft: `src/c64/MAPA.md` (ROMs off; bitmap $E000, screen RAM $C000, code and data $0800-$BFFF, data also
  at $C400-$CFFF and under the I/O).
* `src/c64/juego/`: the 6502 sources (ca65; `zp.inc`, `motor_iso.s` with the first three routines:
  util_add_bx_al, iso_floor_base, iso_orient_relative), `mapa64.tsv` (each datum: CPC address, length,
  C64 address; `mapa64.py` -> `mapa64.inc`), `resultados.tsv` (what each routine must leave as the
  Z80), `construye.sh` -> `juego.bin` (from $0800) + `juego.lbl`.
* `src/juego/m6502/`: cc65's sim65 6502 core with minimal headers (`m6502.c`: `m6502_llama`), and
  `sombra6502.c`: the check.  `hibrido --6502 ../c64/juego --solo-6502`: the Z80 runs the game and
  each of its calls of a function that has a 6502 routine is checked (the map's blocks copied into the
  6502 memory, the registers set, the routine run to its RTS, blocks and declared registers compared).
  The three pilot routines: 416 707 calls in session 1, 529 642 in session 5, 0 differences; a
  deliberate bug is caught (6 differences in 600 frames).

### Pure C (merged)

* The whole game in C with no Z80 core: every function calls the others in C (no llama_z80/stand-ins
  left; a real bug of the C drivers fixed on the way: ai_plan_route got chr_update's IX instead of the
  record), the rest of the Z80 translated in `src/juego/f_principal.c` (20BE game_main: start, new game,
  main loop; 0038; 31DF the CTRL+TAB tape menu with save/load, the tape blocks as platform calls) and
  the abbot's ceremony scripts 6000h-60F2h; platform calls plat_frame/espera/pausa/cinta_*/final/salir.
* `src/juego/puro/`: `puro_host.c` (the platform and synchronous mode without a Z80; game_main runs as a
  coroutine on the host), `puro.c` (the test program); the game files built with `-DJUEGO_PURO` (the
  hybrid's wrappers and checks under `#ifndef JUEGO_PURO`), C89-clean (`-Wdeclaration-after-statement`,
  gnu89 -pedantic).  Checks (`src/juego/puro/pruebas/`): `puro.sh` (pure C against the Z80, per-frame
  hashes, 8 sessions x 4001 frames: identical), `solo_c.sh`, `largo.sh` (16 scripts x 20000 frames),
  `dias.sh` (every day x hour, 49 x 6000 frames), `final.sh` (the 100 % ending), `frontal.sh` (the GNU
  front-end on the hybrid and on pure C: same pictures, AY writes, WAV), all identical; `prueba.sh` and
  `pruebas_extra.sh` (with `pruebas_principal/`) 0 differences.  References: `data/puro/`.
* `src/juego/gnu/abadia64ks-puro`: the GNU game in pure C (H2).
* `tools/prototipos64.py` skips the hybrid's functions; `src/juego/juego64.h`: 339 prototypes.

### The C64 memory map (H3, merged): done

* `src/c64/MAPA.md` (the map and the budget), `src/c64/NOTAS_MAPA.md`, `src/c64/NOTAS_GRAFICOS.md`; `src/c64/juego/bloques64.tsv`
  (204 blocks), `mapa64.tsv`/`mapa64.inc`, `punteros64.tsv` (642 pointer fields relocated), `datos64.s` (the data
  image), the graphics in C64 formats (`tools/c64_graficos.py`, `data/c64graf/`: 12970 CPC
  bytes -> 6779), the inventory (`tools/inventario64.py`).  Code area $0800-$7150: 26961 bytes;
  data 31040 bytes; the 6502 code is estimated at 23-28 KB: cuts are listed in MAPA.md (none applied).
* The 6502 check (`src/juego/m6502/sombra6502.c`) relocates the pointers both ways, converts the graphics,
  and now: traps (a stub of an untranslated function runs the Z80 original on the CPC form of the memory:
  17152 traps in session 1 with 0 differences, a deliberate bug caught), the platform mirrors
  (`src/c64/juego/plataforma.inc`, `plataforma_prueba.s`: AY, inks, CRTC, mode, IFF compared with the Z80's port
  effects; keyboard rows given), the screen (copied into the bitmap at entry, compared with `PANTALLA`), and
  the cycles per routine (`SOMBRA6502_CICLOS`).  Conventions: `src/c64/CODIGO6502.md`.

### The C64 platform layer (H4): done

* `src/c64/plataforma/`: `tinta.s` (plat_tinta: X = the C64 colour; a pen change fills the 768 game cells' screen RAM
  or colour RAM, ~4100 cycles), `teclado.s` (the CPC matrix from the C64 keyboard and joystick port 2:
  `TECLADO.md`; CTRL + <- opens the save menu, RUN/STOP = ESC, INST/DEL = pause, the digits pick the slot),
  `psg.s` (the AY on the SID: tone 1064277/P, noise as the SID noise waveform, volumes by the AY's log table;
  envelope registers unused by the game), `interrupcion.s` (plat_inicio: ROMs off, vectors, VIC bank 3 multicolour
  bitmap; the IRQ every 3279 cycles = the CPC's 300.48 Hz, 78 cycles of its own, JSR sys_tick), `disco.s`
  (save/load the game state as ABADIA64.BSn with the KERNAL's zero page and $0200-$03FF put aside and restored;
  plat_final loads and runs "FINAL", the ending parchment).  1797 bytes.  Tests in VICE on Xvfb :99
  (`src/c64/plataforma/pruebas/prueba.py`, ~6 min): all pass; the sound against the GNU synthesis (compara_audio).

### The 6502 groups as they finish

* camino (src/c64/juego_camino): 26 + 2 routines, 0 differences in the 8 sessions (master host), 2370 bytes.
* motor_iso (src/c64/juego_motor_iso): 23 of 24 routines, 0 differences (8 sessions, 16 long scripts, 4 variants),
  1835 bytes (budget 4300); a room drawn in ~339000 cycles (0.34 s); spr_update_char_sprite waits for personajes'
  chr_project / chr_show_frame (motor_iso_spr.s.pendiente).  Frees in the map: ISO_VM_STACK ($C800, 64 bytes)
  and the opcode table copy D64_ISO_BLOCK_OPCODE_TABLE ($E3A0, 56 bytes).
* logica_a (src/c64/juego_logica_a): 79 routines, 0 differences in the 8 sessions on the master host (after the map
  changes below and PANTALLA:doble on spr_draw_all / iso_draw_room_spiral), 6713 bytes (budget 5230: the sprite
  engine, the shared room/floor search); spr_draw_all ~41000 cycles a frame on average (max 243000), the spiral
  wipe 1.25 M cycles.  Map changes for it (merged): the sprite rectangle pointers 2978h + 14h k, 4471h, 4690h
  into the sprite buffer, the mirror buffer or the queue top; D64_ISO_MIRROR_BUF_GUILLERMO copied (the path
  queue grows into it); 2BE6h with the new flag `region` (7F80h-9FFFh shifted as a whole); D64_SPR_RECT_SIZE is
  an address.  Host: `PANTALLA:doble` (the Z80 run again on doubled C64 graphics: an exact check of tile and
  sprite composition).
* personajes (src/c64/juego_personajes): the 48 functions plus the Z80 entries the C keeps internal (chr_project
  2632, chr_show_frame 2589, chr_read_command 280D, ...), 0 differences in the 8 sessions on the master host;
  the group's own checks also in the 16 long scripts, an `npc` build (2226 left out so the NPC drivers' calls
  into the group are checked one by one) and 97 synthetic cases (`sinteticas.sh`: dark room, the mirror trap,
  stairs frames...): every Z80 instruction of the group run but the dead 254F-2552.  2705 bytes (budget 3560).
  Notes for the merge: the C64 animation tables at $CF99/$CFB9 have bits 7-6 set, so the monks' C0xxh tag is
  tested as hi = C0h exactly (an `.assert`); principal must skip the dead robes copy (2136 -> 2F57 on AE2Eh,
  which on the C64 is inside D64_CHR_FLOOR2_HEIGHTS); D64_CHR_PARAM_TARGETS (10 bytes) can leave the map.
* estado_texto (src/c64/juego_estado_texto): 0 differences in the 8 sessions on the master host (with its host rule
  `PANTALLA:fuente`, merged: the rule par plus the CPC byte -> nibble pairs of the C64 font's hand-made glyphs N
  and ';'); its own checks: the 6 long scripts, 4 variant builds hiding outer routines, unit tests for the
  routines the sessions never call (2FAD, 3087, 39E5; 3607 rebuilds the 2320 bytes of the C64 merge tables
  exactly, so the loader need not load them).  2276 bytes in estado_texto.s (budget 3300) + 297 in
  estado_texto_tabla.s (391E, 38FC, 3A5D, 3994, 3910, 316E, the slopes, 3558, 3778: nothing calls them in the
  6502 game; left out of the integration).  ai_script_eval meets logica_b's VM interface.
* logica_b (src/c64/juego_logica_b): the 40 functions, the scripts as bytecode for a VM over the Z80 script bytes
  (`logica_b_guiones.s`, generated by `guiones64.py` from the tape image), 0 differences in the 8 sessions on
  the master host and in the 16 long scripts (its own).  6170 bytes with estado_texto's ai_script_eval in place
  of its local evaluator (budget 4880; the group's real Z80 size is 5215 with the inline data).  Open: the
  drop orientation at 4E4Bh reads junk bytes (height << 8 | low byte of a CPC address); reproduced exactly
  with 2 x 36 bytes from the tape image (~115 bytes: a possible cut, still to decide).
* The integration (src/c64/juego_final): the six groups' sources in one build (`construye.sh`), the
  declarations merged by `resultados.sh` (`tools/resultados64.py`: each translated routine with
  its owner's lines, plus `resultados_integra.tsv`: the routines that called a trap in their group and now call
  the translated routine inherit its rule: spr_draw_or_darken -> PANTALLA:doble, hud_scroll_hour_name and
  txt_print_inline -> PANTALLA:fuente, sys_tick's screen compared), `comprueba.sh [--largos]`.  With
  objetos_sonido still as traps: 0 differences in the 8 sessions.  Code: 21907 bytes for the six groups.
* objetos_sonido (src/c64/juego_objetos_sonido): the 46 routines, 0 differences (8 sessions on the master host, its
  own variants and long scripts), 1967 bytes (budget 2700).  With it **the whole game is 6502, no traps**: the
  integrated build gives 0 differences in the 8 sessions and the 16 long scripts (0 traps).
* The platform (src/c64/plataforma): 1797 bytes.
* **The C64 build** (`C64=1 ./construye.sh` in src/c64/juego_final -> src/c64/juego_final/c64/juego.bin, .lbl, .map): every
  group, principal.s, the real platform, no stubs; code + read-only data + data + BSS end at $70E7 (the data start
  at $7151: 105 bytes free).  It runs in VICE (`src/c64/juego_final/vice/arranca.py`: the image written into the RAM
  through the binary monitor, the CPU at principal_inicio): the first room, the score bar, day I NONA.
* **The whole-game check** (hibrido `--juego6502 DIR`, src/juego/m6502/sombra6502.c; `comprueba.sh --juego`): the 6502
  game from principal_inicio (principal.s with -D PRUEBA: plat_frame / plat_espera / plat_pausa) in step with the
  Z80, the ticks given at the same wait passes by the host's rule, the keyboard and LD A,R in the mirrors, the
  memory (every block but `juego6502.tsv`'s, with reasons) and the platform mirrors compared at every frame point;
  the ending: the Z80 stopped at 31CFh, the 6502 at plat_final, compared there.  It found principal.s's wait pass
  at 3EB8 placed before the key test (fixed) and the C3h the start writes at 4AFCh, which is data (now written).
  `dias.sh [--rutinas]`: from the 49 start states of every day and hour (data/puro/estados) with long scripts,
  the whole game and the per-routine check.  It found three bugs no session from the start reached, all fixed:
  the hour name pointer one past its block after COMPLETAS (punteros64.py: `fin`), personajes_read_command's
  restart of a 2x2 command stream (`BEQ` after `LDY #9`: now `BCC`), and logica_b's script 5FDD falling past its
  switch table into the next function's entry (guiones64.py: a JR over that JSR).  After the fixes: 0 differences
  in the 8 sessions and the 16 long scripts (routine by routine and frame by frame), the 49 states and the ending;
  the long scripts needed one more block left out of the frame comparison, D64_PATH_QUEUE_TOP (where the CPC's
  sprite rectangles reach past the buffers, as spr_draw_all's own check leaves it: a few frames in largo108/110,
  healed by the path search's own writes, nothing else affected).  The disk rebuilt from this image passes
  src/c64/presentacion/pruebas/disco_prueba/prueba.py (the RAM at principal_inicio equals the image over 60719 bytes).  `PERFIL=1 ./construye.sh` and
  `SOMBRA6502_PERFIL=F` + `perfil64.py`: the whole game's cycles by routine.
* **Speed, measured** (the game's frames 1-400 from its start, no keys: the abbot comes to Guillermo and
  speaks): CPC 6128 (the Caprice32 with its control socket, `tools/cpc_velocidad.py`: the
  start as a .sna, a 3-byte frame-counting patch at 217Ah costing 0.02 %, the emulator's video-frame counter as
  the clock) 33.8 s, 11.8 frames a second; C64 PAL (VICE, CIA 2 as a cycle counter) 48.6 s, 8.2 frames a second:
  **the C64 takes 1.44 times as long**.  The C64's time by routine (`perfil64.py`, session azar1): the sprite engine
  ~28 % (spr_draw_all, spr_mirror_byte, the tile layers, the blit), the 300 Hz interrupt ~15 % in the host's count
  (more on the C64: a longer frame gets more ticks; ~850 cycles a tick with plat_irq and the SID — wrong: measured
  in VICE, an empty tick costs 96 cycles, "Speed, round 5"), the path search
  ~14 %, the script VM ~12 %.
* Speed work (src/c64/OPTIMIZACION6502.md; each area's diffs and notes in src/c64/optimizacion/<area>/):
  * the 300 Hz interrupt: sys_tick's idle tests inline, plat_irq without X/Y (56 cycles), the
    sound sequencer's idle paths, txt_phrase_tick's strip scroll unrolled, plat_psg's tone registers without
    PHP/SEI and a direct table; the check-only routines under `.ifdef PRUEBA`; psg_inicio clears all its state.
    Frames 1-400: 48.6 s -> 46.6 s (VICE); the build ends at $70B9; all checks 0 differences.
  * the keyboard: Q A O P as the cursors (src/c64/plataforma/TECLADO.md).
  * the sprite engine: the merge a destination column at a time with one table lookup per
    byte, tiles through patched absolute reads, the cell pointer once per cell, spr_draw_all's quick scan for a
    changed sprite, 4-byte clears and blits; the routines only the checks call under `.ifdef PRUEBA`.  The sprite
    file ~26 % faster in the sessions (whole game -2 % to -8 %); frames 1-400 (few sprites: no keys) 46.6 s ->
    46.2 s; the build ends at $70CD; all checks 0 differences.  The or_spr table ($BE00, 256 bytes) is no longer
    read (vid_init_stub still builds it): 256 bytes of data that could go.
  * the script VM: the instruction pointer as zhl + Y, opcodes by frequency, RST 08h tests
    compiled into short-circuit chains (261 of 265: the evaluator no longer runs in the sessions), the variable's
    page in the opcode, a liveness pass in guiones64.py, literal assignments inline; checked also by
    src/c64/optimizacion/guiones/pruebas/diferencial.sh (old and new builds from random states: 0 differences).
  * the path search: la_busca with a 24y table and an inline neighbour loop, the Z80 stack's
    writes under the queue done once at the end (an exact mode when the queue reaches the grid), the grid marks
    cleared by two fixed loops; src/c64/optimizacion/camino/pruebas/diferencial.sh: 0 differences (4 runs, 390 deep
    searches).
  * With everything (and the new characters' graphics): all checks 0 differences; the disk rebuilt and its VICE
    test passed; the build ends at $70AC (165 bytes free).  **Speed, no keys from the start** (CPC 6128 in
    Caprice32 / C64 PAL in VICE): frames 1-400 33.8 s / 35.0 s (1.04; it was 1.44), 1-1000 112.8 s / 133.2 s
    (1.18), 1-2000 294.2 s / 373.2 s (1.27).  Where the C64's time goes over frames 1-2000 (perfil64.py, by
    routine: the first version of its view gave unexported routines to the exported one before them and showed
    "t_frase 12.5 %", which was la_cuadro of the path search; the phrases cost nothing in this run): the path
    search's room search (la_busca and its parts la_cuadro, sala1/2, modo1, mete1, encola, la_sala) about 40 %,
    chr_hbuf_fill_list 14 %, chr_fill_height_buffer 2.6 %.
  * Round 2: the room search (la_cuadro does the Z80's 4077-40DD in one routine, the room
    expansion unrolled with the offsets written into the code at each search, the floor expansion's cell pointer
    inline: src/c64/optimizacion/planta/, its differential test extended to the floor searches: 7 runs equal) and the
    height buffer's fill (a cache of the last fill's visible records in $D4-$D9 and $C3E8-$C3FF, invalidated at
    2151: 98 % of the no-keys fills repeat the last list and window; src/c64/optimizacion/texto/, pruebas/hbuf.c against
    a C model of 346E/3786: 220000 calls the same).  Why the no-keys run is heavy: from frame 672 Severino tries,
    every 1.5 frames, to route to a room he cannot reach (a floor search, the grid built again, a grid search that
    fails), 1329 times; the Z80 does the same (now once a frame from VICE frame 674, 1 328 identical
    calls; the memo of round 5 replays them).  All checks 0 differences; the build ends at $7129.
    **Speed now (no keys from the start, CPC 6128 in Caprice32 / C64 PAL in VICE): frames 1-400 33.77 s / 34.13 s
    (1.01), 1-1000 112.78 s / 113.33 s (1.005), 1-2000 294.17 s / 296.87 s (1.009): the C64 runs at the CPC's
    speed.**

### The main loop in 6502 (src/c64/juego_principal/principal.s)

* `principal_inicio` (the C64's entry: plat_inicio, then game_main), `game_main` (20BE-2225: start-up, a new game,
  2151, the main loop with the frame wait), `game_check_end` (3E29-3EC6: the percentage texts; 100 % -> "PON EL
  CASSETTE EN MARCHA" and plat_final; else the wait for space and a new game), `ai_stop_hour_countdown` (3EE6),
  the CTRL+TAB menu (31DF: S saves / L loads the state buffer through plat_disco_guarda/carga, the checksum,
  game_state_gather/restore piece by piece over the C64 blocks).  994 bytes.  Left out on the C64 (documented
  in the file): the Z80 vectors, 2913h, the CRTC calls, the robes copy at a new game (dead), the lone RETs.
* With `-D PRUEBA` it calls plat_frame / plat_espera / plat_pausa: the host can then deliver the ticks as its
  synchronous mode does and compare the whole 6502 game with the Z80 frame by frame (to build at the merge).
* Size budget at this point: the 7 groups ~25.8 KB (before their size passes and the dropped table-only
  routines), the platform 1.8 KB, principal 1 KB, against 26961 bytes of code area: about 1.6 KB over.  Room
  besides the code area: 871 bytes in the bitmap's invisible pieces (up to 64 bytes each), $079D-$07FF (99
  bytes on the C64), plat_inicio + psg_inicio (210 bytes, run once).

### Hardware sprites for Guillermo and Adso: the SPRHW build: REJECTED

* Rejected after seeing it live on hal9000c: the black layer (sprites) and the body (bitmap)
  separate while walking (the VIC and the CPU are not synchronised: the sprite registers change when a rectangle
  is blitted, the bitmap over several raster frames) and the game lost speed (walking frames +105 000-190 000
  cycles).  The normal build is the game; the HW build stays as a record (`HW=1`), not shipped.  Next: the other
  option, the whole character as multicolour sprites (3 colours), studied against another C64 version
  (src/c64/SPRITES_HW.md).
* The aim: the C64 characters pixel for pixel as the PC EGA / CPC ones and, after the mock-ups, in hardware
  sprites.  The multicolour bitmap halves the horizontal resolution, so each
  character's black strokes go to hires hardware sprites (black, two 24 x 21 sprites per character) over its
  body drawn without black (rule `cuerpo`); Guillermo, Adso and their two mirror reflections take the 8 sprites,
  the monks keep the rule `trazos` in the bitmap.  Design, hooks, memory map, costs and the bugs met:
  `src/c64/SPRITES_HW.md`.  `HW=1 C64=1 ./construye.sh` -> `src/c64/juego_final/c64hw/`; disks `src/c64/disco/abadia64ks_hw.d64`
  and `abadia64ks_english_hw.d64` (`src/c64/ingles/pruebas/prueba_en.py --juego`).  The normal builds are byte for byte
  what they were before this work plus the size reductions below.  Measured in VICE: +1.4 % cycles a frame over 800
  frames of the start.  Found with the disk tests: the image's tile table must be the EOR form the stub rebuilds,
  and the sprite module's zero-page variables and slots must be zeroed by hw_inicio (from disk they hold the
  KERNAL's values; the image test wrote zeros).  Both HW disks pass their VICE tests without the ending (20
  checks each; the normal disks unchanged, 40 and 37 checks with the ending): `src/c64/SPRITES_HW.md`, "Disk tests".
* Code size (`src/c64/ANALISIS_TAMANO_6502.md`, the size analysis): items 2-6, 8, 12 applied
  to both builds, CODE 26 236 -> 25 601 bytes; the hybrid check 0 differences (8 sessions) and the whole 6502 game
  in step with the Z80 over 24 sessions 0 differences.
* What the game never uses (which positions are NEVER used, found by deterministic code and the result
  verified): `src/juego/hibrido --usados6502` marks every byte the 6502 reads, writes or
  executes; `src/c64/juego_final/usados64.py` reports it against the map, the segments and the labels
  (`src/c64/CODIGO6502.md`, "What the game never uses"; the report it writes).  Over the
  24 sessions: 44 386 addresses used, 21 150 never; statically dead data confirmed by a search for readers in the
  sources: 392 bytes (`tabla_or_spr` 256, `ISO_VM_STACK` 64, `D64_ISO_BLOCK_OPCODE_TABLE` 56, `D64_CHR_PARAM_TARGETS`
  10, `cola_obsequium` 4, `fila_blanca` 1, `D64_AI_UNUSED_3CAD` 1) plus the 21 zero-page Z80 operands (26 bytes)
  the SPRHW map already drops; code never executed 7 171 bytes is an upper bound (the scripts never reach the
  mirror room, the ceremonies, the ending).  Verified: the executed bytes all lie in code segments, the Z80's
  `--accesos` of the same runs agree byte for byte on 108 of 179 copied blocks and the rest are explained
  (operands the Z80 fetches as instructions, the rewritten path search and room builder), the 21 dropped operands
  are all in the never-read set.  Not applied to the normal builds (it would change the shipped disks).
* A remote-control bridge for VICE (a local tool, not in the repository): start a build or a disk, run frames,
  registers, RAM, watchpoints, screenshots.
* VIC-II sprites dropped altogether (measured first: a composed rectangle costs 30 700 cycles and path search is 46 % of all cycles, so
  sprites would not fix the crowded scenes) and the precise conversion tried to reach Darksoft's look, for the
  characters and all the background, very precisely:
  rule `contorno` (the stroke pen whole wherever it touches the outside, `trazos` inside) for the characters,
  faces, robes, door and objects; the tiles were tried with `trazos` per class (807 runs of the source lost
  against 1373) and put back on `detalle` at once: live, the rooms looked worse (the per-tile choices break the continuity of courses and floor patterns).  `src/c64/NOTAS_GRAFICOS.md`, the sheets in `muestra_graficos_c64/muestra7/`.  The
  host's screen rule of hud_draw_guillermo_objects is `par` now (the objects are no longer `sim`): hybrid check 0
  differences.  Not yet approved visually; watched live on hal9000 (vice/vivo.py on the Plasma session,
  DISPLAY :1).
* ALL the graphics put back as they were (with `contorno` Adso going right-down loses his eyes in some
  frames, the forced contour eats the highlights next to the silhouette).  State left:
  `c64_graficos.py` as before those rules (characters/faces/robes `trazos`, door/objects `sim`, tiles
  `detalle`); the normal image byte for byte the earlier one (2aba9beaee99), the English disk too
  (6fb981ae203a); the Spanish disk rebuilt from that image was b6fd69421faa, not the earlier cf66187ff3f3 (the
  English disk from the same scripts identical).  The rule `contorno`, the `tr` parameter, `c64_compara_baldosas.py`
  and the `--columnas contorno` of the comparator stay as tools, not applied.
* Open then: the Spanish disk's md5; sync hal9000c; the English C64 video re-recorded; the dead data's
  removal in the normal builds (the memory gained to be used: 635 bytes of code and 392 of data free, use to be
  decided); Darksoft's look needs redrawn frames, not a rule (src/c64/NOTAS_GRAFICOS.md).

### Next

1. Pure C (P): one header with every game function's prototype; every llama_z80 / salta_z80 /
   stand-in replaced by the C call; the start and the main loop (20BEh-2225h), the functions that do
   not return to their caller (chr_project 2632, 261E, 280D, 0ACA, 3E29, 3EE6...) restructured; a
   program with no Z80 core whose per-frame hashes equal the hybrid's Z80 run; then the SDL front-end
   for GNU/KDE (H2).
2. H3: the C64 memory map: every D64_ datum placed (data footprint measured with `hibrido --accesos`,
   `data/cpc64/accesos/`), graphics converted (tiles and sprites at half horizontal resolution), the
   data kept by the CPC in the hidden parts of its screen moved out; a 6502 core in the host.
3. H4: the 6502 code (ca65) function by function, checked in shadow against the C; the C64 platform
   (VIC-II multicolour bitmap, keyboard, SID for the AY sequencer with noise, CIA 300 Hz); the game
   loading the ending parchment; `abadia64ks.d64`.  H5: the Atari.

Fitting needs, measured so far: renderers (tiles, sprites, room builder interpreter) and the
heavy loops in ca65; the logic in C written for cc65 (globals/zero page instead of pointer
parameters, 8-bit arithmetic, table-driven code), measured function by function with
`mide_cc65.py`; parchments and the ending as overlays from disk; more cuts only if needed.


1. H1: decode the height-map, room-link and state differences; compare the graphics; review the
   code differences of `dif_total.txt`; BN1 confirmed (the ending) and the tape save/load found.
2. H2: a compact rewrite of the game core in C89 (cc65 subset), on C data structures instead of a
   byte image of the PC's data segment, with the 64 KiB version's data generated as C source;
   PC-only parts dropped.  Oracle: the CPC 64 KiB version in the Z80 simulator (same keys → same
   game state per main-loop iteration), plus the full rebuild for the parts both share.
3. H3: hot paths (tile and sprite drawing, maybe path search) in ca65 assembly per platform;
   measured memory map; overlays for the parchments (loaded apart, like the CPC tape).
4. H4: C64 platform layer, VICE tests on Xvfb :99, `.d64`.  H5: Atari, `.atr`.
