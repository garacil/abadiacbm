# Objetos, puertas y el espejo

[Inicio](Inicio.md) · anterior: [La mente de los monjes](Monjes.md) · siguiente: [El texto y el marcador](Texto.md)

## Objetos y portadores

Nueve registros de objeto (5 bytes cada uno: banderas, orientación, x, y y altura) describen el libro, los guantes, las
gafas, el pergamino, las tres llaves, un hueco sin usar y la lámpara.  Cuando alguien lleva un objeto (bit 7 de sus
banderas), sus bytes x e y guardan en su lugar la dirección de su **portador**.  Los portadores son seis entradas de 7
bytes: Guillermo, Adso, Malaquías, el abad, el registro de Berengario y el de Severino:

| Desplazamiento | Significado |
|---|---|
| +0 | banderas (bit 7: lleva la lámpara; bit 0: ahora no puede coger objetos) |
| +1, +2 | la dirección de la x de su personaje |
| +3 | los objetos que lleva, un bit cada uno (80h el libro, 40h los guantes, 20h las gafas, 10h el pergamino, 08h la llave 1, 04h la llave 2, 02h la llave 3) |
| +4, +5 | las máscaras de lo que puede coger (la lámpara; los demás objetos) |
| +6 | un contador de fotogramas entre dos veces que coge o deja algo |

Guillermo empieza con las gafas y puede cogerlo todo salvo la llave 3; Adso solo puede coger la lámpara y la llave 3.

## Coger y dejar

Cada fotograma `obj_update_inventory` hace las cogidas, las dejadas, los permisos de las llaves y los sonidos, y vuelve
a dibujar los huecos de objetos del marcador:

{{code src/c64/juego_final/logica_a.s | ^; 4BEC obj_update_inventory | +4}}

Un objeto se coge cuando está en la celda de delante de un portador cuyas máscaras lo permiten; así Adso, que anda
detrás de Guillermo, recoge él mismo la lámpara o la llave 3:

{{code src/c64/juego_final/logica_b.s | ^; 4C46 obj_pick_up_objects | +5}}

ESPACIO deja el primer objeto de Guillermo delante de él, si ese suelo está libre y llano:

{{code src/c64/juego_final/logica_b.s | ^; 4DC3 obj_drop_on_space | ^; where the original reads it}}

La rutina que deja el objeto (`obj_drop_object`) mira la celda de delante en el búfer de alturas: tiene que estar
libre, por debajo de 0Dh, como mucho 4 por encima del suelo y a nivel con sus tres vecinas; si el suelo o el búfer no
permiten la prueba, el objeto se deja en la posición del propio personaje.

Los guiones también mueven objetos, copiando cinco bytes que van detrás de la instrucción en un registro: las gafas y la
llave 1 aparecen el día V, la lámpara en la cocina desde el día III, Jorge coge el libro, el abad guarda el pergamino en
su celda.

## Llaves y puertas

En la abadía hay siete puertas.  Cada fotograma `obj_update_doors` abre una puerta cuando hay al lado un personaje que
puede pasar, y la cierra si no; la hoja de una puerta forma parte del búfer de alturas, así que una puerta cerrada corta
el paso:

{{code src/c64/juego_final/objetos_sonido.s | ^; 0B1D obj_door_check_open_close | +9}}

Quién puede abrir cada puerta sale de tres sitios: las **llaves** (la llave 1 y la llave 2 dan a Guillermo una puerta
cada una, la llave 3 le da una a Adso), la **hora del día** (`OBJ_DOOR_CHECK_MASK`: algunas puertas se cierran de
noche) y los **guiones** (las máscaras de puertas de los monjes).  Los mismos permisos abren o cierran los enlaces
entre salas que usa el buscador de caminos:

{{code src/c64/juego_final/logica_b.s | ^; 4D97 obj_update_key_permissions | +2}}

{{code src/c64/juego_final/estado_texto.s | ^; 39F1 obj_set_door_permissions | +4}}

## El manuscrito y el espejo

Cuando Guillermo lleva a la vez las gafas y el pergamino, lee el manuscrito: se elige un número romano al azar, una vez
por partida (el `LD A,R` del CPC; aquí, el temporizador de la CIA y la línea del haz), se escribe sobre la palabra `AAA`
del diccionario y aparece la frase en latín: *SECRETUM FINIS AFRICAE, MANUS SUPRA XIX IDOLUM AGE PRIMUM ET SEPTIMUM DE
QUATUOR*, con IXX, XIX o XXI:

{{code src/c64/juego_final/logica_b.s | ^; 5184 obj_read_manuscript | ^\s+rts}}

En la sala del espejo de la biblioteca, Guillermo tiene que ponerse en el escalón que nombra el número y pulsar Q y R a
la vez.  `game_check_qr_mirror` mira si Guillermo está en x = 22h, a la altura 1Ah, con las dos teclas pulsadas, y
devuelve el escalón por su y (6Dh, 69h, 65h: el 1, el 2 y el 3).  El escalón bueno abre el espejo, el camino al finis
Africae; cualquier otro es una trampa y Guillermo cae:

{{code src/c64/juego_final/personajes.s | ^; 2D99 game_input_and_mirror | +5}}

En el C64 las teclas son las del CPC: Q y R juntas (primero R, como explica `teclado.s`, porque Q sola también hace
andar).  La versión de PC elegía siempre el mismo número; el juego completo del C128 conserva el azar del CPC.

### Los reflejos

Mientras el espejo está cerrado, Guillermo y Adso se reflejan en él.  `iso_mirror_reflect` dibuja la imagen de un
personaje cuando el búfer de alturas es el de la sala del espejo y el personaje está en su suelo (x de 20h a 29h, y de
62h a 6Bh): la refleja (x := 42h − x, la orientación cambiada) y la anima con una rutina de volteo propia:

{{code src/c64/juego_final/logica_b.s | ^; 4F03 iso_mirror_reflect | +7}}

## Todas las rutinas de objetos y sonido

{{rutinas src/c64/juego_final/objetos_sonido.s}}
