# Los personajes y su movimiento

[Inicio](Inicio.md) · anterior: [Las salas y el motor isométrico](Motor-isometrico.md) · siguiente: [Los sprites y la pantalla](Sprites-y-pantalla.md)

Todo el movimiento está en `src/c64/juego_final/personajes.s`: los registros de los personajes, los pasos y los giros,
la lectura de las alturas, las órdenes de movimiento de los monjes, la animación y la proyección a la pantalla.

## Los registros de personaje

Cada uno de los seis personajes tiene un registro de 15 bytes (`CHR_GUILLERMO` y los cinco siguientes, en el orden
Guillermo, Adso, Malaquías, el abad, el registro de Berengario y el de Severino):

| Desplazamiento | Significado |
|---|---|
| +0 | el contador de animación, 0-3 (con el bit 0 a 1: a mitad de un paso) |
| +1 | la orientación, 0-3 (0 = +x, 1 = −y, 2 = −x, 3 = +y) |
| +2, +3, +4 | x, y y la altura |
| +5 | banderas: bit 7 = el personaje ocupa una celda (en las escaleras) en vez de 2 × 2; bit 5 = girado de través en una pendiente; bit 4 = bajando |
| +6 | el estado de volteo de sus gráficos |
| +7, +8 | el desplazamiento de su sprite |
| +9 | el contador de bits de órdenes (bit 7 = sin órdenes) |
| +0A, +0B, +0C-0D | el byte de orden actual, su índice y la dirección del flujo de órdenes |
| +0E | la marca que el personaje deja en el búfer de alturas (10h o 20h) |

Una segunda tabla, `CHR_TABLE` (10 bytes por personaje), une cada uno con su sprite, su registro, su rutina de
comportamiento, la rutina que voltea sus gráficos y su tabla de animación.  En el Z80, `chr_load_params` copiaba esas
cinco palabras en los operandos de cinco instrucciones repartidas por el código; como esa lista de destinos es fija, en
el 6502 las guardo directamente en la página cero y en `$0208`.

## Un paso de un personaje

Cada fotograma, cada personaje pasa por `chr_update`: sale del búfer de alturas (para no estorbarse a sí mismo), piensa
o termina su paso, y vuelve a marcar el búfer de alturas:

{{code src/c64/juego_final/personajes.s | ^; 2472 chr_update | ^\.endproc}}

Un paso dura dos fotogramas (el medio paso del bit 0 del contador de animación); entre dos pasos se ejecuta la **rutina
de comportamiento** del personaje: para Guillermo, las teclas; para los demás, sus órdenes de movimiento.  Lo decide
`chr_think_or_step`: con un paso a medias lo termina, y si no, llama a la rutina de comportamiento por su dirección,
como el `JP (HL)` del Z80.  Cuando Malaquías muere se eleva: su altura sube una unidad cada pocos fotogramas (`ai_malaquias_rise`), y mientras tanto
solo se anima.

## Guillermo

El comportamiento de Guillermo hace tres cosas, en este orden:

* **La caída de la trampa del espejo**: si el estado de Guillermo no es 0, cae; el contador baja, el sprite desciende
  `CHR_GUILLERMO_FALL_DY` líneas cada fotograma y al final desaparece.
* **Nada** mientras la cámara sigue a otro personaje.
* **Las teclas**: izquierda o derecha recién pulsadas (una pulsación nueva, no mantenida) giran; arriba mantenida avanza,
  si las alturas lo permiten.

{{code src/c64/juego_final/personajes.s | ^\.proc chr_guillermo_behaviour | ^guillermo_self:}}

El último detalle es una curiosidad del original que conservo: el Z80 dejaba en HL la dirección de la propia rutina
(23E2h), y `chr_try_advance`, cuando el suelo no es el que se enseña, leía de ahí sus valores por defecto, que resultan
ser los bytes del código (`00 3E`: un `NOP` y el comienzo de un `LD A,n`).  `guillermo_self` son esos dos bytes.

Girar es inmediato:

{{code src/c64/juego_final/personajes.s | ^; 2561 chr_turn | ^\.endproc}}

Antes de avanzar, el juego lee una ventana de 4 × 4 alturas delante del personaje (`chr_probe_ahead`) del **búfer de
alturas** de la sala (24 × 24 celdas alrededor de la sala: la altura del suelo, o la marca de un personaje que está
allí).  Las dos celdas de delante deciden: suelo llano, una unidad hacia arriba, una hacia abajo, o bloqueado.  En las
escaleras un personaje ocupa una celda; en suelo llano, 2 × 2:

{{code src/c64/juego_final/personajes.s | ^; 250C chr_try_advance_2x2 | ^\.endproc}}

El búfer de alturas se rellena al entrar en la sala (`chr_fill_height_buffer`): se vacía, se fija su origen en la sala
del personaje y se llena con los datos de alturas del piso que corresponde.

## Los demás: flujos de órdenes

Adso y los monjes no deciden sus pasos uno a uno.  Su mente (ver [La mente de los monjes](Monjes.md)) elige un destino,
el buscador de caminos ([Alturas y búsqueda de caminos](Caminos.md)) calcula una ruta, y la ruta se escribe como un
**flujo de bits** de órdenes en el búfer de órdenes del personaje.  En cada paso, `chr_ai_follow_commands` lee la orden
siguiente:

{{code src/c64/juego_final/personajes.s | ^; 280D chr_read_command | +5}}

| Bits | Orden |
|---|---|
| `1` (2 × 2), `1b` (una celda) | avanzar (una celda: b = 0 subir o llano, 1 bajar) |
| `01b` | girar (+1 o −1) |
| `001b` | subir o bajar cambiando de tamaño |
| `0000` | volver a empezar el flujo (2 × 2) |
| `0001` | el final: no hay más órdenes |

Antes de intentar el paso, `chr_ai_follow_commands` guarda los diez bytes de la posición del personaje (de +2 a +0B);
supone las diferencias de altura que corresponden a la orden (para cuando el personaje no está en el suelo que se ve),
prueba el paso como Guillermo, y si nadie lo ha movido (otro personaje estaba en medio) vuelve a poner esos diez
bytes:

{{code src/c64/juego_final/personajes.s | ^; 278F chr_ai_follow_commands | +12}}

## Del mundo a la pantalla

`chr_project` convierte una posición en una posición de sprite: coordenadas locales respecto de la sala, giradas según
la orientación de la cámara, y después la proyección isométrica (la fila sale de `x + y − altura` y la columna de
`x − y`):

{{code src/c64/juego_final/personajes.s | ^; 2632 chr_project | +9}}

La tabla de animación da, para la orientación relativa a la cámara y el contador, el gráfico, su ancho y su alto
(`chr_select_frame`).  Los monjes comparten una tabla de cuerpos, y la palabra del gráfico se convierte en la cara de
cada monje; los fotogramas con el bit 4 del índice usan su segunda cara:

{{code src/c64/juego_final/personajes.s | ^; 25B6 chr_select_frame | +5}}

Dos de las cuatro orientaciones se dibujan con los mismos gráficos reflejados: cuando cambia la orientación de un
personaje respecto de la cámara, sus gráficos se voltean **en su sitio** (`spr_flip_guillermo`, `spr_flip_adso` y las
caras de los monjes), como hacía el CPC, sobre el formato de sprite del C64: dos píxeles en un byte, los nibbles
intercambiados a través de una tabla.  Las caras y la puerta están debajo de la E/S, así que se desconecta mientras
tanto:

{{code src/c64/juego_final/personajes.s | ^; 2F57 spr_flip_graphics_h | +7}}

## Todas las rutinas de los personajes

{{rutinas src/c64/juego_final/personajes.s}}
