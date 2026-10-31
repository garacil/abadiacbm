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

{{code src/c64/cinta/turbo.s | ^; abadia64ks on tape: the turbo loader's core | ^; at \$02B0-\$02FF}}

The blocks, in their order on the tape:

{{code src/c64/cinta/cinta.inc | ^; the blocks' ids, in their order on the tape | ^ID_FINAL}}

The game travels as a **stream**: the game's image cut into segments, each with its destination, read straight into
memory while the loading picture stays on the screen; first everything the screen does not show, then a mark, then the
bytes hidden in the bitmap's side cells (see `src/c64/cinta/FLUJO.md`).  For English, a last block carries only the
bytes that differ.  The ending's stage waits further on the tape: when the game is won, the game asks for the tape to
be started again (*PON EL CASSETTE EN MARCHA*) and the KERNAL reads "FINAL" from where the tape stopped.

## The C64 disk (abadia64ks.d64)

The same release on a 1541 or a 1571: the menu, the presentation and the ending crunched with Exomizer, the game's
stream read with the KERNAL as it comes, the English bytes as their own file, and the games saved on the disk:

{{code src/c64/disco64/NOTAS.md | ^\x7c File \x7c What \x7c | ^\x7c FINALZ}}

## The C128 disk (abadia128ks.d64)

The C128 boots from the disk's boot sector, and loads everything at once, file by file, every file crunched:

{{code src/c64/disco128/NOTAS.md | ^\x7c track 1 sector 0 | ^\x7c FINAL \x7c}}

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
