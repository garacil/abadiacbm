# abadia128ks: the disk of the 128 KiB machines (milestone H10)

The Commodore 128 in its own mode (C128 mode, not C64 mode), one source tree with the C64 (`-D C128`): the game is
the C64's, certified against the CPC's Z80 like it, with the C128's memory management; the disk boots by itself
and loads everything at once, file by file, crunched with Exomizer (everything as on the tape, but on
disk, file by file).  Every C128 fact used here was read in "Mapping the Commodore 128" (Ottis R. Cowper,
COMPUTE! Books, 1986; doc/referencias/c128.md) and checked in x128 (VICE 3.10, its own ROMs).

## Building and testing

    src/c64/disco128/construye.sh            # everything from the sources: src/c64/disco128/abadia128ks.d64
    src/c64/disco128/prueba128.py OUT [--opciones KEYS] [--frames N] [--final] [--guarda] [--unidad 1571|1541]
                                         # the disk in x128, checked (Xvfb :99)

It must work with both drives: every check is run with
`--unidad 1571` (x128's default, fast serial) and `--unidad 1541` (slow serial, the IRQ on between bytes).  The
1541 found the ending's bug: `plat_final` left the game's $FF05-$FFFF in block 0's RAM, so an interrupt during the
slow LOAD of FINAL went into the game's code being overwritten; it now puts the KERNAL's back first ($E0CD's way).

## The disk

| File | What | Where it goes |
|---|---|---|
| track 1 sector 0 | the boot sector (`arranque128.py`): "CBM", no more sectors, the message ABADIA DEL CRIMEN, the program M, then `JMP $1300` (run by the KERNAL's BOOT_CALL in bank 15) | $0B00 (the KERNAL's buffer) |
| M | the menu (`src/c64/cinta/menu.s -D C128`): black, white lower case, centred; 1 language, 2 footsteps, 3 the text's sound, 4 the Ave Maria at completas; the credits | block 0, $1300 |
| ABADIA | the presentation for the C128 (`src/c64/presentacion`, cc65's c128 target, `c128.cfg`), both languages inside, crunched (Exomizer `mem`, placed for an in-place decrunch) | block 0, from $1B00 |
| B | the game's zero page and stack page, then its block 1 (the room table) | block 1, $0E00 |
| J | the game's block 0 crunched in three pieces ($0200-$BFFF, $C400-$FEFF, $FF05-$FFFF) | block 1, ending at $BFFF |
| E | English only: the bytes the English image has different (records) | block 1, after the KERNAL's photograph |
| AVE | the Ave Maria's samples (ave128.py), only when option 4 is on | block 1, ave_muestra ($3098), loaded by the last stage |
| FINAL | the ending for the C128 (cc65), both languages inside | block 0, $1C01, loaded by the game |

The menu keeps the options at $0BFF and the boot drive at $0BFE (the end of the boot sector's buffer, free once
it has run; FA, $BA, is 3 by the time the presentation's loader runs: cc65's output to the screen).

## The loading

1. The boot sector loads M; the menu loads ABADIA with the KERNAL and decrunches it with Exomizer's own decruncher
   (`src/c64/cinta/exodecrunch.s`), cc65's configuration ($FF00 = $0E) meanwhile; then the presentation runs.
2. The presentation (the parchment with the CPC's music; the C128's music interrupt: `sid.s`) shows the picture on
   the game's screen (`presentacion.c` gameload; the bitmap's 5 bytes under the MMU's registers $FF00-$FF04 are left
   out and their cell made black) and calls `carga128.s`: B, J and (English) E into block 1 with the KERNAL
   (SETBNK: the data in block 1, the name in block 0), then the last stage copied to $C000 and started.
3. The last stage (`etapa128.s`, at $C000-$C3E7, the game's screen RAM): the display blanked, 2 MHz, 16 KiB of
   common RAM at the top; the KERNAL's RAM photographed into block 1 (the game's `kernal_foto`); J's pieces
   decrunched from block 1 into block 0; the KERNAL's page $0A00 back (the game keeps it free); the English bytes;
   the game's two pages; the options (plat_opciones, plat_unidad; footsteps or the text's sound off: the note of the
   footstep's or the beep's sequence a rest, 0Fh, played as before but silent); 1 MHz; the game.

Limits met and kept (each one checked in x128):
- The KERNAL's LOAD fails with error 16 (out of memory) once its pointer reaches $FF00, even after the last byte.
- With the top 16 KiB common, block 1 is readable only below $C000: J ends at $BFFF.
- ca65's c128 target translates strings into PETSCII's shifted letters: the file names are bytes.
- $FF00-$FF04 are the MMU's registers in every configuration: no data there (mapa64.py), and the CPU can never write
  the RAM under them.

## The game on the C128 (src/c64/juego_final with C128=1; src/c64/plataforma/c128.s)

- The MMU's $FF00 where the C64 writes $01 (`MEMCFG`, `MEM_RAM` $3F, `MEM_IO` $3E; `MEM_B1` $7F: block 1).
- 4 KiB of common RAM at the bottom ($D506 = $05): segment COMUN ($0800: block 1's readers and writers, the
  interrupt), the KERNAL's page $0A00 (KERNAL128), SALA ($0B00: the room record), COMUN2 ($0C00: the disk); the code
  from there on.
- The room table in block 1 (mapa64.py zone banco1, from $1000): iso_select_room walks it there, iso_draw_room copies
  the room's record into SALA, the mirror's bytes are written there (`LEE_SALA`, `PON_SALA`); every pointer keeps
  its block-1 value, so the certification compares it as the CPC's.
- The sound sequences at $BDE0 (the same low bytes as the C64's $FDE0: the triggers share a page).
- The disk (save, load, the ending) through the C128's KERNAL, its RAM swapped with the photograph.

## Certification

`src/c64/certifica` (lote.sh, certifica.py, vice_cert.py) runs the real C128 build in x128 in step with the CPC's Z80:
block 1's blocks are read from x128's ram01 and given to the host at their map addresses.

## The Ave Maria (the menu's option 4)

The PC version plays its digitised Ave Maria when the hour becomes completas (its 1000:5AAF-5AB3, inside the tail
that sets the hour; also after a load into completas), the game frozen while it sounds.  The C128 the same
(`logica_b.s` lb_hora, `c128_ave` in plataforma/c128.s): `ave128.py` makes the PC's voice (src/c64/datos/pc) into 4-bit
samples at 4031 Hz (13.45 s, 27108 bytes; the PC's last 0.27 s are other data, left out), loaded as "AVE" into block 1
by the last stage once the game is in place (through the KERNAL's photograph), played through the SID's volume
register (the three voices held at a constant level so that an 8580 sounds too) at the pace of CIA 1's timer B, at 1
MHz with the screen shown.  Option 4 off: the file is not loaded and the call is 3 NOPs.  Checked in x128: the
samples in block 1 as ave.bin, the call kept or NOPs, and a recording of the sound (VICE's wav device): 13.4 s with
the PC's envelope (~/Escritorio/abadia128/ave_maria_c128_x128.wav).
