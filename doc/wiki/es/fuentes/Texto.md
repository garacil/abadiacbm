# El texto y el marcador

[Inicio](Inicio.md) · anterior: [Objetos, puertas y el espejo](Objetos.md) · siguiente: [El sonido](Sonido.md)

La parte de abajo de la pantalla es el **marcador**: el número del día y el nombre de la hora, los seis huecos de
objetos, la barra del obsequium y una franja por la que las frases de los monjes se desplazan de derecha a izquierda.
En el C64 el marcador forma parte de la propia imagen del bitmap, que ya está en su sitio cuando se carga el juego.  El
texto está en `src/c64/juego_final/estado_texto.s`, que guarda también el estado de la partida.

## Palabras y frases

El juego no guarda oraciones: guarda un **diccionario** de palabras (`TXT_WORDS`, con el bit 7 en la última letra de
cada una) y 56 **frases** (`TXT_PHRASES`), cada una una lista de números de palabra terminada en `FF`:

| Byte | Significado |
|---|---|
| menor que F9h | la palabra n, con un espacio delante |
| `F9 n` | la palabra n pegada a la anterior (sin espacio) |
| `FA`-`FE` | signos: ¿ ? ; . , |
| `FF` | el final de la frase |

La fuente no tiene Ñ: el diccionario la escribe como W, y el dibujo de la W es una Ñ (la versión inglesa dibuja una W de
verdad).  Cada frase tiene además un byte de **voz** (`TXT_PHRASE_SOUND`): el tono del pitido que acompaña a sus
letras, uno por cada personaje que habla (el abad, Adso, Malaquías, Berengario, Severino, Jorge, Bernardo, el
manuscrito).

## Decir una frase

Un guion llama a `hud_say` con el número de frase detrás de la llamada; la frase empieza si no se está enseñando otra
(`hud_say_now` interrumpe la que esté sonando):

{{code src/c64/juego_final/logica_a.s | ^; 4B71 hud_say_now | ^\.endproc}}

{{code src/c64/juego_final/logica_a.s | ^; 4B7C hud_say: | +3}}

Los guiones también pueden decir una frase guardada en una variable (`ai_say_phrase_param`, la variable A2h), para las
frases que cambian según el día.

## El desplazamiento

La frase se desplaza en la interrupción de 300 Hz: cada 45 ticks la franja se mueve a la izquierda el ancho de un
carácter y la letra siguiente se dibuja en su extremo derecho, con un pitido en la voz del que habla.  Como el
desplazamiento pertenece a la interrupción, la frase sigue mientras el fotograma dibuja, igual que en el CPC:

{{code src/c64/juego_final/estado_texto.s | ^; 368A txt_phrase_tick | ^\.ifdef PRUEBA}}

En el C64 un carácter del CPC tiene 2 bytes de ancho (8 píxeles del CPC = 4 píxeles multicolor): un byte del bitmap.
Los dibujos son los de la fuente del CPC reducidos a 4 píxeles (dos filas del dibujo por byte; la N retocada a mano);
las letras de una frase se dibujan invertidas:

{{code src/c64/juego_final/estado_texto.s | ^; 3649 txt_draw_char_inverted | +4}}

## El resto del marcador

* **El nombre de la hora** entra en su recuadro en 9 pasos cuando cambia la hora (`hud_scroll_hour_name`); los nombres
  tienen 7 caracteres cada uno (*NOCHE*, *PRIMA*, *TERCIA*, *SEXTA*, *NONA*, *VÍSPERAS*, *COMPLETAS*: los dos últimos
  escritos para que quepan).
* **El número del día** son tres dibujos de una tablita (blanco, V, I) por día: I, II, III, IV, V, VI, VII.
* **Los huecos de objetos** enseñan lo que lleva Guillermo, dibujado con los propios sprites de los objetos:

{{code src/c64/juego_final/logica_b.s | ^; 4D30 hud_draw_objects | +4}}

* **La barra del obsequium**: 8 bytes, un cuarto de byte por punto (ver [El juego](El-juego.md)).

## Las paletas

El juego cambia de colores sin tocar ningún píxel: tres rutinas ponen las plumas 3, 2, 1, 0 y el borde con los cinco
colores de cada paleta (negra, de día y de noche), que en la imagen del C64 ya son colores del C64:

{{code src/c64/juego_final/estado_texto.s | ^; 3A83 vid_palette_black | +1}}

## El estado de la partida

Una partida nueva no se prepara a mano: al arrancar, `sys_startup_init` hace una **foto** de los bloques del estado
inicial (`game_snapshot_initial_state`), y cada partida nueva los restaura (`game_init_new_game`), esconde todos los
sprites y vuelve a poner los seis registros de personaje.  Una lista de pares (dirección, longitud) dice qué bloques son
el estado, y la misma rutina los recorre para guardar o para restaurar, según la función que se le dé:

{{code src/c64/juego_final/estado_texto.s | ^; 3111 game_for_each_state_block | +2}}

Al cargar una partida grabada, `obj_fix_owner_pointers` vuelve a calcular los punteros de los portadores de los objetos
cogidos, que dependen de las direcciones de esta máquina.  La pausa (INST/DEL en el C64) apaga las interrupciones y el
sonido y espera a que se pulse otra vez la misma tecla:

{{code src/c64/juego_final/estado_texto.s | ^; 2FB9 sys_check_pause_save_load | +2}}

## Los idiomas

Las ediciones de Commodore están en español y en inglés, a elegir en el menú de inicio.  El juego en inglés es el
español con otro diccionario y otras frases (las mismas 56 frases con las mismas voces, traducidas al inglés británico
para que quepan en los mismos bytes), los nombres de las horas (*NIGHT*, *PRIME*, *TERCE*, *SEXT*, *NONES*, *VESPERS*,
*COMPLIN*), *Day* en el marcador, una W de verdad en la fuente, Y:N para la pregunta de Adso y las líneas de la
pantalla final: el generador es `src/c64/ingles/genera_ram_en.py`, a partir de `src/c64/ingles/frases_en.txt`.  La
cinta lleva los bytes en inglés como un bloque aparte, que solo se lee si se elige el inglés.  La frase 0, el enigma en
latín del espejo, es la misma en los dos.

## Todas las rutinas del texto y del estado

{{rutinas src/c64/juego_final/estado_texto.s}}
