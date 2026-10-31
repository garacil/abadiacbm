# Las salas y el motor isométrico

[Inicio](Inicio.md) · anterior: [El reloj y las ceremonias](Reloj.md) · siguiente: [Los personajes y su movimiento](Personajes.md)

La abadía es un mundo de 256 × 256 posiciones en tres pisos (la planta baja, el primer piso con el scriptorium y la
biblioteca bajo el tejado), cortado en **salas** de 16 × 16 posiciones.  Solo se enseña una sala a la vez, dibujada en
proyección isométrica; cuando el personaje al que sigue la cámara sale de ella, se construye y se dibuja la siguiente.
Todo el motor está en `src/c64/juego_final/motor_iso.s`.

## Qué sala, y desde qué lado

Los mapas de los pisos dan un número de sala para cada cuadrado de 16 × 16 de cada piso.  Cada fotograma
`iso_update_camera_room` mira el cuadrado del personaje al que sigue la cámara (`x & F0h`, `y & F0h` y el piso de su
altura); cuando ha cambiado, elige la sala y también la **orientación de la cámara**, que depende de la posición de la
sala: la abadía se ve desde un lado distinto en salas vecinas, uno de los rasgos más conocidos del juego.

{{code src/c64/juego_final/motor_iso.s | ^; 1F79 iso_update_camera_room | +9}}

El piso sale de la altura del personaje con `iso_floor_base`: por debajo de 0Dh es la planta baja (base 00h), desde 18h
la biblioteca (16h) y entre medias el primer piso (0Bh).  El acarreo queda como lo dejaba el Z80, porque hay quien lo
mira:

{{code src/c64/juego_final/motor_iso.s | ^; 2097 iso_floor_base | ^@clr:}}

Con la orientación de la cámara, las coordenadas del mundo se giran antes de proyectarlas.  Son cuatro
transformaciones sobre la rejilla de 28h posiciones; la orientación 2 es la 1 aplicada dos veces.  Al cambiar de sala,
`iso_update_camera_room` copia la dirección de la que toca, de una tabla de cuatro (`ISO_CAMERA_ROTATIONS`), en la
palabra `CHR_CAMERA_TRANSFORM` (2656h): en el Z80 era el operando de un `CALL` que el programa reescribía; en el 6502
es un puntero a una de estas rutinas:

{{code src/c64/juego_final/motor_iso.s | ^; the camera transforms | +24}}

## Las salas son programas

Una sala no es una imagen.  Su registro en la tabla de salas (`ISO_ROOM_TABLE`: 129 registros en el juego de 64 KiB) es
una lista de **entradas** de tres o cuatro bytes, y cada entrada coloca un **bloque** (una pared, un suelo, una
escalera, un arco, una mesa, una estantería…) en una posición de la rejilla de la sala, con dos parámetros de tamaño y
una altura opcional:

| byte | bits | significado |
|---|---|---|
| 0 | 7-1 | el tipo de bloque: un número par, el índice de una palabra de la tabla de bloques |
| 0 | 0 | 1 = sigue un byte de altura |
| 1 | 4-0, 7-5 | x (0-31) y el primer parámetro de tamaño p1 (0-7) |
| 2 | 4-0, 7-5 | y (0-31) y el segundo parámetro de tamaño p2 (0-7) |
| 3 | 7-0 | la altura (si la hay) |

`FF` termina el registro.  `iso_draw_room` vacía el búfer de baldosas, llena el área de juego (de negro si la sala está
a oscuras) y ejecuta el registro; una sala iluminada se dibuja después desde el búfer de baldosas:

{{code src/c64/juego_final/motor_iso.s | ^; 1611 iso_draw_room | ^:       rts}}

`iso_build_room` descodifica una entrada tras otra.  Antes de entrar en un bloque mete en la pila su propia dirección
como marca de vuelta, para que el `END` del bloque vuelva a ella a por la entrada siguiente, igual que hacía el Z80 con
su propia pila:

{{code src/c64/juego_final/motor_iso.s | ^; 163F iso_build_room | ^        txa                             ; A = the height}}

## El intérprete de bloques

Cada bloque es una lista de 12 números de baldosa y un pequeño programa de **código de bytes** que pone esas baldosas
en el búfer.  Los códigos de operación están guardados complementados (`FF` es la operación 0) y el despachador salta a
cada manejador a través de una tabla de direcciones con un `RTS`, el equivalente en el 6502 del `PUSH DE / RET` del
Z80:

{{code src/c64/juego_final/motor_iso.s | ^; 1C2C the dispatcher | ^        rts}}

{{code src/c64/juego_final/motor_iso.s | ^; the handlers of opcodes FFh down to E4h | +12}}

| Código | Significado |
|---|---|
| `FF` END | vuelve a quien llamó (la entrada siguiente de la sala, o el bloque que llamó a este) |
| `FE` / `FD` LOOP | repetir hasta `FA` NEXT p1 o p2 veces |
| `FC` / `FB` | guardar / recuperar la posición |
| `F9` / `F8` / `EB` | una tira de baldosas: hacia arriba, a la derecha, a la izquierda, una celda tras cada una |
| `F7` SET | un registro := una expresión (operandos: literales, los registros de baldosa, p1, p2, la altura, la profundidad) |
| `F6`-`F1` | mover la posición: y+1, x+1, y−1, x−1, y += expr, x += expr |
| `F0`-`ED` | p1 / p2 más o menos 1 |
| `EC` CALL, `E4` CALL_KEEP | ejecutar otro bloque aquí (con sus baldosas o conservando estas) |
| `EA` JUMP | seguir en el programa de otro bloque: la mayoría de los bloques comparten código así |
| `E9`-`E5` MIRROR | reflejar la dirección x hasta el END del bloque: una pared que mira al otro lado es el mismo bloque reflejado |

### Las expresiones

`SET` y los desplazamientos llevan una expresión: un primer valor y después operandos que se suman hasta un byte de C8h
o más, que no se consume; el byte 84h cambia de signo lo acumulado.  Un operando por debajo de 60h es un literal; 82h
dice que el byte siguiente es un literal; los demás son registros del bloque (61h-6Ch las doce baldosas, 6Dh p1, 6Eh
p2, 6Fh la altura, 70h y 71h la profundidad, intercambiadas cuando el bloque está reflejado):

{{code src/c64/juego_final/motor_iso.s | ^; 1D74 iso_expression | ^@r:     rts}}

Un suelo, por ejemplo, son dos bucles anidados (p2 + 1 filas de p1 + 1 baldosas) de `TILES_UP t1, t1` más un borde, y un
remate delantero; una pared gruesa es el mismo programa que una fina con otra lista de baldosas.  Toda la abadía se
dibuja con menos de cien bloques de unas pocas decenas de bytes cada uno (88 en la tabla de bloques del juego de 64 KiB).

## El búfer de baldosas y la profundidad

La parte visible de la rejilla son 16 × 20 celdas de 16 × 8 píxeles.  Cada celda del búfer de baldosas guarda las dos
**últimas** baldosas que se le pusieron (la de abajo se dibuja primero) y, para cada una, una **profundidad**: la
posición del bloque en el mundo, para que el motor de sprites pueda decidir después, píxel a píxel, si una baldosa
tapa a un personaje.

{{code src/c64/juego_final/motor_iso.s | ^; 1295 iso_put_tile | ^iso_put_tile:}}

Las tiras de baldosas se hacen con `iso_put_tile_step` (poner y dar un paso; el paso es una instrucción que se cambia
según la dirección de la tira) y `iso_put_tile_times` (repetirlo mientras quede cuenta).  La profundidad de un bloque
sale de su posición y de su altura, como la inversa de la proyección de los personajes:

{{code src/c64/juego_final/motor_iso.s | ^; 1BC6 iso_block_depth | ^@r:     rts}}

## El dibujo

Una sala iluminada se dibuja desde el búfer de baldosas en espiral, del centro hacia fuera (`iso_draw_room_spiral`);
cada baldosa son 8 líneas en el formato multicolor del C64, 4 bytes por línea; las baldosas por debajo de 0Bh se copian
opacas y las demás se mezclan con las tablas AND/OR.  Las baldosas viven debajo de la E/S (`$D000`), así que el dibujo
desconecta la E/S mientras las lee.  Una sala a oscuras (las de la biblioteca en el piso alto, todas menos una) deja el
área de juego en negro y solo se ve la luz de la lámpara (ver [Los sprites y la pantalla](Sprites.md)).

## Todas las rutinas del motor

{{rutinas src/c64/juego_final/motor_iso.s}}
