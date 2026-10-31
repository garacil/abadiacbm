# abadia64ks: the 6502 code of the game (C64, later Atari) — conventions (draft)

The 6502 code is a hand translation of the game's Z80 functions, one 6502 routine per Z80 function,
with the C translation (`src/juego/f_*.c`) as the readable reference.  It is checked like the C: the
hybrid host runs it on a 6502 core (`src/juego/m6502/`, cc65's sim65 core) at every call the Z80 makes in
the exploration sessions, from the same state, and compares the result with the Z80's.  One source
for the C64 and the Atari: only the platform layer differs (`src/c64/plataforma/`, later `atari/`).

## Registers

The routines keep the Z80 function's interface, so a call is checked from the Z80's registers and the
6502 routines call each other as the Z80 functions do:

| Z80 | 6502 |
|---|---|
| A | the accumulator A (at entry and exit; free inside) |
| BC, DE, HL | zero-page pairs `zbc`, `zde`, `zhl` (low byte first: `zbc` = C, `zbc+1` = B) |
| IX, IY | zero-page pairs `zix`, `ziy` |
| BC', DE', HL', AF' | zero-page `zbc2`, `zde2`, `zhl2`, `za2`, `zf2` (EXX and EX AF,AF' become copies or swaps) |
| flags Z, C used by the caller | the 6502's Z and C at the RTS, with the Z80's meaning (C = 1 when the Z80's CF is 1; mind that CMP sets the 6502's carry the other way round) |
| flags S, P/V, H, N | only when a caller uses them (the C check's declared results say which) |
| SP-relative tricks (POP of the return address, return past inline data, the stack as a queue) | the same tricks with the 6502 stack (PLA/PLA, adjusted return address) or a software stack in memory, as the routine needs |

Calls: `CALL nn` → `JSR`; `RST 08h` / `RST 10h` (the script helpers with inline data) → `JSR` to
their 6502 routines, which read the inline bytes through the return address.  Self-modified operands
of the Z80 become variables (or self-modified 6502 operands where that is faster and the code is in
RAM, which it always is on the C64).

## Data

Every datum the Z80 code reaches by address has a name (`D64_*` in `src/juego/datos_*.h`) and a C64 address in the
memory map (`src/c64/MAPA.md`, `src/c64/NOTAS_MAPA.md`): `src/c64/juego/mapa64.inc` (generated) defines every `D64_` name
at its C64 address, the blocks, and `CODIGO_INICIO` / `CODIGO_FIN` (the code area).  The operands the Z80 code
rewrites are zero-page variables ($24-$9D).  Variables keep the CPC's values and units (widths in CPC bytes =
C64 nibbles, positions as x bytes / y lines, the Z80 opcodes the code switches between, tile and room numbers):
only addresses differ, and a pointer stored in data holds the C64 address (`src/c64/juego/punteros64.tsv`), a
code pointer the 6502 routine.  Graphics (tiles, characters, doors, objects, faces, robes, font) are in the C64
multicolour formats of `src/c64/NOTAS_GRAFICOS.md` (a CPC byte = a C64 nibble); the 6502 drawing routines work on
the converted data and write the C64 bitmap directly.  Data under the I/O ($D000-$DFFF: the tiles, faces, door,
day numerals, light pattern) is read and written with the I/O switched off.  Never draw or clear outside cells
4-35 of bitmap rows 0-23: the other cells hold data.

## Checking

For each call of a Z80 function that has a 6502 routine, the host (`src/juego/m6502/sombra6502.c`): starts from the
64 KiB image `src/c64/juego/juego.bin`, copies the blocks of the map from the CPC memory to the 6502's memory at
their C64 addresses (pointer fields relocated CPC -> C64, the graphics the game flips in place converted), sets
the zero-page registers and A from the Z80 registers, runs the routine until its RTS, runs the Z80 original,
and compares: every block in C64 form (the Z80's result relocated / converted the same way; the constant C64
data must not change) and the declared result registers (`src/c64/juego/resultados.tsv`).  In resultados.tsv,
after the routine's name: result registers (A B C D E H L IXH IXL IYH IYL BC DE HL IX IY CF ZF), `REG:target`
for a register pair that returns a pointer (compared relocated), `>REG:target` for one that brings a pointer
(relocated at the entry), `!BLOCK` to leave a block out of the comparison (targets as in punteros64.tsv).  The
6502's own stack and scratch zero page are not compared.  `src/c64/juego/construye.sh` rebuilds everything.

## Calls to functions not translated yet: traps

A routine may call (`JSR`, or `JMP` for a tail call) any function of the game by its C name; when no 6502
source exports that name, `construye.sh` (`stubs64.py`) makes a stub for it: the byte 02h (JAM, never
executed on a real 6502) and the function's Z80 entry.  In the host the 6502 core stops at a 02h and the
checker runs the Z80 original instead (`src/juego/m6502/sombra6502.c`, `trampa`): the blocks the 6502 changed go
back to the CPC form (pointer fields relocated C64 -> CPC), the registers from the zero page and A/C/Z, the
hardware state from the platform mirrors; the Z80 function runs on that CPC memory; what it changed comes back
to the C64 form (blocks, the screen into the bitmap, the mirrors, the registers) and the stub returns as an
RTS.  So each routine can be checked before its callees exist.  A helper that reads the bytes after its call (the
script helpers ai_script_test / ai_script_assign, hud_say...) is marked `INLINE` on its stub's line in
`resultados.tsv`: the host copies the 112 bytes after the JSR to CPC 0080h, runs the Z80 helper with 0080h as
its return address and resumes the 6502 past the bytes it consumed.  A stub whose register pairs carry pointers
declares them in `resultados.tsv` like a routine (`>REG:target` relocated C64 -> CPC at the trap's entry,
`REG:target` CPC -> C64 at its exit).  The final build allows no stub (`FINAL=1 construye.sh` fails).

## The platform calls

The game's hardware accesses are `JSR` to the platform routines, with this interface (the same on the C64,
`src/c64/plataforma/`, and in the checked build, `src/c64/juego/plataforma_prueba.s`):

| Call | In | Out | Clobbers |
|---|---|---|---|
| `plat_tinta` | A = pen 0-16 (16 = border), X = the C64 colour (the game's palette tables are converted in the data, src/c64/datos/paleta.tsv) | | Y |
| `plat_psg` | A = AY register 0-15, X = value | | Y |
| `plat_teclado_fila` | A = keyboard matrix row 0-9 | A = the row, active low | Y |
| `plat_crtc` | A = CRTC register 0-15, X = value | | Y |
| `plat_modo` | A = screen mode | | A |
| `plat_di`, `plat_ei` | the Z80's DI / EI | | nothing |
| `plat_aleatorio` | | A = a random byte (the Z80's LD A,R at 518Ah) | flags |
| `plat_inicio` | (C64 only: the game's entry calls it first, `LDX #$FF / TXS / JSR plat_inicio`) | the interrupts off | A, X, Y |
| `plat_disco_guarda` | zhl = the saved game's first byte, zde = its length (the tape menu's block: D64_STATE_BUFFER, 1500); interrupts off | C = 1: an error | A, X, Y |
| `plat_disco_carga` | zhl = where, zde = the length; interrupts off | C = 0 loaded with that length, 1 not (no file, an error) | A, X, Y |
| `plat_final` | (the ending: 31CFh's tape load of the ending and CALL 6000h) | never returns | |

On the C64 (`src/c64/plataforma/README.md`): every call but `plat_di` / `plat_ei` needs the I/O visible ($01 = $35);
the 300 Hz interrupt is `plat_irq` (CIA 1 timer A every 3279 cycles: the CPC's 300.48 Hz), which keeps A and $01
(X and Y are sys_tick's to keep), sets $01 = $35 and CLD, acknowledges the CIA and calls the game's `sys_tick` (56
cycles of its own); the save slot is `plat_ranura` (the last digit key pressed: the file `ABADIA64.BSn`) and the
drive `plat_unidad` (8); the disk calls switch the KERNAL in and put its zero page and page 2-3 variables aside
around it (in $0100-$01AE).

In the checked build each keeps a mirror of the CPC hardware state (`plataforma.inc`, $07C0-$07FC): the host
fills the mirrors from the Z80 machine before a call (keyboard rows included) and compares them after it
with the Z80's port effects (AY registers, inks as C64 colours through src/c64/datos/paleta.tsv, CRTC, mode,
interrupt flag).

The alternate register set (BC' DE' HL' A' F') is loaded into $0C-$13 from the Z80 at every call; results
`A2`, `BC2`, `DE2`, `HL2` in resultados.tsv compare them.

## Zero page

`zp.inc`: $02-$0B the register pairs, $0C-$13 the alternate set, $14-$1B scratch `zt0`.., $1C-$23 pointers
`zp0`..: all of them may be changed by any call (save what you need).  $24-$9D: the operands the Z80 code
rewrites (`mapa64.inc`).  $9E-$FD: 12 bytes per group for its own hot variables, so that groups never clash:
camino $9E-$A9, objetos_sonido $AA-$B5, motor_iso $B6-$C1, personajes $C2-$CD, estado_texto $CE-$D9, logica_a
$DA-$E5, logica_b $E6-$F1, principal $F2-$FD.  Other variables of a group go into its own BSS (inside the code
area: they count against the code budget).  The SPRHW build (src/c64/SPRITES_HW.md) drops 21 of the operands its code
never reads and gives the bytes freed ($86-$9D) and the whole free runs of the windows ($C5-$CC, $F2-$F9: found
by `mapa64.py zp_fijos` from the `name = $xx` symbols of the sources) to the sprite code's own variables
(`hw_datos_a/b/c`, run-time only); `hw_cov` is $FE-$FF.  The holes inside a window belong to its group (two are
used unnamed by chr_hbuf_fill_room); a game variable with an initial value cannot live above $9D, which the disk's
loader does not load.

## Size and speed

The code area is $0800-$7150 (26961 bytes) for all the game's 6502 code, the platform calls and their own
variables; the Z80 functions' listings are 22.3 KB with their inline data.  Budget per group: about 1.2 times
the bytes of its Z80 listing (camino 2285 -> 2740, objetos_sonido 2246 -> 2700, motor_iso 3579 -> 4300,
personajes 2967 -> 3560, estado_texto 2755 -> 3300, logica_a 4357 -> 5230, logica_b 4066 -> 4880, principal
-> 700): compact code first (shared helpers, tables, loops), speed where it matters (the tile and sprite
drawing, the path search, the script interpreter).  `SOMBRA6502_CICLOS=file hibrido ... --6502 ...` writes the
6502 cycles per routine (traps not counted); the C64 runs at 0.985 MHz and the game's frame is 42 ticks of
300 Hz (140 ms, about 138 000 cycles) on the CPC.

### Cycles by module per frame (`SOMBRA6502_CATEGORIAS`)

`src/juego/hibrido --juego6502 DIR --ciclos-frame F` with `SOMBRA6502_CATEGORIAS=file` (the file from
`src/c64/juego_final/categorias64.py`: one category per source module of CODE, plus `hit` lines counting how often a
routine runs) adds to every frame line the cycles spent in each module and the hit counts; `ciclos_categorias.py`
groups the frames by the rectangles composed (hits of spr_blit_to_screen).  Over the 24 sessions (352 024 frames,
no mass scene: at most 5-6 rectangles a frame): path search 46 % of all cycles (logica_a_cam 32.8 + camino 13.6),
characters 12.4, sprite composition 11.8, height buffer / text 8.8, AI VM 8.7; a composed rectangle costs about
30 700 cycles (least squares); mean frame 131 000 cycles with 0-1 rectangles, 170 000 with 2, 187 000 with 3-4.
So hardware sprites for Guillermo and Adso can save at most their rectangles' composition (about 30 000 cycles
each, less the occlusion mask), not the monks' drawing nor the path search that dominates crowded scenes.

## Comparing the screen

`PANTALLA` in a routine's line of `resultados.tsv` compares the bitmap it leaves with the Z80's CPC screen
converted byte by byte (cells 4-35 of rows 0-23; what neither touched is skipped), by the rule of the graphics
the routine draws (src/c64/NOTAS_GRAFICOS.md): `PANTALLA` or `PANTALLA:sim` (sprites, objects), `PANTALLA:der` (the
font), `PANTALLA:izq` (the score bar), `PANTALLA:par` (any rule: each C64 pixel must be the pen of one of the
two CPC pixels it stands for; for the tiles' `detalle` rule, which depends on the neighbouring pixels, and for
tiles and sprites merged).  `PANTALLA:detalle` is the same as `PANTALLA:par`.

## Routines that read the bytes after their call

A routine (not a stub) marked `INLINE` in `resultados.tsv` (hud_obsequium_sub, hud_say, the script helpers...)
is checked with the 112 bytes found after the Z80's call copied to $0100-$016F of the 6502 memory and $00FF
pushed as its return address; it must return (SP back) with PC in $0100-$016F, and the bytes it consumed are
compared with the Z80's.  Inline data that holds Z80 addresses (the jump tables of 3A5D) cannot be checked so.

## Routines that walk Z80 bytes through HL

`>HL:INLINE` copies the 112 bytes at the Z80's entry HL (script expressions in the Z80 code) to $0100-$016F
and enters the routine with zhl = $0100; `HL:INLINE` compares how far the routine moved zhl with how far the
Z80 moved HL.  An `INLINE` routine that drops its return address and jumps (3A5D: to a word of its table)
also stops when SP is back with PC equal to the Z80's exit PC.

## Routines that run in the 300 Hz interrupt

On the C64 the interrupt (CIA 1 timer A, 300 Hz) calls `sys_tick` (2899h), which makes the tests of `snd_interrupt`
(0CD0h: a channel playing) and `txt_phrase_tick` (368Ah: the 2Dh-th tick) inline and calls their work only when
there is some (`s_interrupcion`, `t_frase`; the Z80 entries stay in the checked build for the checks).  The
platform's handler keeps A and $01 only, the RTI the flags: sys_tick and the routines it calls keep X and Y (they
save them only on the paths that use them), and on the C64 they make no DI / EI but one: the I flag is set from
the interrupt's entry to the RTI, except while `t_frase` draws a phrase's character, after its beep starts: there a
CLI, as the Z80's EI there (snd_start's), because that drawing takes up to ~9600 cycles, nearly three ticks, and
the music lost them; a tick that falls due then comes nested, once (the counter t_frase cleared first keeps it from
coming again).  The checked build's sys_tick ends with the EI the host's IFF mirror needs, and the scroller's beep
keeps snd_start's DI / EI there.  The main code's DI spans are the C64's too only where they guard what the
interrupt reads (the sound's starts, hud_say's phrase): chr_cmd_write_path's (the Z80's SP walks a queue) and
hud_say_now's are the checked build's only (`.ifdef PRUEBA`), they cost up to five ticks (
src/c64/juego_final/vice/pasos.py checks no tick is lost).  Everything those routines
and their callees touch in the zero page must be kept as the Z80 keeps its registers there (the pairs it
PUSHes and POPs), and they must not use the shared scratch `zt0`-`zt7` / `zp0`-`zp3` (the code they interrupt
may be using it) unless they save and restore it: use the group's own zero page for their working values.  The
host's check cannot see this (scratch is not compared): it is each group's responsibility.

Since round 5 (`-D JUEGO` in the C64 build): `plat_irq` (src/c64/plataforma/interrupcion.s) does sys_tick's
work inline (the tick count, the sound's test, the scroller's count) and the sound's test is a self-modified opcode,
`plat_irq_sonido`: `BIT s_interrupcion` while no channel plays, `JSR s_interrupcion` while one does; objetos_sonido.s
writes it (C64 build only) where a channel's state gets or loses bit 0 (s_pon, a sequence's end, snd_silence_all):
any new code that sets or clears bit 0 of a channel's state must write that opcode too.  The checked build keeps
sys_tick as before.  s_interrupcion keeps the interrupted X and Y in $C5/$C6 (no other code uses them).  Measured in
VICE: an empty tick 69 cycles (96 before).

## What the game never uses (`usados64.py`)

`src/juego/hibrido ... --juego6502 ../c64/juego_final --usados6502 F` marks every address the 6502 reads, writes or
executes over a run (m6502/memory.h: the core's accessors; the host's own pokes are not counted) and writes one
line per address used.  `src/c64/juego_final/usados64.py USADOS... [--accesos F...]` joins the runs and reports, against
the checked build's juego.map / juego.lbl / mapa64.tsv: the bytes never used per segment, the code never executed
by routine (the operand bytes of an executed opcode counted from the image's instruction lengths), the data
blocks never read / written / touched, the never-touched ranges, and (with the Z80's `--accesos` of the same runs)
the copied blocks whose byte sets differ between the Z80 and the 6502.  The whole set is an UPPER bound of what is
unused: an address none of the runs touched.  The 24 sessions (azar1-8 to 4472, largo101-116 to
20472) never enter the mirror room, the ceremonies, the ending or the save menu, so
their never-executed code (7171 bytes of CODE) is mostly unreached, not dead; the data they never read was
crossed with a search for reading instructions in the sources: statically dead are `tabla_or_spr` (256, written by
vid_init_stub and read by nothing: the sprite merge uses the AND table and EOR), `ISO_VM_STACK` (64: the 6502 VM
uses the hardware stack), `D64_ISO_BLOCK_OPCODE_TABLE` (56 Z80 handler pointers), `D64_CHR_PARAM_TARGETS` (10),
`cola_obsequium` (4), `fila_blanca` (1), `D64_AI_UNUSED_3CAD` (1) and the 21 zero-page Z80 operands of
`mapa64.py SIN_ZP_HW` (26 bytes; the SPRHW map already drops them and the OR table).  Three mirror-room operands
(`D64_ISO_MIRROR_OLD_SIZE_OP`, `_NEW_POS_OP`, `_NEW_SIZE_OP`, 6 bytes) have no reading instruction either but the
room was never reached: confirm by reading before dropping them.

