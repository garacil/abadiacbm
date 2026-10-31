# Alturas y búsqueda de caminos

[Inicio](Inicio.md) · anterior: [Los sprites y la pantalla](Sprites.md) · siguiente: [La mente de los monjes](Monjes.md)

Los monjes andan solos por toda la abadía: suben y bajan escaleras, cruzan puertas, van de una sala a otra y de un
piso a otro.  Lo hacen con dos búsquedas en anchura (una dentro de una sala y otra entre salas) y un escritor que
convierte el camino encontrado en órdenes de movimiento.  Es el trabajo más pesado del juego: casi la mitad de los
ciclos del C64 en las sesiones grabadas.  Está en `src/c64/juego_final/camino.s` y `logica_a_cam.s`.

## El búfer de alturas

Cada sala tiene un **búfer de alturas**: 24 × 24 celdas (las 16 × 16 posiciones de la sala y un borde de 4), cada una
con la altura del suelo en ese punto (el nibble bajo) o la marca de un personaje que está encima (10h, 20h).  Se
rellena cuando cambia la sala, a partir de la lista de registros de alturas del piso (zonas llanas, rampas, escalones):

{{code src/c64/juego_final/personajes.s | ^; 2873 chr_fill_height_buffer | +3}}

Las sondas de los personajes lo leen para decidir cada paso (ver [Los personajes y su movimiento](Personajes.md)); las
búsquedas usan un segundo búfer del mismo tipo, construido alrededor del personaje que busca un camino, para que un
monje que está en otra sala pueda planear sin estropear la sala de la pantalla.  Lo construye `chr_path_build_grid`:
rellena el búfer con la sala del monje y, si Guillermo (o la sala de la cámara) está a una sala de distancia como mucho
y en el mismo piso, marca a los demás personajes como obstáculos (10h), da altura 0Fh a las hojas de las puertas
abiertas y quita la marca del propio monje:

{{code src/c64/juego_final/camino.s | ^; 082F chr_path_build_grid | +5}}

## Los conductores de los monjes

Cada fotograma, `game_run_npc_behaviours` llama al *conductor* de cada monje: Malaquías, el abad, Berengario y Severino
comparten el mismo código (el byte 2Ch, un `BIT abs`, salta el `LDX` siguiente para elegir el monje sin saltos), y Adso
tiene el suyo:

{{code src/c64/juego_final/camino.s | ^; 036D ai_update_malachi | +1}}

El conductor ejecuta la mente del monje (ver [La mente de los monjes](Monjes.md)), que deja un destino, y termina en la
cola común 03ACh (`camino_plan_route`):

* si el monje ya tiene un movimiento planeado, solo comprueba que el último intento no falló; si falló, descarta las
  órdenes (`chr_cmd_discard` escribe la orden 10h, «piensa otra vez», al principio del búfer) y en el siguiente
  fotograma se vuelve a planear;
* si la mente ha dicho que no hay que moverse (`AI_NO_ROUTE`), no hace nada;
* si no, busca el camino al destino: un lugar de la tabla de lugares del monje, o uno de cuatro destinos especiales
  (FFh Guillermo, FEh el abad, FDh el libro, FCh el pergamino), cuyas cuatro casillas vecinas son los candidatos; si
  `chr_path_find` contesta que ya está allí, el destino se da por alcanzado.

{{code src/c64/juego_final/camino.s | ^; 03AC \(ai_plan_route | +5}}

## Elegir el tipo de búsqueda

`chr_path_find` es la entrada: llevar a un personaje hacia una posición.  Otro piso: hacia las escaleras que suben o
bajan; otra sala del mismo piso: por el grafo de salas; la misma sala: una búsqueda en el búfer de alturas.  Cuando el
personaje ya está en la casilla de destino, `chr_path_face_target` solo lo gira hacia la orientación pedida:

{{code src/c64/juego_final/camino.s | ^; 05FA chr_path_find | ^\.proc chr_path_find}}

## La búsqueda dentro de una sala

La búsqueda es una expansión en anchura sobre el búfer de alturas a partir de la celda del personaje: cada posición de
la cola prueba sus cuatro vecinas, que tienen que poder pisarse desde ella (la misma altura o una unidad más o menos,
para un personaje de 2 × 2 celdas), y las marca como visitadas (bit 7), hasta que llega a una celda marcada como
destino (bit 6).  Primero se marca como visitado el borde de la sala, para que la búsqueda no se salga:

{{code src/c64/juego_final/logica_a_cam.s | ^\.proc la_sala | ^\.endproc}}

El Z80 usaba su propia **pila** como cola de la búsqueda: metía las posiciones y recorría el puntero de pila sobre
ellas.  La pila del 6502 solo tiene 256 bytes, así que en la traducción la cola está en memoria, en las mismas
direcciones, creciendo hacia abajo como la del Z80, y escribo en ella las mismas palabras que dejaban allí los `CALL` y
los `PUSH` del Z80, para que la memoria siga siendo igual a la del original byte a byte (la certificación la compara).

## Entre salas y entre pisos

El mapa del piso (un byte por sala) funciona como una rejilla más pequeña: la misma búsqueda recorre ese mapa para
encontrar la sucesión de salas hacia la sala de destino, y las puertas son aristas que los permisos de las puertas
abren o cierran.  Después el personaje busca dentro de su sala un camino hasta la franja de celdas que lleva a la sala
siguiente; esas franjas las marcan cuatro rutinas, una por lado (la fila 3, la columna 20, la columna 3 o la fila 20):

{{code src/c64/juego_final/camino.s | ^; 090A chr_path_mark_exit_up | +2}}

Para cambiar de piso, todas las celdas que tienen la altura de la escalera pasan a ser destino.

## Del camino a las órdenes

La búsqueda deja en su cola la celda que llegó al destino.  `chr_cmd_write_path` recorre la cola hacia atrás para
reconstruir el camino, simula el paseo del personaje por él y escribe las órdenes (giros y pasos) en su búfer de
órdenes, como el flujo de bits que el personaje leerá paso a paso:

{{code src/c64/juego_final/logica_a_cam.s | ^; 41C9 chr_cmd_write_path | +8}}

Los bits se añaden de uno en uno con `chr_cmd_write_bits`, el bit más alto primero: cada ocho bits el byte completo
pasa al búfer:

{{code src/c64/juego_final/camino.s | ^; 0959 chr_cmd_write_bits | +5}}

## Adso

Adso no planea cuando sigue a Guillermo: su conductor mide la longitud del camino entre los dos y da un paso cuando
están bastante separados (4 celdas si Adso ocupa una sola o no comparte ninguna coordenada con Guillermo; si no, 3).
Cuando Guillermo se le echa encima, Adso se aparta, y el jugador puede empujarlo con la tecla *abajo*
(`chr_adso_step_aside`, `chr_adso_step_guillermo_dir`).  Si un movimiento planeado falla, lo cuenta hasta 10 veces
antes de descartarlo:

{{code src/c64/juego_final/camino.s | ^; 04EB ai_update_adso | +10}}

## La memoria del C128

Sin pulsar teclas, el original repite cada fotograma algunas búsquedas que fallan igual (Severino desde el fotograma 674
del principio, por ejemplo: 1328 llamadas idénticas de 91 152 ciclos cada una).  En el trabajo de velocidad del C128
guardo la última búsqueda de sala a sala que falló (cada byte que lee, como clave; cada byte que escribe, como
resultado) y la repito cuando vuelve la misma llamada: como el 6502 es determinista, las mismas entradas dan las mismas
salidas, y la certificación contra el PC no muestra ninguna diferencia.

{{code src/c64/juego_final/camino_memo.s | ^; abadia64ks, 6502 code of the game: a memo of the whole route | +8}}

## Todas las rutinas de los caminos

{{rutinas src/c64/juego_final/camino.s}}

{{rutinas src/c64/juego_final/logica_a_cam.s}}
