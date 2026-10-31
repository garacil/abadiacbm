# La plataforma del Commodore 64

[Inicio](Inicio.md) · anterior: [El sonido](Sonido.md) · siguiente: [El Commodore 128](Commodore-128.md)

El juego nunca toca el hardware: cada acceso del original al hardware del CPC es una llamada a la capa de plataforma,
`src/c64/plataforma/`, con los valores del CPC.  Estas pocas rutinas son todo lo que convierte el juego del CPC en un
juego del C64.

| Fichero | Qué |
|---|---|
| `interrupcion.s` | la preparación de la máquina, la interrupción de 300 Hz, `DI` / `EI`, el byte aleatorio |
| `pantalla.s`, `tinta.s` | la dirección de pantalla del CPC en el bitmap; las tintas |
| `psg.s` | los registros del AY en el SID ([El sonido](Sonido.md)) |
| `teclado.s` | la matriz del teclado del CPC a partir del teclado y el joystick del C64 |
| `disco.s` | grabar y cargar una partida, y la carga del final, a través del KERNAL |
| `c128.s` | las partes propias del Commodore 128 ([El Commodore 128](Commodore-128.md)) |
| `interrupcion500.s`, `teclado500.s`, `tinta500.s`, `p500.s`, `io500.inc` | las mismas piezas para el P500 ([El Commodore P500](Commodore-P500.md)) |

## La preparación

`plat_inicio` convierte el C64 en la máquina que espera el juego: sin ROM (RAM en todas partes salvo la E/S), todas las
interrupciones apagadas salvo el temporizador A de la CIA 1 cada 3279 ciclos (los 300,48 Hz del CPC), los vectores en
RAM, el VIC-II en el banco 3 con el bitmap multicolor en `$E000` y la RAM de pantalla en `$C000`, todo negro y el SID
en reposo:

{{code src/c64/plataforma/interrupcion.s | ^\.proc plat_inicio | ^\.endproc}}

## El teclado y el joystick

El juego lee el teclado del CPC como diez filas de ocho teclas (`sys_read_keyboard`).  Al leer la primera fila, el C64
explora todo su teclado y el joystick del puerto 2 y los traduce, tecla a tecla, a la matriz del CPC; las otras nueve
filas devuelven esa misma foto, coherente, como la exploración de unos cientos de microsegundos del CPC.  El reparto:

* **el joystick** del puerto 2 pasa a ser el joystick 0 del CPC (fila 9); los alias del propio juego hacen el resto,
  como en un CPC: arriba avanza, izquierda y derecha giran, abajo es ESPACIO y el disparo es cursor abajo (Adso);
* **cada tecla del C64** es una tecla del CPC, por su posición en la matriz: letras, signos, espacio, RETURN, SHIFT,
  CTRL → CONTROL, RUN/STOP → ESC, la flecha izquierda → TAB, INST/DEL → DEL, C= → COPY, y los cursores del C64 (con
  SHIFT para arriba y para la izquierda);
* **Q, A, O y P** hacen de cursores (A adelanta a Adso, O y P giran, Q avanza), salvo **Q con R pulsada**, que es la Q
  del CPC: la combinación Q + R del espejo se hace pulsando primero la R, porque Q sola haría subir a Guillermo un
  escalón;
* **las cifras** no son teclas del CPC (el juego no las lee): eligen la ranura de grabación.

{{code src/c64/plataforma/teclado.s | ^; plat_teclado_fila: A = CPC matrix row | ^;     are left out of the scan}}

## Las tintas

Ver [Mapa de memoria](Mapa-de-memoria.md), «La pantalla»: una tinta del CPC se convierte en `$D021`, en un nibble de la
RAM de pantalla o de la RAM de color de las celdas del juego, y no se redibuja ningún píxel.  Las tablas de paletas del
juego ya tienen colores del C64, elegidos por su tono a partir de los del CPC (`src/c64/datos/paleta.tsv`).

## El disco y el KERNAL

El juego usa la página cero y las páginas 2 y 3, que necesita el KERNAL.  Para grabar o cargar una partida (CTRL + ← en
el juego) o para cargar el final, la plataforma aparta la parte del KERNAL de esas páginas, les da los valores con los
que arranca el KERNAL, conecta la ROM del KERNAL, la llama y lo vuelve a poner todo como estaba:

{{code src/c64/plataforma/disco.s | ^; plat_disco_guarda: In: zhl | the game has them \(the serial code}}

La partida grabada es el bloque de estado de 1500 bytes que el CPC grababa en la cinta (los personajes, los objetos,
las puertas, el reloj, las variables de los guiones), en un fichero `ABADIA64.BSn`, donde n es la última cifra
pulsada, así que se pueden guardar diez partidas.  En la edición de cinta el mismo menú graba y carga en la cinta con
las rutinas de cinta del KERNAL.

## El byte aleatorio

El original lee una sola vez el registro de refresco del Z80 (`LD A,R`): para elegir el número del espejo.  El C64
combina el temporizador de la CIA, que corre dentro del tick, con la línea del haz:

{{code src/c64/plataforma/interrupcion.s | ^\.proc plat_aleatorio | ^\.endproc}}
