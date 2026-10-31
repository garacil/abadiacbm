# Los sprites y la pantalla

[Inicio](Inicio.md) · anterior: [Los personajes y su movimiento](Personajes.md) · siguiente: [Alturas y búsqueda de caminos](Caminos.md)

El CPC no tiene sprites por hardware y el juego tampoco usa los del C64 (salvo para las cabezas del C128 y del P500):
todo lo que se mueve (los personajes, las puertas, los objetos, la luz de la lámpara) es un **sprite** por software,
dibujado en el bitmap junto con las baldosas que tiene delante.  Es el trabajo más caro de un fotograma, y solo se hace
donde algo ha cambiado.  Está en `src/c64/juego_final/logica_a_spr.s`.

## La tabla de sprites

`SPR_TABLE` tiene 23 registros de 20 bytes (y un `FF` al final): primero los seis personajes, luego las puertas, los
objetos y la luz.

| Desplazamiento | Significado |
|---|---|
| +0 | `FE` = inactivo; bit 7 = hay que redibujarlo; bit 6 = compuesto en esta pasada; bits 0-5 = la profundidad (el orden de dibujo) |
| +1, +2 | x (en bytes del CPC, 4 píxeles cada uno) e y (en líneas) |
| +3, +4 | la x y la y anteriores |
| +5, +6 | el ancho y el alto (bit 7 del ancho: borrar la zona antigua) |
| +7, +8 | el gráfico |
| +9, +0A | el ancho y el alto anteriores |
| +0B | la animación (orientación × 4 + fotograma) |
| +0C-0F | el rectángulo que se está componiendo |
| +10, +11 | dónde está el rectángulo en el búfer de sprites |
| +12, +13 | la posición local, para la prueba de profundidad contra las baldosas |

## Componer por rectángulos

`spr_draw_all` hace todo el trabajo, en este orden:

1. hace la lista de los sprites activos y, si ninguno tiene el bit 7 (nada ha cambiado), termina;
2. ordena la lista por profundidad con el método de la burbuja (`[sprite] & 3Fh`, de menor a mayor);
3. a cada sprite que ha cambiado le da un **rectángulo** que cubre su sitio viejo y el nuevo, alineado a las baldosas
   (4 bytes de ancho, 8 líneas de alto), y le reserva un trozo del búfer de sprites, que vacía;
4. compone cada rectángulo: las baldosas de detrás, cada sprite que se solapa con él en orden de profundidad, y las
   baldosas de delante;
5. copia a la pantalla cada rectángulo compuesto de una vez, así que nada parpadea; si el búfer de sprites se llenó,
   vuelve a empezar con los sprites que no cupieron.

{{code src/c64/juego_final/logica_a_spr.s | ^; 447D spr_draw_all | ^\.proc spr_draw_all}}

El alineamiento lo hacen dos rutinas: `spr_rect_tile_align` lleva el principio del rectángulo al principio de su
baldosa y agranda el tamaño a baldosas enteras, y `spr_rect_union_old` lo agranda para cubrir también el rectángulo
viejo, con la aritmética de 8 bits del original:

{{code src/c64/juego_final/logica_a_spr.s | ^; 48FC spr_rect_tile_align | +2}}

En el C64 guardo el búfer con la misma disposición que el bitmap (celda a celda, 8 bytes por celda), así que una
baldosa son 16 bytes seguidos y una fila del rectángulo es una tira de bytes seguidos del bitmap: la copia mueve filas
enteras.

{{code src/c64/juego_final/logica_a_spr.s | ^; The C64 sprite buffer | ^; tiles, faces, door, objects and light lie under}}

## Mezclar un sprite

`la_mezcla` mezcla un sprite en el rectángulo, línea a línea: la pluma 0 es transparente, así que cada byte se combina
con dos tablas (`AND` del fondo con una máscara, `OR` de los píxeles del sprite).  Un sprite en una x impar del CPC
está medio byte desplazado: sus nibbles pasan por una tabla de intercambio.  Los monjes se dibujan en dos partes: la
cara (cada monje la suya) y el hábito (compartido, que se lee hacia atrás cuando está reflejado).

## Las baldosas de delante

Una baldosa tapa a un personaje cuando su profundidad (guardada en el búfer de baldosas al construir la sala, ver
[Las salas y el motor isométrico](Motor-isometrico.md)) está delante de la posición del personaje: `la_capas` copia,
para cada sprite, las baldosas cuya profundidad está entre la del sprite anterior y la de este, y al final las
baldosas que están delante de todo.  Así un personaje que pasa por detrás de una columna desaparece tras ella píxel a
píxel.  La prueba es la del original: la baldosa se dibuja si su profundidad x o y no es menor que el límite de abajo y
las dos son menores que el límite de arriba; una baldosa ya dibujada lleva el bit 7 para no dibujarla dos veces:

{{code src/c64/juego_final/logica_a_spr.s | ^; 4925 spr_draw_tiles_in_depth_range | +7}}

## La copia a la pantalla

{{code src/c64/juego_final/logica_a_spr.s | ^; 47E7 spr_blit_to_screen | ^\.proc spr_blit_to_screen}}

En el C128 la copia espera al haz de barrido (`la_haz`): nunca copia las líneas que el haz va a enseñar enseguida, así
que los sprites aparecen enteros; allí las cabezas se dibujan además en alta resolución con los sprites del propio
VIC-II (ver [El Commodore 128](Commodore-128.md)).

## Dibujar una sala entera

Cuando se entra en una sala iluminada, el búfer de baldosas se dibuja entero en espiral, desde el centro hacia fuera:
8 vueltas de tramos abajo, a la derecha, arriba y a la izquierda, de 4, 1, 5 y 2 baldosas, cada vuelta dos más largos;
de cada entrada, primero la baldosa de fondo y después la de delante, si no son 0:

{{code src/c64/juego_final/logica_a_spr.s | ^; 4A5F iso_draw_room_spiral | +4}}

## Las salas a oscuras y la lámpara

En las salas a oscuras de la biblioteca no se dibuja nada salvo la luz de la lámpara, que sigue a Adso cuando él la
lleva:

{{code src/c64/juego_final/personajes.s | ^; 2236 spr_draw_or_darken | +10}}

La luz es un sprite cuyo gráfico es una máscara: un dibujo de filas de 16 bits que deja visible la zona alrededor de
Adso y oscuro el resto de su rectángulo.  La versión del C64 la aplica de dos en dos nibbles sobre el búfer ordenado por
celdas:

{{code src/c64/juego_final/logica_a_spr.s | ^; The same CPC light mask | ^\.proc la_luz}}

## Todas las rutinas de los sprites

{{rutinas src/c64/juego_final/logica_a_spr.s}}
