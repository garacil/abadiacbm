# abadia64ks — milestones

Started.  This file is the project's to-do list: read it first on every return to the work,
tick a milestone only when its check has been run, and add what is learnt to `ESTADO.md`.

## The rules

* `/home/german/proyectos/abadia` (the full PC rebuild) is a **read-only reference**: never write
  there, never run `make` or any tool that writes inside it.  Everything new lives here.
* abadia64ks is the **64 KiB version** of La Abadía del Crimen, the equivalent of the Amstrad CPC
  464/664 tape version (which removed rooms and decoration from the 6128 game), cut further
  if needed, so that it fits in 64 KiB machines.
* The target is **cc65**: the C sources must become a Commodore 64 game first, then Atari 8-bit.
* The end products are **disk images with the finished game**: a `.d64` for the Commodore 64, then
  another disk (`.atr`) for the Atari 8-bit.
* Loading order to imitate the CPC 64 KiB version: the **intro parchment loads on its own first**,
  then the loading screen together with the game; the **ending parchment is loaded at the end**
  (confirmed on the original cassette: three turbo blocks after the loader — first stage, game with
  the loading screen built up as it loads, ending loaded by the game at 100 %; see RECORTES.md).
* **The reference is the original cassette** (`original/archive.org/cdt/`), not the disk
  repack used at first (`data/cpc64/dsk_cngsoft/`).
* **Keep the original look faithfully**: the aesthetics and the design of
  everything (rooms, sprites, score bar, parchments, layout) as in the original, and **the colours of
  the CPC version** (its palettes, measured from the CPC 64 KiB game in the simulator) mapped to the
  nearest colours of each machine.  Not the CGA colours of the PC version.
* **The C64/Atari code is 6502 assembly with ca65** (the ca65 option, after the
  measurement: the game's C through cc65 is 65 KB of code, the C64 has 27 KB for it).  The C stays the
  reference and the GNU version; every 6502 routine is checked against the Z80 original.
* **A note on the board (`tiza console ...`) when the C64 version is finished**.
* **The reverse-engineering tools as before** (rea, Ghidra and its projects of the PC and CPC programs,
  DOSBox-X, when useful) and **everything the project needs installed**.
* The general rules of the projects apply: docs and code in English, the OS is called GNU, no GUI tests on
  the desktop (Xvfb :99), deterministic automation, files owned by german (chown after root writes),
  references only for cross-checking.

## Milestones

| # | Milestone | Done when | State |
|---|---|---|---|
| H0 | Project created next to the full one, full one untouched | `abadia64ks/` exists with its own tools; nothing written in `abadia/` | done |
| H1 | The CPC 64 KiB version measured | `RECORTES.md` lists, from a direct comparison of the unpacked CPC 64 KiB memory with the full game: rooms emptied, rooms simplified, height maps, room links, graphics (tiles) removed, start position, logic changes, how the parchments are loaded | in progress: loader simulated, game running in the Z80 simulator, rooms, heights, tiles, start, palette, code diff measured; `RECORTES.md` still to write |
| H2 | abadia64ks C sources: the CPC 64 KiB game in C | builds with gcc + SDL2 on GNU/KDE and plays from start to end; the 64 KiB version's own code and data (rebuilt from the original cassette's Z80 code, function by function, checked against it, instead of cutting the PC rebuild: same game, no PC-only parts); portable core separated from the platform layer; C89 | done: `src/juego/` (7 groups + f_principal.c), pure C build identical to the Z80 frame by frame in every check; `src/juego/gnu/abadia64ks-puro` plays it with the introduction, loading screen, game and ending (parchments identical to the CPC); not installed in the KDE menu (not wanted yet) |
| H3 | It fits in 64 KiB | a memory map for the C64 (and Atari) with measured sizes from cc65 (code, data, screen, buffers); data relocated so no 64 KiB `ds[]` image is needed; extra cuts decided and listed in `RECORTES.md` | done: `src/c64/MAPA.md` (code area $0800-$7150, 26961 bytes; data 31040 bytes placed, 642 pointers relocated, graphics converted); the 6502 code is hand-written ca65 (the C via cc65 would be ~60 KB), checked in shadow against the Z80 (`src/c64/CODIGO6502.md`) |
| H4 | Commodore 64 version | C64 platform layer (VIC-II bitmap, keyboard/joystick, SID sound, raster/CIA timer, disk loading of the parchments); built with `cl65 -t c64`; tested headless and deterministically in VICE on Xvfb :99; **`abadia64ks.d64` with the finished game** | in progress: the whole game in 6502 (src/c64/juego_final: 7 groups + principal.s + src/c64/plataforma), 0 differences against the Z80 routine by routine and frame by frame in the 8 sessions, the 16 long scripts and the 49 day/hour start states, the 100 % ending reached; it fits ($70E7 of $7150); `src/c64/disco/abadia64ks.d64` ("abadia", "juego", "final") loads as the tape did (pink, the picture in the CPC's byte order, then the game). Speed: rounds 4 and 5 put the C64 well ahead of the CPC (VICE, no keys, frames 1-2000: 122.5 s against the CPC's 294.2 s, C64/CPC 0.42; frames 1-400 29.6 s against 33.8; ESTADO.md "Speed, round 4" and "round 5"; it was 1.44x at first), Adso's frames (some lose the eyes in the conversion), then the main characters' conversion reviewed against Amstrad captures, the music with a more SID sound (the same notes and timing), its own C presentation and parchments (done: src/c64/presentacion, the abadia.c/manuscrito.c/io.c with the least changes, diffs in its NOTAS.md: the parchment first with the CPC's music, a key, the picture on the game's screen while the game loads; the ending the parchment with the tape's ending text and music; the credit on the introduction; `src/c64/presentacion/pruebas/disco_prueba/prueba.py` passes), the play reports (walking + turning turns the wrong way: the C64's SHIFT+CRSR keys; the library key: the monk never steps aside for Adso, even after the second day's meal), the report (done: the music lost 300 Hz ticks while monks walked and talked: the C64's DI spans and the phrase's character inside the interrupt; the choice: no footsteps while the music plays, which then ends at its end, and the footsteps at half; the percentage's third digit; the ending from drive 9; ESTADO.md "The music on the C64"), playing tests in VICE, its own approval |
| H5 | Atari 8-bit version | Atari platform layer (ANTIC/GTIA, POKEY, keyboard/joystick, disk loading); built with `cl65 -t atari`; tested in an emulator on Xvfb :99; **`abadia64ks.atr`** | pending |
| H6 | English (British) release for the Commodore 64, separate from the Spanish one | `src/c64/disco/abadia64ks_english.d64` built by `src/c64/ingles/construye.sh` (everything translated, a d64 disk with the same label and the suffix _english.d64, British English, the English text fitting where the Spanish fitted); the Spanish disk untouched | superseded: the separate English disk retired (removed with old/); English is now the tape's language option (H8) |
| H7 | The characters' HEADS as VIC-II hires sprites with a black mask, the bodies in the bitmap | After studying the other C64 conversion: only the head goes to the VIC-II, in hires with a black mask; the body does not: Guillermo's and Adso's heads (the face lines) drawn by a hires hardware sprite carrying the black strokes over the multicolour body, the body composed as now; the full-body hardware sprite route (src/c64/SPRITES_HW.md: mask and fill separate when walking, slower) is NOT it.  Brought forward the same evening (the heads in high definition, with a backup made before applying it): a backup made first; built as the HW variant (HW=1), the normal build untouched | moved to H10 (every head hires on the 128 KB machines); the C64 keeps the restored code without them (base) |
| H8 | The C64 tape release, both languages on one tape | `src/c64/cinta/abadia64ks.tap` (`tools/genera_cinta.sh`): the start menu (1 language, 2 footsteps, 3 the text's sound), the presentation and ending with both languages inside (Exomizer), the game Spanish plus the English texts' block when English is chosen, the ending loaded from the tape at 100 %; the base is the code with every graphic edit; certified against the CPC (host chain and the real binary in VICE) | in progress: done and checked in VICE: the menu, both languages, Exomizer, the game and the English texts from the tape, the sounds off, the ending from the tape in both languages, the ending deaf to keys, the menu's credits; **the same release on a C64 1541 disk** (both versions, tape and disk): `src/c64/disco64/abadia64ks.d64` (src/c64/disco64/NOTAS.md), checked in VICE in Spanish, English with every option off and the ending at 100 % from the disk; `tools/genera_todo.sh [--prueba]` builds (and tests) the tape and both disks; to do: save/load a game on tape (coded, untested), the tape build certified against the CPC, src/c64/cinta/NOTAS.md |
| H9 | The tape read by interrupt (CIA 1's FLAG into a small ring buffer) | the loader free of the tape's timing: faster waves again, and the game's stream compressed (the loader's lz64 matches decode while the tape runs; ~26 % less, ~50 s) | pending (after H8) |
| H10 | abadia128ks: the disk release for the 128 KB machines (C128, CBM-II/P500), one source tree | every head hires (all the monks too: ALL of them); the rooms of the 128 KB PC/CPC disk version; everything loaded at once per file and decrunched (presentation with all languages, game, ending: everything as on the tape, but on disk, file by file); several languages, the start menu, the PC's Ave Maria; assembler conditionals per machine (`-D C128`, `-D P500`); the H7 heads' work as the starting point | in progress: done: the game in C128 mode (`-D C128`: the MMU's $FF00, 4 KiB of common RAM, the room table in block 1); every head hires (src/c64/juego_final/cabezas128.s: Guillermo, Adso, every monk's face, the reflections; one raster window, or one a head when they do not fit a frame); 2 MHz in the border (CIA 2's NMIs); the boot disk `src/c64/disco128/abadia128ks.d64` (boot sector, the menu with the 4th option Ave Maria, the presentation and ending, the game in J and J2 crunched into block 1, saves and ending through the KERNAL); **the full game of the PC** (`-D COMPLETO`: the full game, with the PC version as the reference; data/completo/PLAN.md): its rooms, blocks, heights and room links, the 256 tiles (204 the 64ks's C64 graphics byte for byte, 25 new), the start at the entrance, and the logic differences the certification found; certified against the PC rebuild (src/c64/certifica/pc: 8 random sessions x 4000 frames + a walk: 0 differences); the 64 KiB map build certified against the CPC (8 x 3530 frames: 0 differences); **the P500** (`-D P500`, src/c64/discop500: its own platform for the 6509 and the CBM-II's I/O, the menu, the parchment and the loader in cc65's cbm510 target, the game's bank 0 crunched into bank 1 and decrunched there by the last stage, save and load and the ending through the KERNAL of bank 15; disks for the 8050 and the 2031/4040, checked in VICE in both languages, with a long run of the interrupt; src/c64/discop500/NOTAS.md); to do: the C128's save/load test, the 128ks's head edits in the editor (H12) |
| H11 | The project on GitHub, private | `garacil/abadiacbm` (private): the tree organised (tools/, src/, doc/, README) | pending |
| H12 | The graphics editor for both lines | `tools/c64_editor.py` choosing what to edit (characters, scenery, objects) and for which version: abadia64ks (multicolour heads, `src/c64/datos/editados64.txt`) or abadia128ks (hires heads over the bodies) | pending |
| H13 | A sound and deep clean-up | everything not needed moved to `old/` (in case it was needed later; old/ deleted), measured by what the builds and checks really read, and every build proved byte for byte the same afterwards | pending |

## Tools in this project

* `tools/terceros/cc65/` — cc65 built from <https://github.com/cc65/cc65> (commit `a6530f469`,
  `cc65 V2.19 - Git a6530f469`); binaries in `tools/terceros/cc65/bin/`.
* `data/.venv` — Python venv with SkoolKit 10.1 (Z80 simulator).
* `tools/dsk.py` — CPC disk images (standard/extended), AMSDOS directory and files.
* `tools/cpc_carga.py` — runs a CPC loader on the Z80 simulator with the firmware
  calls emulated and dumps the RAM (deterministic).
* `tools/z80sim.py` — SkoolKit's simulator without the Spectrum ROM write block.
* `tools/busca_recursos.py`, `compara_salas.py`, `difiere.py` — where the full game's
  resources are in another memory image; room-by-room comparison of the room tables; byte
  differences of aligned resources.
* `tools/difcodigo.py`, `difcodigo_total.py`, `codigo_comun.py` — Z80 code of two
  images compared instruction by instruction (z80dasm, 16-bit operands normalised).
* Installed for the ports: VICE (`vice-sdl2`: x64sc, c1541, petcat), atari800, cc1541, dir2atr,
  exomizer 2 (`tools/terceros/exomizer/exomizer2/src/`).
