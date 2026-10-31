# abadia64ks — rules of the translation of the CPC 64 KiB game to C

The game of abadia64ks is the CPC 64 KiB version of La Abadía del Crimen (Amstrad tape), rebuilt in
C function by function from its Z80 code, so that it can later be built with cc65 for the Commodore 64
and the Atari 8-bit.  The reference is the CPC 64K binary; the full rebuild of the PC version
(`/home/german/proyectos/abadia`, read-only: never write there) documents the same game logic and is
the guide for names and meaning.

## 1. The data model

* `ds[]` (= `ram[]`, `juego.h`) is the CPC's 64 KiB of RAM; every address is the CPC 64K version's.
  Read and written with `rb/rw/wb/ww`.  The addresses a group uses are named in its header
  `datos_<group>.h` as `#define D64_<NAME> 0xXXXXu  /* what it is; PC name if the meaning matches */`;
  with the PC rebuild's names (`/home/german/Proyectos/abadia/c/include/direcciones.h`) when the datum is the same thing.
* No other global state: what the Z80 keeps in memory stays in `ds[]` (self-modified operands
  included: they are data at their code address, named too).
* **The screen.**  The CPC screen is C000h-FFFFh (mode 1, 64 bytes a line as the game sets the CRTC).
  Every write the game makes to it must use `wscr(addr, v)` and every read `rscr(addr)` (in the hybrid
  they are `wb`/`rb`; on the C64 they convert the CPC byte to the multicolour bitmap), never
  `wb`/`rb` on a screen address.  Hardware ports (gate array inks and mode, CRTC, PSG sound and
  keyboard) are platform calls declared in `juego.h` (`plat_tinta`, `plat_psg`, `plat_teclado_fila`...;
  each one added when needed and implemented in the group's copy of `hibrido.c` exactly as the port code does).

## 2. A translated function

* Name: the PC rebuild's name of the same function (from `data/cpc64/funciones64.tsv`, the listing
  header, or found while translating); `f_XXXX` functions get a real name once what they do is known.
* Comment before it: `/* XXXX name (PC 1000:YYYY): what it does.  In: ...  Out: ... */` with the 64K
  address first.  Comments in English.
* Parameters and results: what the Z80 passes in registers and flags becomes C parameters and results
  (`uint8_t`, `uint16_t`, `bool`, pointers to results).  Memory effects stay in `ds[]`.
* C style (cc65 accepts only this): C89 declarations at the start of a block, no declarations inside
  `for (...)`, no compound literals, no designated initializers, no `inline` in .c files, no VLAs,
  no 64-bit types; `uint8_t` wherever the Z80 works on 8 bits; no recursion unless the Z80 recurses.
* Calls: a function of the same group already translated is called in C.  A function not translated (any
  group) is called through the core: set `cpu.*` registers, `llama_z80(0xADDR);  /* name */`, read
  `cpu.*` (development only; they will be replaced by C calls when everything is translated).
  The RST 08h / 10h helpers are 391Eh / 38FCh.
* R register: the read at 518Ah (mirror numeral) is `plat_aleatorio()` (to be added by the group that
  owns it), which returns `cpu.r` in the hybrid host.

## 3. The wrapper and the check (hybrid host)

For every function, in the same file: a wrapper `static void w_XXXX(void)` that reads the registers
the function takes (`HL`, `DE`, `BC`, `cpu.a`, `cpu.ix`, `cpu.cf`...), calls the C function, puts back
every register and flag the Z80 function leaves that a caller can use (`SET_HL`, `cpu.a = `,
`cpu.zf = `...) and ends with `z80_ret();`, and a check `static int r_XXXX(const z80 *cz, const
z80 *zz, char *msg, size_t n)` comparing those results (see `funciones.c`).  Then
`{ 0xXXXX, "name", w_XXXX, r_XXXX }` goes into the group's table `const traducida_t traducidas_<group>[]`
(ended by `{ 0, NULL, NULL, NULL }`) and the table into the group's copy of `grupos.c`.

The wrappers, the checks, the table and every helper only they use stay under `#ifndef JUEGO_PURO`
(`src/juego/puro/pruebas/guarda_hibrido.py` puts the guards): the game code never touches `cpu`,
the registers or llama_z80.  `src/juego/puro` builds the game files with `-DJUEGO_PURO` and no Z80 core (the
pure C program, `puro/puro.c`), so a leftover reference to the hybrid does not compile there.

## 4. Checking

`src/juego/prueba.sh` builds `hibrido` and runs the 8 exploration sessions (8 x 4000 frames); every call
of every translated function runs both ways from the same state and must give the same RAM, SP, PC and
declared results ("0 differences").  `--solo name` checks one function; `--sesiones "1 2"` some
sessions.  A function the sessions never call cannot be checked: it is translated anyway and listed as
not exercised.  A function that does not return to its caller (drops its return address, jumps into
the main loop, moves SP) cannot be checked this way: it stays in Z80 for the moment and is described in the group's notes.

The whole game in C: `src/juego/puro` (`make -C puro`) is the game with no Z80 core; its per-frame hashes
must equal the hybrid's pure Z80 run (`hibrido --solo nada --hash-pila 0xAD`), frame by frame
(`src/juego/puro/pruebas/puro.sh`: the 8 sessions; `largo.sh`, `dias.sh`: long scripts and every day
and hour of the game).

## 5. Tools

* `data/cpc64/listado/XXXX_name.asm`: the Z80 listing of each function (`*` = executed);
  `data/cpc64/listado/indice.tsv`; `data/cpc64/juego/ram.bin` (the 64K image at the game's
  start); `z80dasm -a -g 0xXXXX file` for any range.
* The PC rebuild: `/home/german/Proyectos/abadia/c/src/*.c`, `/home/german/Proyectos/abadia/c/include/direcciones.h`,
  `/home/german/proyectos/abadia/trabajo/re/notas/*.md` (the analysis), and the Ghidra projects
  **ghidra-abadia** (the PC program) and **ghidra-abadia64ks** (the Z80 64K program).
* Never write in `/home/german/proyectos/abadia`.  Files written as root: `chown -R german:german`.
