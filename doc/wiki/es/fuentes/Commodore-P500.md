# El Commodore P500

[Inicio](Inicio.md) · anterior: [El Commodore 128](Commodore-128.md) · siguiente: [La carga: cinta y discos](Carga.md)

El P500 es el CBM-II 510: un MOS 6509, el VIC-II y el SID del C64, 128 KiB de RAM y unidades de disco IEEE-488.
abadia128ks funciona en él como el juego completo del C128 (`-D C128`: los datos del segundo banco, las cabezas en alta
resolución, el Ave María) sobre una plataforma propia (`-D P500`: `src/c64/plataforma/p500.s`, `interrupcion500.s`,
`teclado500.s`, `tinta500.s`, `io500.inc`).  Cada dato de la máquina que uso sale del *700 Reference Guide* de
Commodore, de la ROM del KERNAL 901234-02 y del entorno cbm510 de cc65, y lo comprobé en el xcbm5x0 de VICE
(`doc/referencias/p500.md`).

## Los bancos del 6509

El 6509 direcciona 16 bancos de 64 KiB.  No tiene instrucciones propias: dos registros en `$0000` y `$0001` de cada
banco eligen el banco en el que corre el programa y el banco de las únicas dos instrucciones que leen o escriben en
otro banco, `LDA (zp),Y` y `STA (zp),Y`.  Cualquier otra instrucción con `(zp),Y` (un `CMP`, un `ADC`…) lee el banco en
el que se ejecuta: lo comprobé, y el teclado tuvo que leer con `LDA` y comparar después.  El juego corre en el banco 0
con `$01 = 0`; sus salas, sus textos, los trazos negros de las cabezas y el Ave María están en el banco 1; todos los
chips están en el banco 15:

{{code src/c64/plataforma/io500.inc | ^; The MOS 6509 has the 6502's instructions | +5}}

Lo que el C128 alcanza poniendo el bloque 1 con su MMU, el P500 lo alcanza byte a byte a través del registro del banco
indirecto; `far_lee` es el lector de la tabla de salas:

{{code src/c64/plataforma/p500.s | ^\.proc far_lee | ^\.endproc}}

Un `LDA abs` normal siempre lee el banco en el que corre el programa: la copia de los trazos negros de una cabeza desde
el banco 1 también tuvo que pasar a ser una lectura indirecta (`cabezas128.s`, `neg_b1_copia`).

## Los chips del banco 15

El código que se comparte con el C64 y el C128 escribe en el VIC-II y en el SID a través de tres macros: en esas
máquinas cada una es la instrucción normal, los mismos bytes de antes; en el P500 es una llamada corta que pone
`$01 = 15` alrededor de un `STA (zp),Y`:

{{code src/c64/plataforma/io500.inc | ^\.macro P5_STA | ^\.endmacro}}

{{code src/c64/plataforma/p500.s | ^p5_vic_k: | ^        rts}}

Para que el VIC-II vea la pantalla del banco 0, las líneas CA y CB de la primera 6525 (la TPI 1, registro de control
`$DE06`, bits 4-7 = %1010) tienen que estar bajas; con el valor que dejaba el pergamino de 2016 ($03) la pantalla de
carga salía negra.

## La interrupción de 300 Hz

El tick del juego viene del temporizador A de la 6526, a través de la primera 6525 (la TPI 1), el controlador de
interrupciones del CBM-II.  El orden de la confirmación importa: si se termina la TPI 1 mientras la línea de la 6526
sigue baja, la interrupción vuelve enseguida, para siempre; si solo se lee la 6526 antes de la TPI 1, se pierde el tick
que cae entre las dos y ya no llega ningún tick más.  Así que la 6526, la TPI 1 y otra vez la 6526:

{{code src/c64/plataforma/interrupcion500.s | ^; the game's build: the game's sys_tick \(2899h\) inline | ^        rti}}

## El teclado

El teclado del CBM-II es una matriz de 16 columnas y 6 filas en la segunda 6525 (la TPI 2), que leo como la lee el
KERNAL (cada fila dos veces, hasta que dos lecturas coinciden), y los dos puertos de juego están en la 6526; el
resultado es la matriz del CPC que lee el juego, igual que en el C64:

{{code src/c64/plataforma/teclado500.s | ^columna: | ^        bpl     columna}}

## El KERNAL del banco 15

Grabar y cargar pasan por el KERNAL, que tiene su propia página cero y su propia pila en el banco 15: no hay que mover
nada del juego (el C128 intercambia su RAM con una foto).  La llamada entre bancos es el propio protocolo del KERNAL, el
mismo que usa el entorno de cc65: la pila del banco 15 recibe el camino de vuelta, los registros y la dirección de la
rutina; un `STA $00` en `$FFF6`, igual en los dos bancos, lleva la CPU al banco 15:

{{code src/c64/plataforma/p500.s | ^\.proc k15 | ^\.endproc}}

## La carga

El menú, el pergamino y el cargador son un programa de cc65 para el destino cbm510.  Carga el banco 1 del juego y su
banco 0, comprimido, en el banco 1, y empieza allí la última etapa: corriendo en el banco 1, la etapa descomprime en el
banco 0 con las dos instrucciones entre bancos (el descompresor de Exomizer sin cambios: sus literales se leen en el
banco que corre, y sus copias y su salida van por `LDA`/`STA (zp),Y`), pone las opciones (las notas del paso y del
pitido en silencio si se han quitado, ver [El sonido](Sonido.md)), carga el Ave María y entra en el juego:

{{code src/c64/discop500/etapa500.s | ^; the game: bank 0's \$FFF6-\$FFFA | ^salto: }}

La etapa se queda en el banco 1 durante toda la partida: con el 100 % el juego vuelve a ella, y ella carga el final
encima del juego y lo arranca como lo haría el `SYS` del BASIC (`src/c64/discop500/NOTAS.md`).
