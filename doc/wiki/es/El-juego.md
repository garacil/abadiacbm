<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/El-juego.md: se edita la plantilla, no esta página. -->
# El juego

[Inicio](Inicio.md) · siguiente: [Del Z80 al 6502](Del-Z80-al-6502.md)

En esta página cuento qué tiene que hacer el programa: las reglas de *La abadía del crimen* tal como las implementa el
código.  Las páginas siguientes explican cómo lo hace.

## La historia en un párrafo

En 1327 fray Guillermo de Occam y su novicio Adso de Melk llegan a una abadía benedictina del norte de Italia.  Ha
muerto un monje, Venancio; el abad le pide a Guillermo que encuentre al culpable antes de que llegue el inquisidor
Bernardo Gui, y le ordena cumplir la regla de la abadía: estar en los oficios de la iglesia y en la comida del
refectorio, y estar en su celda por la noche.  Durante los siete días mueren más monjes.  El secreto es un libro
prohibido escondido en el *finis Africae* de la biblioteca, un laberinto en el piso alto del edificio, y el venerable
Jorge, ciego, que lo guarda.

## Los personajes

El juego tiene seis registros de personaje; dos de ellos los reutilizan otros personajes según avanza la historia.

| Registro | Personaje | Quién lo mueve |
|---|---|---|
| 0 | **Guillermo** | el jugador: girar a la izquierda, girar a la derecha, avanzar |
| 1 | **Adso**, su novicio | su propio guion: sigue a Guillermo, y el jugador lo adelanta con *abajo* |
| 2 | **Malaquías**, el bibliotecario | su guion |
| 3 | **el Abad** | su guion |
| 4 | **Berengario**, el ayudante del bibliotecario; desde el día 3 el monje encapuchado, y después **Bernardo Gui** | su guion |
| 5 | **Severino**, el herbolario; desde el día 6 **Jorge** | su guion |

En el C64 las teclas son las del juego del CPC puestas sobre el teclado del C64 (`src/c64/plataforma/teclado.s`): Q
(SHIFT + CRSR abajo, joystick arriba) avanza, O y P (SHIFT + CRSR derecha y CRSR derecha, joystick izquierda y
derecha) giran, A (CRSR abajo, el botón de disparo) adelanta a Adso, ESPACIO (joystick abajo) deja un objeto,
INST/DEL hace una pausa y CTRL + ← abre el menú que graba o carga la partida.

## El tiempo: siete días de siete horas

El juego cuenta **días** (del 1 al 7) y las **horas** canónicas del día monástico:

| Hora | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|---|
| en el marcador | NOCHE | PRIMA | TERCIA | SEXTA | NONA | VÍSPERAS | COMPLETAS |

Una partida nueva empieza el día I a **nona**: lo leen de los datos `GAME_START_DAY` y `GAME_START_HOUR` la rutina
`ai_clock_init`, que pone el reloj en marcha.  Una hora termina de una de dos formas:

* por **tiempo**: algunas horas tienen una duración, contada en fotogramas (ver [El reloj](Reloj.md)); cuando se
  acaba, la hora avanza haga lo que haga Guillermo;
* por la **historia**: la mayoría de las horas terminan cuando lo decide un guion, por ejemplo cuando todos los monjes
  han llegado a la iglesia y el abad ha dicho *OREMOS*, o cuando Guillermo contesta a la pregunta de Adso *¿DORMIMOS?,
  MAESTRO* por la noche.

Cada hora tiene sus obligaciones.  En **prima** y **vísperas** los monjes se reúnen en la iglesia; en **sexta**, en el
refectorio; en **completas** el abad manda a todos a sus celdas; de **noche** Guillermo debería dormir… o explorar los
sitios prohibidos mientras la abadía duerme.  El abad comprueba que Guillermo está en su sitio exacto, mirando al altar
o a la mesa: si llega tarde o está en otro lugar, le reprende.

## El obsequium

La barra de la derecha del marcador es el *obsequium* (la obediencia) de Guillermo: 31 puntos al empezar, de 0 a 1Fh.
Cada reprimenda del abad (o de Bernardo Gui) quita 2; si fuera a bajar de 0, el abad pasa a su estado 0Bh, viene a por
Guillermo y lo expulsa de la abadía: el fin de la partida.  Es la única rutina que lo cambia:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L1697-L1727), líneas 1697–1727:

```asm
; 5129 hud_obsequium_sub: `JSR hud_obsequium_sub / .byte n`: hud_obsequium -= n; below 0 it becomes 0 and, unless
; the game is over, ai_abbot_state := 0Bh (the abbot expels Guillermo); the bar (CDB4h): obsequium / 4 bytes
; 0Fh, one byte FFh >> (obsequium & 3) (the CPC's tail table 5180h), the rest of the 8 bytes FFh.
hud_obsequium_sub:
        pla                             ; the inline byte, and the return past it
        clc
        adc     #1
        sta     zp0
        pla
        adc     #0
        sta     zp0+1
        pha
        lda     zp0
        pha
        ldy     #0
        lda     D64_HUD_OBSEQUIUM
        sec
        sbc     (zp0),y
        bcs     :+
        lda     D64_GAME_GUILLERMO_DEAD
        bne     @cero
        lda     #$0B
        sta     D64_AI_ABBOT_STATE
@cero:  lda     #0
:       sta     D64_HUD_OBSEQUIUM
        and     #$03
        tax
        lda     #$FF
        cpx     #0
        beq     @cola
:       lsr     a
```

Quien la llama escribe la cantidad como un byte a continuación del `JSR` (`JSR hud_obsequium_sub / .byte 2`), igual
que el programa del Z80 lo hacía detrás de su `CALL`: la rutina saca de la pila su dirección de vuelta, lee ese byte y
vuelve a meter la dirección que queda detrás de él.  Luego dibuja la barra: el valor dividido entre cuatro da los bytes
llenos (cuatro puntos cada uno) y sus dos bits bajos, el trozo del último byte.  Al empezar cada partida el bucle
principal la llama con 0 solo para dibujar la barra.

## Los objetos

Hay nueve objetos: el **libro**, los **guantes**, las **gafas** (las lentes de Guillermo), el **pergamino** (el
manuscrito de Venancio), la **llave 1**, la **llave 2**, la **llave 3**, un hueco sin usar y la **lámpara**.  Cada
personaje que puede llevar objetos tiene una entrada de *portador* con la máscara de lo que puede coger; un objeto se
coge al pasar por encima y se deja con ESPACIO.  Guillermo empieza con las gafas; Adso solo puede coger la lámpara y
la llave 3.  Al leer el pergamino con las gafas aparece el enigma en latín del espejo, con un número elegido al azar
para cada partida (ver [Objetos, puertas y el espejo](Objetos.md)).  La lámpara hace falta en la biblioteca, que está
a oscuras: sin ella Adso no quiere seguir, y si se agota se pierden.

## Cómo termina la partida

Todos los finales ponen la misma marca, `GAME_GUILLERMO_DEAD`; el bucle principal espera entonces a que termine la
frase del marcador y muestra el resultado:

* expulsado por el abad (el obsequium agotado, la desobediencia, entrar en su celda, la biblioteca a deshora);
* perdido en la biblioteca a oscuras, o la lámpara agotada;
* se acaba el tiempo: el día VII a tercia el abad despide a Guillermo;
* envenenado: Guillermo pasa las páginas del libro sin los guantes;
* **resuelto**: Jorge se come el libro en el finis Africae.

[`src/c64/juego_final/principal.s`](../../../src/c64/juego_final/principal.s#L224-L240), líneas 224–240:

```asm
; ---- 3E29 game_check_end: the end of a game ---------------------------------------------------------------------
; Nothing unless Guillermo is dead (37E4h) and no phrase is being shown; then the play area filled, the
; percentage computed and printed; at 100 % the ending (3EC6), else "PULSA ESPACIO PARA EMPEZAR", the wait
; for space and a new game (3EC2 POP HL / JP 20C7: the JSR's return address dropped).
.proc game_check_end
        lda     D64_GAME_GUILLERMO_DEAD         ; 3E29-3E2D
        bne     :+
        rts
:       lda     #$80                            ; 3E2E-3E30
        sta     D64_GAME_CAMERA_OTHER
        lda     D64_TXT_PHRASE_BUSY             ; 3E33-3E37
        beq     :+
        rts
:       jsr     vid_fill_play_area_ff           ; 3E38 CALL 16A1
        jsr     game_compute_percentage         ; 3E3B CALL 3DA8 (the digits into D64_GAME_PERCENT_DIGITS)
        lda     D64_GAME_PERCENT_DIGITS         ; the digits into this code's own copy of the text (3E61)
        sta     digitos
```

## El porcentaje de la investigación

El porcentaje se calcula con el día, la hora y los bits de *bonificación*: un bit por cada descubrimiento que el juego
premia (tener los guantes, las llaves, llegar a ciertas salas…), 4 por ciento cada uno.  La cuenta es
7·(día − 1) + hora + 4 por cada bit de la palabra `game_bonus2`; por debajo de 5 se muestra 0, y si la investigación
está resuelta (`game_investigation_open` a 0) sale directamente «100»:

[`src/c64/juego_final/logica_a.s`](../../../src/c64/juego_final/logica_a.s#L831-L895), líneas 831–895:

```asm
; 3DA8 game_compute_percentage: "100" when the investigation is solved; else 7 (day - 1) + hour + 4 per bit of
; the word game_bonus2 (8-bit sum), 0 below 5; its digits go to game_percent_digits (' ', tens, units).
; Out: A = 20h (31h when solved), BC = units << 8 | tens (0), HL = 3030h + BC.
.proc game_compute_percentage
        lda     D64_GAME_INVESTIGATION_OPEN
        bne     calc
        sta     zbc
        sta     zbc+1
        lda     #$31
        bne     guarda                          ; (always)
calc:   lda     D64_GAME_DAY
        sec
        sbc     #1
        sta     zt0
        asl
        sta     zt0+1
        asl
        clc
        adc     zt0
        clc
        adc     zt0+1
        clc
        adc     D64_GAME_HOUR
        sta     zt0
        ldx     #1                      ; + 4 per bit of the word game_bonus2 (8 bits)
palabra:
        ldy     D64_GAME_BONUS2,x
unbit:  tya
        beq     :+
        asl
        tay
        bcc     unbit
        lda     zt0
        adc     #4 - 1                  ; (C set)
        sta     zt0
        jmp     unbit
:       dex
        bpl     palabra
        lda     zt0
        cmp     #5
        bcs     :+
        lda     #0
:       ldx     #0
:       cmp     #10
        bcc     :+
        sbc     #10
        inx
        bne     :-
:       sta     zbc+1                           ; B = units
        stx     zbc                             ; C = tens
        lda     #$20
guarda: sta     D64_GAME_PERCENT_DIGITS
        tax
        lda     zbc
        clc
        adc     #$30
        sta     zhl
        sta     D64_GAME_PERCENT_DIGITS+1
        lda     zbc+1
        adc     #$30
        sta     zhl+1
        sta     D64_GAME_PERCENT_DIGITS+2
        txa
        rts
.endproc
```

El 7·(día − 1) no se multiplica: se hace con dos desplazamientos y dos sumas (2x, 4x y 4x + x + 2x).  Con el 100 % (la
investigación resuelta) se carga de la cinta o del disco el pergamino final ([Presentación y final](Pergaminos.md));
cualquier otro resultado muestra *HAS RESUELTO EL nn POR CIENTO DE LA INVESTIGACIÓN* y espera a que se pulse ESPACIO
para empezar otra vez.

## Los tres juegos de Commodore

| | abadia64ks (C64) | abadia128ks (C128 y P500) |
|---|---|---|
| lógica | la versión de cinta de 64 KiB del CPC, traducida rutina a rutina | el mismo código 6502 más, con `-D COMPLETO`, todas las diferencias del juego completo (CPC 6128 / PC) |
| mapa | 129 salas; siete vaciadas por la versión de 64 KiB del CPC (17h, 27h, 32h, 33h, 35h, 36h, 4Bh) | el mapa completo |
| comienzo | Guillermo en el claustro (x 88h, y 9Ch) | en la entrada (x 88h, y A8h), como en el juego completo |
| tercia del día VII | dura C3h × 256 fotogramas (un byte que `game_main` escribe en la tabla de duraciones) | solo termina por la historia, como en el PC |
| cabezas | los gráficos multicolor del CPC | alta resolución: una máscara negra de sprites del VIC-II sobre cada cabeza |
| extras | menú de inicio: idioma, pasos, sonido del texto | el mismo menú y el Ave María en completas; en el C128, 2 MHz en los bordes |

Encontré las diferencias del juego completo comparando el programa de 64 KiB con las funciones y los datos de la
versión de PC (`data/completo/PLAN.md`), y certifiqué el juego del C128 contra mi reconstrucción del PC fotograma a
fotograma.
