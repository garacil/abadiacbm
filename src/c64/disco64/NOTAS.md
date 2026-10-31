# abadia64ks on disk: the C64's 1541 disk with the tape's menu

made as the tape is, but on disk for the Commodore 64: the 64ks version on disk too, so that there are
both, tape and disk.  The same release as the tape (src/c64/cinta/NOTAS.md): the menu
(1 language, 2 footsteps, 3 the text's sound; the credits), the presentation and ending with both languages
inside, the game in Spanish plus the English bytes when English is chosen, the sounds turned off as rests, the
ending from the disk at 100 %, the games saved and loaded on the disk.  Every file crunched with Exomizer but the
game's stream (its own literal format, read with the KERNAL as it comes, the picture on the screen meanwhile).

    src/c64/disco64/construye.sh                       # everything from the sources: src/c64/disco64/abadia64ks.d64
    src/c64/cinta/prueba_cinta.py OUT --disco [--opciones KEYS] [--final] [--unidad 1541|1571]    # the disk in VICE, checked

## The disk

| File | What |
|---|---|
| ABADIA64KS | `arranque64.s`: 10 SYS 2061, the menu (`src/c64/cinta/menu.s -D DISCO`) copied to $C000 and run; LOAD"*",8 and RUN |
| ABADIA | the presentation (`src/c64/presentacion` DISCO=1), crunched, loaded where Exomizer says, decrunched to $0801 |
| JUEGO | the game's stream (`src/c64/cinta/flujo_cinta.py --disco`: the tape's format and header, whole) |
| TEXTOS | the English bytes (the tape's English block), read after JUEGO when English was chosen |
| FINAL | `arranque64.s -D FINAL`: loaded by the game at 100 % (plat_final); the options from $C3FF, the ending's stage (`src/c64/cinta/etapa_final.s -D DISCO`) to $C000 |
| FINALZ | the ending, crunched, decrunched to $0801 by that stage |

The menu keeps the options at $02A7 (OPCIONES, as the tape) and the drive at $02A8 (UNIDAD; cc65's programs leave
FA at 3).  The game is the build `src/c64/juego_final` DISCO=1 (`c64disco`, `c64disco_en`): the tape's options and
labels (plat_opciones, cinta_paso, cinta_pitido), the disk's saves and ending (plataforma/disco.s), the ending's
message the same length in both languages ("CARGANDO EL FINAL" / "LOADING THE ENDING").
