<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Carga.md: se edita la plantilla, no esta página. -->
<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# La carga: cinta y discos

[Inicio](Inicio.md) · anterior: [El Commodore P500](Commodore-P500.md) · siguiente: [Presentación y final](Pergaminos.md)

El juego del CPC venía en una cinta con tres bloques turbo: la primera etapa (el pergamino de la presentación), el juego
con su pantalla de carga, y el final, que el propio juego carga con el 100 %.  Las ediciones de Commodore conservan ese
orden y le añaden delante un menú de inicio.

## El menú de inicio

El primer programa enseña una pantalla negra con letras blancas y cuatro líneas de opciones (tres en el C64):

1. el idioma: ESPAÑOL (escrito ESPANOL: la fuente de la ROM no tiene Ñ) o ENGLISH;
2. los pasos, sí o no;
3. el sonido del texto (el pitido de las frases), sí o no;
4. (C128 y P500) el Ave María en completas, sí o no.

El propio texto del menú sale en el idioma elegido.  Con los pasos o el sonido del texto quitados, la única nota de la
secuencia del paso o del pitido se convierte en un silencio de la misma duración (`0Fh` en `cinta_paso`,
`cinta_pitido`, escrito al cargar el juego), así que el juego los toca como siempre, sin que suenen, y siguen
terminando la música como en el CPC (ver [El sonido](Sonido.md)).  Con el Ave María quitado (C128 y P500), su llamada se
convierte en tres `NOP` (`c128_ave_llamada`), así que el juego nunca lo empieza.

## La cinta (abadia64ks.tap)

El KERNAL del C64 lee una cinta a unos 50 bytes por segundo, así que solo carga un primer programa corto; todo lo demás
va en **bloques turbo** de un formato propio, escritos por `src/c64/cinta/cinta.py` y leídos por un pequeño cargador
que el primer programa pone en el búfer del casete:

[`src/c64/cinta/turbo.s`](../../../src/c64/cinta/turbo.s#L16-L31), líneas 16–31:

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

Los bloques, en su orden en la cinta:

[`src/c64/cinta/cinta.inc`](../../../src/c64/cinta/cinta.inc#L42-L51), líneas 42–51:

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

El juego viaja como un **flujo**: la imagen del juego cortada en segmentos, cada uno con su destino, leídos directamente
a la memoria mientras la pantalla de carga sigue a la vista; primero todo lo que la pantalla no enseña, luego una
marca, y después los bytes escondidos en las celdas laterales del bitmap (ver `src/c64/cinta/FLUJO.md`).  Para el
inglés, un último bloque lleva solo los bytes que cambian.  La etapa del final espera más adelante en la cinta: cuando
se gana la partida, el juego pide que se vuelva a poner en marcha la cinta (*PON EL CASSETTE EN MARCHA*) y el KERNAL
lee «FINAL» desde donde se paró la cinta.

El cargador recibe en la cabecera del flujo las direcciones del juego que tiene que tocar: su entrada, la unidad, las
opciones, y las dos notas que las opciones pueden silenciar.  Con los sonidos quitados, escribe el silencio en la nota:

[`src/c64/presentacion/cargador.s`](../../../src/c64/presentacion/cargador.s#L549-L558), líneas 549–558:

```asm
; 0Fh (a rest) at the address in the zero page at X (the I/O out: $01 = $34 here)
silencio:
        lda     0,x
        sta     zsrc
        lda     1,x
        sta     zsrc+1
        ldy     #0
        lda     #$0F
        sta     (zsrc),y
        rts
```

## El disco del C64 (abadia64ks.d64)

La misma edición en una 1541 o una 1571: el menú, la presentación y el final comprimidos con Exomizer, el flujo del
juego leído con el KERNAL según llega, los bytes en inglés como un fichero propio y las partidas grabadas en el disco:

[`src/c64/disco64/NOTAS.md`](../../../src/c64/disco64/NOTAS.md#L32-L39), líneas 32–39:

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

## El disco del C128 (abadia128ks.d64)

El C128 arranca desde el sector de arranque del disco y lo carga todo de una vez, fichero a fichero, cada fichero
comprimido:

[`src/c64/disco128/NOTAS.md`](../../../src/c64/disco128/NOTAS.md#L41-L48), líneas 41–48:

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

La última etapa corre donde estará la RAM de pantalla del juego; fotografía la RAM del KERNAL en el bloque 1 (para que
el juego pueda llamar después al KERNAL para grabar, cargar y cargar el final), descomprime las piezas del juego en el
bloque 0, aplica las opciones y arranca el juego.

## Los discos del P500 (abadia128ks_p500.d80 y .d64)

El mismo contenido en una imagen D80 para una 8050 y en una D64 para una 2031 o una 4040.  El P500 no arranca solo: se
carga con SHIFT + RUN/STOP (que escribe `dL"*` y `RUN`) o con `DLOAD"ABADIA"` y `RUN`.  La carga y la etapa del banco 1
están explicadas en [El Commodore P500](Commodore-P500.md).

## Cómo se construyen

    src/c64/cinta/construye.sh        # la cinta (y todas las imágenes del juego para el C64)
    src/c64/disco64/construye.sh      # el disco del C64
    src/c64/disco128/construye.sh     # el disco del C128
    src/c64/discop500/construye.sh    # los discos del P500
    tools/genera_todo.sh [--prueba]   # la cinta y los dos discos de C64 y C128, y con --prueba sus pruebas en VICE

Cada construcción comprueba su flujo con un modelo del cargador antes de escribirlo, y las pruebas cargan la cinta o el
disco de verdad en VICE: la memoria del juego en su primera instrucción tiene que ser igual a su imagen byte a byte (ver
[Construcción y certificación](Construccion.md)).  Los discos del C64 y del C128 se prueban con una 1541 y con una 1571.
