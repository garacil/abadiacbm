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

{{code src/c64/cinta/turbo.s | ^; abadia64ks on tape: the turbo loader's core | ^; at \$02B0-\$02FF}}

Los bloques, en su orden en la cinta:

{{code src/c64/cinta/cinta.inc | ^; the blocks' ids, in their order on the tape | ^ID_FINAL}}

El juego viaja como un **flujo**: la imagen del juego cortada en segmentos, cada uno con su destino, leídos directamente
a la memoria mientras la pantalla de carga sigue a la vista; primero todo lo que la pantalla no enseña, luego una
marca, y después los bytes escondidos en las celdas laterales del bitmap (ver `src/c64/cinta/FLUJO.md`).  Para el
inglés, un último bloque lleva solo los bytes que cambian.  La etapa del final espera más adelante en la cinta: cuando
se gana la partida, el juego pide que se vuelva a poner en marcha la cinta (*PON EL CASSETTE EN MARCHA*) y el KERNAL
lee «FINAL» desde donde se paró la cinta.

El cargador recibe en la cabecera del flujo las direcciones del juego que tiene que tocar: su entrada, la unidad, las
opciones, y las dos notas que las opciones pueden silenciar.  Con los sonidos quitados, escribe el silencio en la nota:

{{code src/c64/presentacion/cargador.s | ^; 0Fh \(a rest\) at the address in the zero page at X | +10}}

## El disco del C64 (abadia64ks.d64)

La misma edición en una 1541 o una 1571: el menú, la presentación y el final comprimidos con Exomizer, el flujo del
juego leído con el KERNAL según llega, los bytes en inglés como un fichero propio y las partidas grabadas en el disco:

{{code src/c64/disco64/NOTAS.md | ^\x7c File \x7c What \x7c | ^\x7c FINALZ}}

## El disco del C128 (abadia128ks.d64)

El C128 arranca desde el sector de arranque del disco y lo carga todo de una vez, fichero a fichero, cada fichero
comprimido:

{{code src/c64/disco128/NOTAS.md | ^\x7c track 1 sector 0 | ^\x7c FINAL \x7c}}

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
