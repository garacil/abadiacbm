# abadia64ks: making the C64's 6502 game faster — the method, area by area

The whole game is 6502 (src/c64/juego_final), checked against the Z80 routine by routine and frame by frame.  It is
correct, but slower than the CPC: the game's frames 1-400 from its start with no keys take 33.8 s on a CPC 6128
(Caprice32) and 48.6 s on a PAL C64 (VICE): the C64 takes 1.44 times as long (ESTADO.md, "Speed, measured").
Each area is worked on separately: its routines made faster without changing what they do, within the
code space left, and both proved.

**Round 5 (ESTADO.md "Speed, round 5"): the route-search memo, Adso's proportional clear, the
interrupt / keyboard / sound.**  VICE, no keys, frames 1-400 / 1-1000 / 1-2000: **29.6 / 64.3 / 122.5 s** against the
CPC's 33.8 / 112.8 / 294.2 s (C64/CPC 0.88 / 0.57 / 0.42).  The code area has 3 bytes left; more needs the 392 dead
data bytes (but not D64_AI_UNUSED_3CAD: it is written by Jorge's book scene).

**Round 4 (ESTADO.md "Speed, round 4"): the C64 is AHEAD of the CPC.**  VICE, no keys from the start, frames
1-400 / 1-1000 / 1-2000: CPC 33.8 / 112.8 / 294.2 s, C64 before 34.3 / 112.8 / 294.7 s, after **31.2 / 99.1 / 255.7 s**
(C64/CPC 0.92 / 0.88 / 0.87).  The figures of round 2 below (373.2 s) are and were superseded by round 3
(296.87 s) before this round.  The build ends at $712D: 35 bytes free below $7151 (the 392 statically dead data bytes of
src/c64/ANALISIS_TAMANO_6502.md are still there).  The instruments of this round (the static cycle analyzer over ca65
listings with the sim65 core's own tables, the sim65 harnesses per area, the routine placement tool) live in a
scratch directory, not in the project.

**Round 2 (after the first round's merge: src/c64/optimizacion/{interrupcion,sprites,guiones,camino}):**
no keys from the start, CPC 6128 / C64: frames 1-400 33.8 s / 35.0 s, frames 1-2000 294.2 s / 373.2 s (1.27).
Measure frames 1-2000 too: `python3 -I vice/arranca.py OUTDIR 2000` (ciclos.tsv) and, in the host, the profile
of `--guion` a file with no keys (`# no keys`) to `--hasta 2472`.  Where the C64's time goes over those frames:
the path search's room search (la_busca and its parts la_cuadro, sala1/2, modo1, mete1, encola, la_sala) about
40 %, chr_hbuf_fill_list 14 % (perfil64.py by routine; its first version showed "chr_path_floor_search 30 %,
t_frase 12.5 %": unexported routines counted under the exported one before them, and t_frase costs nothing).  The code area has 165 bytes left ($70AC of $7150).

## What an area's work starts from

* ESTADO.md (the integration, the whole-game check, the speed measurement), src/c64/CODIGO6502.md (conventions,
  zero page per group, the interrupt rule), src/c64/MAPA.md, the area's group NOTAS.md (src/c64/juego_<group>/NOTAS.md).
* The sources in src/c64/juego_final: the area's files; the C reference src/juego/f_<group>.c.

## The area's workspace

* A copy of src/c64/juego_final at the same depth: `src/c64/v_opt_<area>` (`*.s *.tsv *.py *.inc *.cfg *.sh` and
  the `vice/` directory).  src/c64/juego_final, the other workspaces, src/juego/ (the host) and the map files are not
  edited from an area's work: a change needed there is made on its own and noted.  src/c64/juego_final's scripts are
  not run from it (other builds use that directory).
* When an area includes src/c64/plataforma files, the changed ones are copied into the workspace and the copy of
  construye.sh's C64 build points at them; src/c64/plataforma is never edited in place.
* The workspace is deleted at the end (once its notes are written); `chown -R german:german /home/german/proyectos/abadia64ks`.

## Measure

* The host's whole-game profile, exact 6502 cycles by routine (the platform calls are the check build's
  mirrors, not the C64's): `PERFIL=1 ./construye.sh` in the workspace, then from src/juego/:
  `SOMBRA6502_PERFIL=OUT.tsv ./hibrido ../../data/cpc64/inicio_juego/ram.bin ../../data/cpc64/inicio_juego/estado.txt
  ../../data/sincrono/puntos64.txt --guion ../../data/cpc64/exploracion/azarN.txt --hasta 4472 --limite 50000000
  --juego6502 ../c64/v_opt_<area>` and `python3 -I ../c64/v_opt_<area>/perfil64.py OUT.tsv 4001 40`.  At least
  sessions 1, 5, 8; the area's routines' cycles per frame noted before and after.
* The real C64: `C64=1 ./construye.sh`, then `python3 -I vice/arranca.py OUTDIR 1 400` (VICE on Xvfb :99; writes
  OUTDIR/ciclos.tsv: the cycles of each game frame): the time of frames 1-400 noted before and after (48.6 s
  then).

## Proof that it is the same game

All must give 0 differences, in the workspace:
`./comprueba.sh` (8 sessions, routine by routine), `./comprueba.sh --largos`, `./comprueba.sh --juego` (the whole
game, frame by frame), `./comprueba.sh --juego --largos`, `./dias.sh --rutinas` and `./dias.sh` (the 49 start
states of every day and hour and the 100 % ending).  If a routine the sessions never reach changes, a check
that reaches it is added (a synthetic case as src/c64/juego_personajes/sinteticas.sh does, or a unit test on juego.bin with
sim65's core as src/c64/juego_estado_texto/pruebas/ does).

## Rules

* Same results: every register, flag and byte the Z80 leaves (resultados.tsv says what is compared; the whole-game
  check compares every block at every frame).  Interfaces between groups stay as they are unless every caller is
  in the area.
* Code space: the C64 build's code, read-only data, data and BSS must end below $7151 (now $70E7).  An area may
  grow by at most its share; bytes saved elsewhere in the same area pay for more.  Size checks:
  `C64=1 ./construye.sh` and `grep -E '^(CODE|RODATA|DATA|BSS) ' src/c64/juego.map`.
* Tables for speed (a 256-byte lookup, unrolled loops) only if they fit; a table in the bitmap's free bytes needs a
  map change, noted with its size and alignment.
* The interrupt rule (CODIGO6502.md): routines run in the interrupt keep the zero page and the shared scratch.
* Comments in English, deterministic tools only, the 6502 code in ca65 as the rest.

## The area's notes

The cycles per frame of its routines before and after (sessions 1, 5, 8), the C64's frames 1-400 time before
and after (VICE), the bytes before and after, the checks' results, and the changes to apply to src/c64/juego_final as
diff files in src/c64/optimizacion/<area>/ (unified diffs against src/c64/juego_final's files, plus any new file), with a
short NOTAS.md there explaining each change.
