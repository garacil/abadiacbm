<!-- Made by tools/wiki.py from doc/wiki/fuentes/Loading.md: edit the template, not this page. -->
# Loading: tape and disks

[Home](Home.md) · previous: [The Commodore P500](P500.md) · next: [Presentation and ending](Parchments.md)

The CPC game came on a tape in three turbo blocks: the first stage (the introduction's parchment), the game with its
loading picture, and the ending, loaded by the game itself at 100 %.  The Commodore releases keep that order and add
a start menu before it.

## The start menu

The first program shows a black screen with white letters and four lines of options (three on the C64):

1. the language: ESPAÑOL (written ESPANOL: the ROM's font has no Ñ) or ENGLISH;
2. the footsteps on or off;
3. the sound of the text (the phrases' beep) on or off;
4. (C128) the Ave María at completas on or off.

The menu's own text is in the language chosen.  The footsteps or the text's sound turned off: the one note of the
footstep's or the beep's sequence becomes a rest as long (`0Fh` at `cinta_paso`, `cinta_pitido`, written when the game
is loaded), so the game plays them as before, silent, and they still end the music as on the CPC.  The Ave María turned
off (C128): its call becomes three `NOP`s (`c128_ave_llamada`), so the game never starts it.

## The tape (abadia64ks.tap)

The C64's KERNAL reads a tape at about 50 bytes a second, so it loads only a short first program; everything else is
in **turbo blocks** of a format of its own, written by `src/c64/cinta/cinta.py` and read by a small loader that the
first program puts in the cassette buffer:

[`src/c64/cinta/turbo.s`](../../src/c64/cinta/turbo.s#L16-L31), lines 16–31:

```asm
; abadia64ks on tape: the turbo loader's core, at $033C (the KERNAL's cassette buffer, free once the KERNAL has
; loaded the first program).  A format of its own, written by cinta.py (c64/cinta/NOTAS.md):
;   a bit: one wave (CIA 1's FLAG fires once a wave): short (CORTO cycles) = 1, long (LARGO) = 0;
;   a byte: 8 bits, the most significant first;
;   a block: the pilot (PILOTO bytes), SINCRO, the header (id, address lo/hi, length lo/hi), the data, the
;     checksum (the XOR of the data bytes).
; A wave is told short or long by CIA 1's timer B in one-shot mode, restarted at every wave with UMBRAL cycles:
; still running at the next wave (bit 0 of the control register B) = short.  The caller keeps the interrupts off
; and the I/O visible ($01 = $35, $36 or $37).
;
;   $033C t_abre    A = a block's id: the tape motor on, the blocks read until that one; out: t_dir, t_cuenta
;   $033F t_byte    A = the block's next byte (X and Y kept; N, Z as A)
;   $0342 t_cierra  the rest of the block skipped, its checksum read: C = 1 bad; the motor off
;   $0345 t_carga   A = id: t_abre, the whole block at its address (not under the I/O), t_cierra
; The entries and the code run at every bit fill the cassette buffer; t_carga, t_cierra and resto (once a block) are
; at $02B0-$02FF, unused by the KERNAL; the variables at $02A8-$02AF; $02A7 holds the menu's options (cinta.inc).
```

The blocks, in their order on the tape:

[`src/c64/cinta/cinta.inc`](../../src/c64/cinta/cinta.inc#L27-L36), lines 27–36:

```asm
; the blocks' ids, in their order on the tape (cinta.py)
ID_MENU      = 1                        ; the menu (to ETAPA; not compressed)
ID_PRES      = 2                        ; the presentation with both languages' picture, parchment border,
                                        ; glyphs and text (Exomizer, decrunched by the menu to $0801)
ID_JUEGO     = 3                        ; the game's stream (Spanish) up to the mark (cargador.s)
ID_JUEGO2    = 4                        ; its rest, after the mark (the loader blackens the side cells between)
ID_TEXTOS_EN = 5                        ; the English game's bytes that differ (read only when English is chosen)
                                        ; then the KERNAL's file "FINAL" (arranque.s, ETAPA_ID = ID_ETAPA_FIN)
ID_ETAPA_FIN = 6                        ; the ending's stage (to ETAPA; not compressed)
ID_FINAL     = 7                        ; the ending's program with both languages' text (Exomizer, to $0801)
```

The game travels as a **stream**: the game's image cut into segments, each with its destination, read straight into
memory while the loading picture stays on the screen; first everything the screen does not show, then a mark, then the
bytes hidden in the bitmap's side cells (see `src/c64/cinta/FLUJO.md`).  For English, a last block carries only the
bytes that differ.  The ending's stage waits further on the tape: when the game is won, the game asks for the tape to
be started again (*PON EL CASSETTE EN MARCHA*) and the KERNAL reads "FINAL" from where the tape stopped.

## The C64 disk (abadia64ks.d64)

The same release on a 1541 or a 1571: the menu, the presentation and the ending crunched with Exomizer, the game's
stream read with the KERNAL as it comes, the English bytes as their own file, and the games saved on the disk:

[`src/c64/disco64/NOTAS.md`](../../src/c64/disco64/NOTAS.md#L15-L22), lines 15–22:

```markdown
| File | What |
|---|---|
| ABADIA64KS | `arranque64.s`: 10 SYS 2061, the menu (`src/c64/cinta/menu.s -D DISCO`) copied to $C000 and run; LOAD"*",8 and RUN |
| ABADIA | the presentation (`src/c64/presentacion` DISCO=1), crunched, loaded where Exomizer says, decrunched to $0801 |
| JUEGO | the game's stream (`src/c64/cinta/flujo_cinta.py --disco`: the tape's format and header, whole) |
| TEXTOS | the English bytes (the tape's English block), read after JUEGO when English was chosen |
| FINAL | `arranque64.s -D FINAL`: loaded by the game at 100 % (plat_final); the options from $C3FF, the ending's stage (`src/c64/cinta/etapa_final.s -D DISCO`) to $C000 |
| FINALZ | the ending, crunched, decrunched to $0801 by that stage |
```

## The C128 disk (abadia128ks.d64)

The C128 boots from the disk's boot sector, and loads everything at once, file by file, every file crunched:

[`src/c64/disco128/NOTAS.md`](../../src/c64/disco128/NOTAS.md#L24-L31), lines 24–31:

```markdown
| track 1 sector 0 | the boot sector (`arranque128.py`): "CBM", no more sectors, the message ABADIA DEL CRIMEN, the program M, then `JMP $1300` (run by the KERNAL's BOOT_CALL in bank 15) | $0B00 (the KERNAL's buffer) |
| M | the menu (`src/c64/cinta/menu.s -D C128`): black, white lower case, centred; 1 language, 2 footsteps, 3 the text's sound, 4 the Ave Maria at completas; the credits | block 0, $1300 |
| ABADIA | the presentation for the C128 (`src/c64/presentacion`, cc65's c128 target, `c128.cfg`), both languages inside, crunched (Exomizer `mem`, placed for an in-place decrunch) | block 0, from $1B00 |
| B | the game's zero page and stack page, then its block 1 (the room table) | block 1, $0E00 |
| J | the game's block 0 crunched in three pieces ($0200-$BFFF, $C400-$FEFF, $FF05-$FFFF) | block 1, ending at $BFFF |
| E | English only: the bytes the English image has different (records) | block 1, after the KERNAL's photograph |
| AVE | the Ave Maria's samples (ave128.py), only when option 4 is on | block 1, ave_muestra ($3098), loaded by the last stage |
| FINAL | the ending for the C128 (cc65), both languages inside | block 0, $1C01, loaded by the game |
```

The last stage runs where the game's screen RAM will be; it photographs the KERNAL's RAM into block 1 (so that the
game can later call the KERNAL to save, load and load the ending), decrunches the game's pieces into block 0, applies
the options, and starts the game.

## Building them

    src/c64/cinta/construye.sh        # the tape (and every C64 image of the game)
    src/c64/disco64/construye.sh      # the C64 disk
    src/c64/disco128/construye.sh     # the C128 disk
    tools/genera_todo.sh [--prueba]   # all three, and with --prueba their tests in VICE

Every build checks its stream with a model of the loader before writing it, and the tests run the real tape or disk
in VICE: the game's memory at its first instruction must equal its image byte for byte (see
[Building and certification](Building.md)).  Both disks are tested with a 1541 and with a 1571.
