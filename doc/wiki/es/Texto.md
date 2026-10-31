<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Texto.md: se edita la plantilla, no esta página. -->
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

[`src/c64/juego_final/logica_a.s`](../../../src/c64/juego_final/logica_a.s#L1119-L1132), líneas 1119–1132:

```asm
; 4B71 hud_say_now: `JSR hud_say_now`, the phrase: a phrase with priority (busy and active cleared, the phrase
; line cleared), then falls into hud_say with the same inline byte.  Its DI is the checked build's only: with the
; phrase inactive the interrupt's t_frase draws nothing, and the C64 clearing the line took ~4800 cycles (a tick
; of the music lost); hud_say makes its own DI ... EI around what the interrupt reads.
.proc hud_say_now
.ifdef PRUEBA
        jsr     plat_di
.endif
        lda     #0
        sta     D64_TXT_PHRASE_BUSY
        sta     D64_TXT_PHRASE_ACTIVE
        jsr     hud_clear_phrase_area
        ; falls into hud_say
.endproc
```

[`src/c64/juego_final/logica_a.s`](../../../src/c64/juego_final/logica_a.s#L1134-L1136), líneas 1134–1136:

```asm
; 4B7C hud_say: `JSR hud_say`, the phrase: starts it unless one is shown (DI ... EI): its voice, busy = active =
; word done := 1, txt_phrase_ptr := the phrase, no trailing blanks.  Out: CF = 1 started (A = 0, B = 0,
; DE = the voice entry, HL = the phrase), CF = 0 busy (A = txt_phrase_busy).
```

Los guiones también pueden decir una frase guardada en una variable (`ai_say_phrase_param`, la variable A2h), para las
frases que cambian según el día.

## El desplazamiento

La frase se desplaza en la interrupción de 300 Hz: cada 45 ticks la franja se mueve a la izquierda el ancho de un
carácter y la letra siguiente se dibuja en su extremo derecho, con un pitido en la voz del que habla.  Como el
desplazamiento pertenece a la interrupción, la frase sigue mientras el fotograma dibuja, igual que en el CPC:

[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L1517-L1526), líneas 1517–1526:

```asm
; 368A txt_phrase_tick: the phrase scroller (300 Hz interrupt): every 2Dh-th call while a phrase is active, a
; beep and the next character (the next letter of the word; at its end a trailing blank or the next phrase byte:
; FFh the end, FA-FE punctuation, F9 nn word nn without a blank, else a blank and word n): the strip (lines
; A4h-ABh, CPC bytes 10h-2Fh) scrolls one C64 byte to the left and the character is drawn inverted at its right
; end.  Every Z80 register is kept.  The game's sys_tick makes the test (the counter + 1 = 2Dh) inline and calls
; t_frase; this entry (the Z80's, with its DI) is for the checks only.
; t_frase: the 2Dh-th tick: the counter to 0 and, while a phrase is active, the character.  X and Y kept (the
; C64's interrupt saves neither); the zero page it uses ($14-$1D: the word pointer in zp0, a flag in zt0,
; txt_draw_char's zt0-zt0+6 and zp0) and txt_cursor are saved and restored.
.ifdef PRUEBA
```

En el C64 un carácter del CPC tiene 2 bytes de ancho (8 píxeles del CPC = 4 píxeles multicolor): un byte del bitmap.
Los dibujos son los de la fuente del CPC reducidos a 4 píxeles (dos filas del dibujo por byte; la N retocada a mano);
las letras de una frase se dibujan invertidas:

[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L1358-L1361), líneas 1358–1361:

```asm
; 3649 txt_draw_char_inverted / 364D txt_draw_char: draws code A (bit 7 ignored; 20h the blank glyph, below
; 2Dh nothing, C set) at txt_cursor (x in CPC bytes, y in lines), opaque: a set pixel pen 3 and a clear one pen
; 2 (inverted: the other way round); a glyph at an odd x straddles two C64 bytes.  Then txt_cursor x += 2.
; Uses only zt0 and zp0 (it runs from the phrase scroller's interrupt too).
```

## El resto del marcador

* **El nombre de la hora** entra en su recuadro en 9 pasos cuando cambia la hora (`hud_scroll_hour_name`); los nombres
  tienen 7 caracteres cada uno (*NOCHE*, *PRIMA*, *TERCIA*, *SEXTA*, *NONA*, *VÍSPERAS*, *COMPLETAS*: los dos últimos
  escritos para que quepan).
* **El número del día** son tres dibujos de una tablita (blanco, V, I) por día: I, II, III, IV, V, VI, VII.
* **Los huecos de objetos** enseñan lo que lleva Guillermo, dibujado con los propios sprites de los objetos:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L834-L837), líneas 834–837:

```asm
; 4D30 hud_draw_objects: the score bar's object slots whose bit is set in A (bit 7 slot 0 .. bit 2 slot 5),
; from C591h, 5 bytes apart and one more after the third: an object held (its bit in C) from its sprite (+5
; width & 7Fh, +6 rows, +7 graphics: objects under the I/O), else cleared (4 x 12 of 00h).  Stops when no bit
; of A is left.
```

* **La barra del obsequium**: 8 bytes, un cuarto de byte por punto (ver [El juego](El-juego.md)).

## Las paletas

El juego cambia de colores sin tocar ningún píxel: tres rutinas ponen las plumas 3, 2, 1, 0 y el borde con los cinco
colores de cada paleta (negra, de día y de noche), que en la imagen del C64 ya son colores del C64:

[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L1329-L1329), líneas 1329–1329:

```asm
; 3A83 vid_palette_black / 3A88 vid_palette_day / 3A8D vid_palette_night: pens 3, 2, 1, 0 and the border :=
```

## El estado de la partida

Una partida nueva no se prepara a mano: al arrancar, `sys_startup_init` hace una **foto** de los bloques del estado
inicial (`game_snapshot_initial_state`), y cada partida nueva los restaura (`game_init_new_game`), esconde todos los
sprites y vuelve a poner los seis registros de personaje.  Una lista de pares (dirección, longitud) dice qué bloques son
el estado, y la misma rutina los recorre para guardar o para restaurar, según la función que se le dé:

[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L449-L450), líneas 449–450:

```asm
; 3111 game_for_each_state_block: game_state_block_fn := zhl (save or restore), called for each (address,
; length) entry of game_state_blocks with a cursor into game_initial_state.  Out: A = 0, Z set, BC = 0.
```

Al cargar una partida grabada, `obj_fix_owner_pointers` vuelve a calcular los punteros de los portadores de los objetos
cogidos, que dependen de las direcciones de esta máquina.  La pausa (INST/DEL en el C64) apaga las interrupciones y el
sonido y espera a que se pulse otra vez la misma tecla:

[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L668-L669), líneas 668–669:

```asm
; 2FB9 sys_check_pause_save_load: the key 4Fh (Del) pauses: interrupts off, the mixer copy and PSG register 7
; := 3Fh, then the keyboard is read until 4Fh is pressed again; interrupts on.  Out: A (Z) = the last
```

## Los idiomas

Las ediciones de Commodore están en español y en inglés, a elegir en el menú de inicio.  El juego en inglés es el
español con otro diccionario y otras frases (las mismas 56 frases con las mismas voces, traducidas al inglés británico
para que quepan en los mismos bytes), los nombres de las horas (*NIGHT*, *PRIME*, *TERCE*, *SEXT*, *NONES*, *VESPERS*,
*COMPLIN*), *Day* en el marcador, una W de verdad en la fuente, Y:N para la pregunta de Adso y las líneas de la
pantalla final: el generador es `src/c64/ingles/genera_ram_en.py`, a partir de `src/c64/ingles/frases_en.txt`.  La
cinta lleva los bytes en inglés como un bloque aparte, que solo se lee si se elige el inglés.  La frase 0, el enigma en
latín del espejo, es la misma en los dos.

## Todas las rutinas del texto y del estado

| Original | Rutina | Línea |
|---|---|---|
| 39A8h | [`ai_stay`](../../../src/c64/juego_final/estado_texto.s#L204) | 204 |
| 39AEh | [`ai_guillermo_is_close`](../../../src/c64/juego_final/estado_texto.s#L211) | 211 |
| 39E5h | [`ai_next_state_on_arrival`](../../../src/c64/juego_final/estado_texto.s#L250) | 250 |
| 39F1h | [`obj_set_door_permissions`](../../../src/c64/juego_final/estado_texto.s#L275) | 275 |
| 3A37h | [`ai_hour_update`](../../../src/c64/juego_final/estado_texto.s#L376) | 376 |
| 3A58h | [`ai_say_phrase_param`](../../../src/c64/juego_final/estado_texto.s#L398) | 398 |
| 2FADh | [`obj_open_left_wing_doors`](../../../src/c64/juego_final/estado_texto.s#L410) | 410 |
| 30FDh | [`spr_tile_ptr_check`](../../../src/c64/juego_final/estado_texto.s#L424) | 424 |
| 310Eh | [`game_snapshot_initial_state`](../../../src/c64/juego_final/estado_texto.s#L444) | 444 |
| 3111h | [`game_for_each_state_block`](../../../src/c64/juego_final/estado_texto.s#L451) | 451 |
| 3166h | [`game_state_block_save`](../../../src/c64/juego_final/estado_texto.s#L483) | 483 |
| 3176h | [`game_init_new_game`](../../../src/c64/juego_final/estado_texto.s#L513) | 513 |
| 304Fh | [`spr_unflip_monk_faces`](../../../src/c64/juego_final/estado_texto.s#L565) | 565 |
| 3087h | [`obj_fix_owner_pointers`](../../../src/c64/juego_final/estado_texto.s#L602) | 602 |
| 2FB9h | [`sys_check_pause_save_load`](../../../src/c64/juego_final/estado_texto.s#L671) | 671 |
| 3456h | [`chr_hbuf_fill_room`](../../../src/c64/juego_final/estado_texto.s#L755) | 755 |
| — | [`hb_list`](../../../src/c64/juego_final/estado_texto.s#L768) | 768 |
| — | [`hb_draw`](../../../src/c64/juego_final/estado_texto.s#L945) | 945 |
| 3786h | [`util_clip_span`](../../../src/c64/juego_final/estado_texto.s#L1122) | 1122 |
| 35F8h | [`chr_hbuf_skip_list`](../../../src/c64/juego_final/estado_texto.s#L1169) | 1169 |
| 3568h | [`sys_startup_init`](../../../src/c64/juego_final/estado_texto.s#L1189) | 1189 |
| 35C3h | [`game_init_mirror`](../../../src/c64/juego_final/estado_texto.s#L1201) | 1201 |
| 3607h | [`vid_init_stub`](../../../src/c64/juego_final/estado_texto.s#L1250) | 1250 |
| 3A83h | [`vid_palette_black`](../../../src/c64/juego_final/estado_texto.s#L1331) | 1331 |
