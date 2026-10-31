# From the Z80 to the 6502

[Home](Home.md) · previous: [The abbey as a game](The-abbey.md) · next: [Memory map](Memory-map.md)

The Commodore game is not a re-creation: it is the Amstrad CPC 64 KiB program, translated function by function from
Z80 to 6502, with every routine checked against the original.  This page explains how that translation is organised,
so that any routine of `src/c64/juego_final/` can be read next to the original.

## Three versions of every routine

Each function of the original exists three times in the repository:

1. **the Z80 original**, disassembled from the tape (`data/cpc64/listado/ADDR_name.asm`; `*` marks the instructions
   the recorded sessions executed);
2. **the C translation** (`src/juego/f_*.c`), function by function, written to be read and checked: the hybrid host
   runs it against the Z80 at every call;
3. **the 6502 translation** (`src/c64/juego_final/*.s`), the one the Commodores run.

Example: `ai_clock_load_duration` (Z80 address 5060h) loads the length of the current hour from a table of seven
entries per day.  The Z80:

{{code data/cpc64/listado/5060_f_5060.asm | ^5060 | ^507C}}

The C reference names everything and states the contract:

{{code src/juego/f_logica_b.c | ^/\* 5060 ai_clock_load_duration | ^\x7d}}

The 6502 keeps the same contract — the result in `zhl`, the variables at the same meaning — but computes
`7 (day - 1)` as `8 x - x` with shifts, and indexes the table with `(zp0),y`:

{{code src/c64/juego_final/logica_b.s | ^; 5060 ai_clock_load_duration | ^\s+rts}}

The four hex digits that start the comment (`5060`) are the Z80 address of the function: they are the key that links
the three versions, the certification tools and the notes.

## The registers

The 6502 has one accumulator and two index registers; the Z80 has seven 8-bit registers paired as BC, DE, HL and two
16-bit index registers.  Every routine keeps the interface of its Z80 function, so the Z80 pairs live in fixed
zero-page pairs:

{{code src/c64/juego_final/zp.inc | ^zbc     = \$02 | ^zp0 }}

| Z80 | 6502 |
|---|---|
| A | the accumulator (at entry and exit; free inside) |
| BC, DE, HL | `zbc`, `zde`, `zhl`, low byte first (`zbc` = C, `zbc+1` = B) |
| IX, IY | `zix`, `ziy` (the character and sprite records are usually reached through them) |
| BC', DE', HL', AF' | `zbc2`, `zde2`, `zhl2`, `za2`, `zf2` (EXX becomes copies) |
| the Z and C flags a caller tests | Z and C at the `RTS`, with the Z80's meaning; the 6502's `CMP` sets C the other way round, so a translated comparison often inverts it |
| an inline argument after `CALL` | the same trick: the routine pulls its return address, reads the bytes, and returns past them (see `hud_obsequium_sub` in [The abbey as a game](The-abbey.md)) |

## The data

Every datum the Z80 program reaches by address has a name `D64_NAME`, defined once in the C headers
(`src/juego/datos_*.h`) with its CPC address.  The C64 memory map is generated from a hand-written list of blocks,
and gives every name its C64 address (see [Memory map](Memory-map.md)):

{{code src/c64/juego_final/bloques64.tsv | ^# ---- zero page: the operands | +8}}

Values keep the CPC's units — widths in CPC bytes, positions as the CPC's x bytes and y lines, room and tile numbers,
even the Z80 opcodes that the code writes into itself — so that a memory dump of the C64 can be compared with the
CPC's byte for byte through the map.  Only the addresses change: a pointer stored in the data holds the C64 address,
and the tools relocate the 642 pointer fields that the data contains (`tools/punteros64.py`).

**Self-modifying code.**  The Z80 program rewrites 93 of its own operands and opcodes (a counter kept as the operand
of an `LD A,n`, a `NOP`/`RET` switch...).  On the 6502 those become variables in the zero page, `$24-$9D`, the fastest
place for the hottest values; the rows of kind `smc` above are such operands.

## The machine

The game never touches the hardware directly: every port access of the Z80 (the gate array's inks, the CRTC, the
AY sound chip, the keyboard matrix, `DI`/`EI`) is a call to the platform layer (`src/c64/plataforma/`), with the
CPC's values: `plat_tinta` (pen, colour), `plat_psg` (AY register, value), `plat_teclado_fila` (a CPC keyboard row).
The platform translates them to the VIC-II, the SID and the C64's keyboard (see [The Commodore 64 platform](Platform-C64.md)).
On the C128 the same game is assembled with `-D C128`, and a few macros choose the machine's way to reach memory:

{{code src/c64/juego_final/zp.inc | ^\.macro LEE_SALA | ^\.endmacro}}

## Checked at every step

While the translation grew, a routine could call a function not yet translated: the build put a *trap* there (the
byte `02h`, which halts a real 6502) and the checking host ran the Z80 original in its place, converting the memory to
the CPC's form and back.  So each routine was checked in isolation, from the same state as the Z80, at every call the
recorded sessions make: registers, flags and every data block compared after the call.  The final build allows no
trap.

When everything was 6502, the whole game was certified: the real C64 build runs in VICE with the same keys as the
original in its own emulator, and at every frame the C64's memory is compared with the CPC's through the map
(see [Building and certification](Building.md)).
