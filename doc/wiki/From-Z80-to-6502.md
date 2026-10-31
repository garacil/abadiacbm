<!-- Made by tools/wiki.py from doc/wiki/fuentes/From-Z80-to-6502.md: edit the template, not this page. -->
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

[`data/cpc64/listado/5060_f_5060.asm`](../../data/cpc64/listado/5060_f_5060.asm#L3-L18), lines 3–18:

```text
5060 * ld a,(028d1h)
5063 * dec a
5064 * ld b,a
5065 * add a,a
5066 * ld c,a
5067 * add a,a
5068 * add a,b
5069 * add a,c
506A * ld hl,04ad0h
506D * call util_add_bx_al
5070 * ld a,(028d2h)
5073 * call util_add_bx_al
5076 * ld h,(hl)
5077 * ld l,000h
5079 * ld (028d7h),hl
507C * ret
```

The C reference names everything and states the contract:

[`src/juego/f_logica_b.c`](../../src/juego/f_logica_b.c#L517-L528), lines 517–528:

```c
/* 5060 ai_clock_load_duration (PC 1000:5A23): ai_hour_frames_left := ai_hour_durations[7 (day-1) + hour]
 * << 8 (0 = only the scripts end the hour).  Out: HL = the value. */
uint16_t ai_clock_load_duration(void)
{
    uint8_t d = (uint8_t)(rb(D64_GAME_DAY) - 1);
    uint16_t p = (uint16_t)(D64_AI_HOUR_DURATIONS + (uint8_t)(7 * d));
    uint16_t v;
    p = (uint16_t)(p + rb(D64_GAME_HOUR));
    v = (uint16_t)(rb(p) << 8);
    ww(D64_AI_HOUR_FRAMES_LEFT, v);
    return v;
}
```

The 6502 keeps the same contract — the result in `zhl`, the variables at the same meaning — but computes
`7 (day - 1)` as `8 x - x` with shifts, and indexes the table with `(zp0),y`:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L1519-L1543), lines 1519–1543:

```asm
; 5060 ai_clock_load_duration: ai_hour_frames_left := ai_hour_durations[7 (day - 1) + hour] << 8.  Out: HL.
ai_clock_load_duration:
        lda     D64_GAME_DAY
        sec
        sbc     #1
        sta     zt0
        asl     a
        asl     a
        asl     a
        sec
        sbc     zt0                     ; 7 (day - 1), 8-bit
        clc
        adc     #<D64_AI_HOUR_DURATIONS
        sta     zp0
        lda     #>D64_AI_HOUR_DURATIONS
        adc     #0
        sta     zp0+1
        ldy     D64_GAME_HOUR
        lda     (zp0),y
        sta     zhl+1
        sta     D64_AI_HOUR_FRAMES_LEFT+1
        lda     #0
        sta     zhl
        sta     D64_AI_HOUR_FRAMES_LEFT
        rts
```

The four hex digits that start the comment (`5060`) are the Z80 address of the function: they are the key that links
the three versions, the certification tools and the notes.

## The registers

The 6502 has one accumulator and two index registers; the Z80 has seven 8-bit registers paired as BC, DE, HL and two
16-bit index registers.  Every routine keeps the interface of its Z80 function, so the Z80 pairs live in fixed
zero-page pairs:

[`src/c64/juego_final/zp.inc`](../../src/c64/juego_final/zp.inc#L18-L29), lines 18–29:

```asm
zbc     = $02
zde     = $04
zhl     = $06
zix     = $08
ziy     = $0A
zbc2    = $0C
zde2    = $0E
zhl2    = $10
za2     = $12
zf2     = $13
zt0     = $14                   ; scratch $14-$1B
zp0     = $1C                   ; pointers $1C-$23
```

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

[`src/c64/juego_final/bloques64.tsv`](../../src/c64/juego_final/bloques64.tsv#L19-L26), lines 19–26:

```text
# ---- zero page: the operands the Z80 code rewrites (its fastest variables) ----
D64_AI_BERENGAR_DOOR_MASK    04B0    1    smc    zp    copia    1    script var A9, operand of LD C,n at 04AF
D64_CHR_GUILLERMO_ANIM_COPY    0600    1    smc    zp    copia    1    copy of [2B87] taken by the main loop (217D)
D64_CHR_STAIRS_HEIGHT    0692    1    smc    zp    copia    1    height of the stairs cells (0Dh up, 01h down)
D64_CHR_GRID_OWNER    08A0    2    smc    zp    copia    1    pointer: the character record the grid is built for
D64_OBJ_FOR_EACH_PATCH    09D4    1    smc    zp    copia    1    opcode 00 (NOP) / C9 (RET): obj_for_each_visible stops after one entry
D64_OBJ_ROOM_REDRAW    0A6D    1    smc    zp    copia    1    ORed into byte 0 of every door sprite
D64_OBJ_DOOR_MOVED    0A6F    1    smc    zp    copia    1    80h while the door processed changes state
```

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

[`src/c64/juego_final/zp.inc`](../../src/c64/juego_final/zp.inc#L55-L61), lines 55–61:

```asm
.macro LEE_SALA
  .ifdef C128
        jsr     far_lee
  .else
        lda     (zhl),y
  .endif
.endmacro
```

## Checked at every step

While the translation grew, a routine could call a function not yet translated: the build put a *trap* there (the
byte `02h`, which halts a real 6502) and the checking host ran the Z80 original in its place, converting the memory to
the CPC's form and back.  So each routine was checked in isolation, from the same state as the Z80, at every call the
recorded sessions make: registers, flags and every data block compared after the call.  The final build allows no
trap.

When everything was 6502, the whole game was certified: the real C64 build runs in VICE with the same keys as the
original in its own emulator, and at every frame the C64's memory is compared with the CPC's through the map
(see [Building and certification](Building.md)).
