<!-- Made by tools/wiki.py from doc/wiki/fuentes/Platform-C64.md: edit the template, not this page. -->
# The Commodore 64 platform

[Home](Home.md) · previous: [Sound](Sound.md) · next: [The Commodore 128](C128.md)

The game never touches the hardware: every access of the original to the CPC's hardware is a call to the platform
layer, `src/c64/plataforma/`, with the CPC's values.  These few routines are all that makes the CPC game a C64 game.

| File | What |
|---|---|
| `interrupcion.s` | the machine's set-up, the 300 Hz interrupt, `DI` / `EI`, the random byte |
| `pantalla.s`, `tinta.s` | the CPC screen address to the bitmap; the inks |
| `psg.s` | the AY's registers on the SID ([Sound](Sound.md)) |
| `teclado.s` | the CPC's keyboard matrix from the C64's keyboard and joystick |
| `disco.s` | saving and loading a game, and the ending's load, through the KERNAL |
| `c128.s` | the Commodore 128's own parts ([The Commodore 128](C128.md)) |

## The set-up

`plat_inicio` turns the C64 into the machine the game expects: no ROMs (RAM everywhere but the I/O), every interrupt
off but CIA 1's timer A every 3279 cycles (the CPC's 300.48 Hz), the vectors in RAM, the VIC-II in bank 3 with the
multicolour bitmap at `$E000` and the screen RAM at `$C000`, everything black, and the SID at rest:

[`src/c64/plataforma/interrupcion.s`](../../src/c64/plataforma/interrupcion.s#L57-L125), lines 57–125:

```asm
.proc plat_inicio
        sei
        cld
        lda     #MEM_IO
        sta     MEMCFG
        lda     #$7F                    ; no interrupts from the CIAs
        sta     CIA1_ICR
        sta     CIA2_ICR
        lda     CIA1_ICR
        lda     CIA2_ICR
        lda     #0                      ; none from the VIC-II, no sprites
        sta     VIC_D01A
        sta     VIC_D015
        sta     VIC_BORDE
        sta     VIC_FONDO
        lda     #$FF
        sta     VIC_D019
        sta     CIA1_DDRA               ; the keyboard: columns out, rows in
        sta     CIA1_PRA
        lda     #0
        sta     CIA1_DDRB
        lda     #<plat_nmi              ; the vectors (RAM: the KERNAL is off)
        sta     $FFFA
        sta     $FFFC
        lda     #>plat_nmi
        sta     $FFFB
        sta     $FFFD
        lda     #<plat_irq
        sta     $FFFE
        lda     #>plat_irq
        sta     $FFFF
.ifdef C128
        jsr     c128_inicio             ; the common RAM, block 1's vectors (plataforma/c128.s)
.endif
        lda     CIA2_DDRA               ; VIC bank 3 ($C000-$FFFF): bits 0-1 = 00 (the serial bus bits kept)
        ora     #$03
        sta     CIA2_DDRA
        lda     CIA2_PRA
        and     #$FC
        sta     CIA2_PRA
        lda     #$08                    ; screen RAM $C000, bitmap $E000
        sta     VIC_D018
        lda     #$18                    ; multicolour, 40 columns
        sta     VIC_D016
        ldx     #0                      ; the screen RAM and the colour RAM black
        txa
:       sta     PANTALLA,x
        sta     PANTALLA+$100,x
        sta     PANTALLA+$200,x
        sta     PANTALLA+$2E8,x
        sta     COLOR_RAM,x
        sta     COLOR_RAM+$100,x
        sta     COLOR_RAM+$200,x
        sta     COLOR_RAM+$2E8,x
        inx
        bne     :-
        lda     #$3B                    ; bitmap mode, display on, 25 rows
        sta     VIC_D011
        jsr     psg_inicio
        lda     #<(CICLOS_TICK - 1)     ; CIA 1 timer A: the tick
        sta     CIA1_TAL
        lda     #>(CICLOS_TICK - 1)
        sta     CIA1_TAH
        lda     #$11                    ; load, start, continuous
        sta     $DC0E
        lda     #$81                    ; its interrupt on
        sta     CIA1_ICR
        rts
.endproc
```

## The keyboard and the joystick

The game reads the CPC's keyboard as ten rows of eight keys (`sys_read_keyboard`).  Reading the first row makes the
C64 scan its whole keyboard and the joystick in port 2 and translate them, key by key, into the CPC's matrix; the
other nine rows return that picture:

[`src/c64/plataforma/teclado.s`](../../src/c64/plataforma/teclado.s#L19-L37), lines 19–37:

```asm
; plat_teclado_fila: A = CPC matrix row 0-9 -> A = the row, active low (bit b of row r = CPC key 8r + b).
; X kept, Y clobbered.  Needs the I/O visible ($01 = $35).
; The game reads the ten rows in order (sys_read_keyboard 2D50h, its only reader): reading row 0 scans the
; whole C64 matrix and the joystick into the ten rows, the other rows return that scan (one consistent picture,
; as the CPC's scan of a few hundred microseconds).
;   - joystick port 2 ($DC00 with no column selected): CPC row 9, the CPC's joystick 0: bits 0-3 up, down, left,
;     right as the C64's, fire -> bit 5 (fire 1).  The game's own aliases (2E2Eh-2E41h) then give, as on a
;     CPC: up = advance, left/right = turn, down = space, fire = cursor down.
;   - each C64 key -> one CPC key (tecla_cpc, by the C64 matrix position): letters, punctuation, space, return,
;     shift, CTRL -> CONTROL, RUN/STOP -> ESC, the left-arrow key -> TAB, INST/DEL -> DEL, C= -> COPY,
;     CRSR down / right -> cursor down / right, with SHIFT -> cursor up / left (the C64's own cursor keys).
;   - Q A O P as the cursors (the C64's cursors need SHIFT for up and left, so walking with
;     SHIFT + CRSR down and turning with CRSR right reads as left): A -> cursor down (Adso), O -> cursor left,
;     P -> cursor right, Q -> cursor up (walk) but when R is down too, then the CPC's Q (the mirror's Q + R:
;     press R first, or Guillermo walks up a step).
;   - the digit keys choose the save slot (the last character of the save file's name, disco.s), not CPC keys:
;     the game does not read them.
;   - rows that read low with no column selected (joystick port 1, or a key in a column joystick 2 pulls low)
;     are left out of the scan, so the joystick does not make phantom keys.
```

## The inks

See [Memory map](Memory-map.md), "The screen": a CPC ink becomes `$D021`, a nibble of the screen RAM or the colour RAM
of the game's cells, and no pixel is redrawn.  The game's palette tables already hold C64 colours, chosen by hue from
the CPC's (`src/c64/datos/paleta.tsv`).

## The disk and the KERNAL

The game uses the zero page and pages 2-3, which the KERNAL needs.  To save or load a game (CTRL + ← in the game) or
to load the ending, the platform puts the KERNAL's part of those pages aside, gives them the values the KERNAL starts
with, switches the KERNAL ROM in, calls it, and puts everything back:

[`src/c64/plataforma/disco.s`](../../src/c64/plataforma/disco.s#L18-L44), lines 18–44:

```asm
; plat_disco_guarda: In: zhl = the block's first byte, zde = its length (the tape menu's saved game: 1500 bytes
;   from D64_STATE_BUFFER).  Saves it as the file "ABADIA64.BSn" (n = plat_ranura, the last digit key pressed,
;   "1" at first: teclado.s) on the drive plat_unidad, replacing it (the old one is scratched first).  Out:
;   C = 0, or C = 1 when the KERNAL reported an error (no drive...; the drive's own errors, such as a full disk,
;   are not read back).  A, X, Y clobbered; zbc..zp3 kept.
; plat_disco_carga: In: zhl = where, zde = the length.  Loads "ABADIA64.BSn" there.  Out: C = 0 when it was
;   loaded and had exactly that length, else C = 1 (no file, an error; a longer file would have been loaded
;   past the block: only this game writes these files).  A, X, Y clobbered.
;   Both are called with the interrupts off (the tape menu's DI) and return with them off; no tick is
;   delivered meanwhile (as during the CPC's tape operations).
; plat_final: the end of the game: loads the ending parchment ("FINAL", c64/pergamino/final.prg, a cc65
;   program at $0801) from plat_unidad and runs it ($080D); never returns.  The game's screen stays while it
;   loads; then the machine is set as after a reset (IOINIT, RAMTAS, the KERNAL's vectors, CINT) for that
;   program, which expects the KERNAL's interrupt chain.  A load error flashes the border and tries again.
;
; The game uses the zero page and $0200-$03FF (c64/MAPA.md), which the KERNAL needs.  Around a KERNAL call the
; KERNAL's part of them is put aside in $0100-$01AE (the bottom of the stack page: the stack is shallow at the
; tape menu, ~16 bytes, and the KERNAL's own use of it is measured below 60 bytes: c64/plataforma/README.md)
; and given the values the KERNAL starts with:
;   $90-$FF (the KERNAL's zero page: status, file and serial variables) -> 0;
;   $0259-$0276 (the file tables: OPEN writes entry 0) -> kept aside, untouched;
;   $02A1 (the RS-232 flags: the serial LISTEN waits while bits 0-1 are set) -> 0;
;   $0314-$0333 (the vectors) -> the KERNAL ROM's table (copied from $FD30: RESTOR would also write the RAM
;     under $FD30, a part of the bitmap), with the NMI (RESTORE key) -> an RTI and the IRQ -> an acknowledge.
; CIA 1's timer A interrupt is off during the call (the KERNAL's serial code reads CIA 1's flags itself), $01 =
; $36 (KERNAL and I/O; $A000-$BFFF stays RAM: the game's data is readable), the VIC bank and the screen as
; the game has them (the serial code keeps $DD00's bits 0-1).  Then everything goes back.
```

The saved game is the 1500-byte state block that the CPC saved to tape (the characters, the objects, the doors, the
clock, the scripts' variables), as a file `ABADIA64.BSn` — n being the last digit key pressed, so ten games can be
kept.  On the tape release the same menu saves and loads on the tape through the KERNAL's tape routines.

## The random byte

The original reads the Z80's refresh register (`LD A,R`) once: to choose the mirror's numeral.  The C64 combines the
CIA's timer, which runs within the tick, with the raster line:

[`src/c64/plataforma/interrupcion.s`](../../src/c64/plataforma/interrupcion.s#L230-L234), lines 230–234:

```asm
.proc plat_aleatorio
        lda     CIA1_TAL
        eor     VIC_D012
        rts
.endproc
```
