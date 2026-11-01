<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Bucle-principal.md: se edita la plantilla, no esta página. -->
<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# Arranque y bucle principal

[Inicio](Inicio.md) · anterior: [Mapa de memoria](Mapa-de-memoria.md) · siguiente: [El reloj y las ceremonias](Reloj.md)

El juego es un único bucle que nunca vuelve, marcado por una interrupción de 300 Hz.  En esta página sigo el programa
desde el salto del cargador hasta el último paso de cada fotograma.

## La entrada

El cargador (de la cinta o del disco) salta a `principal_inicio` con la imagen del juego ya en memoria.  Primero
preparo la máquina (la capa de plataforma: el VIC-II, el temporizador de la CIA, el SID; en el C128 también las
cabezas en alta resolución) y después el juego empieza exactamente donde saltaba el cargador de la cinta del CPC,
`game_main` en 20BEh:

[`src/c64/juego_final/principal.s`](../../../src/c64/juego_final/principal.s#L77-L86), líneas 77–86:

```asm
.proc principal_inicio
        sei
        ldx     #$FF
        txs
        jsr     plat_inicio
.ifdef C128
        jsr     cab_inicio              ; the C128: the heads' hardware sprites (cabezas128.s)
.endif
        jmp     game_main
.endproc
```

## Una partida nueva

`game_main` hace la preparación de una sola vez (`sys_startup_init`, que también reconstruye las tablas de mezcla
del C64; la marca `SYS_STARTUP_DONE` vale 0Dh cuando ya está hecha) y después cada partida nueva, paso a paso:

1. silencia los tres canales (`snd_silence_all`) y espera a que se suelte ESPACIO;
2. pone cada registro en su estado inicial (`game_init_new_game`) y borra el área de juego;
3. pone el tempo del sonido (6) y, en el juego de 64 KiB, escribe C3h en la tabla de duraciones: la tercia del día
   VII dura C3h × 256 fotogramas (en el juego completo ese byte no se escribe y la hora solo acaba por la historia);
4. carga el presupuesto del fotograma (`SYS_FRAME_TICKS`);
5. coloca a Guillermo en la casilla de salida y a Adso a su lado, en x − 2, y + 2, a la misma altura;
6. prepara el espejo (`obj_init_mirror`) y pone el reloj en el día I, nona (`ai_clock_init`);
7. da a los cinco búferes de órdenes de los monjes (de 2Dh bytes cada uno) la orden vacía 10h, y pone a 0 los ticks.

`reanuda` es también donde sigue una partida cargada: olvida la sala que se estaba mostrando (para que se vuelva a
dibujar), borra el área de juego, cierra el espejo, dibuja los objetos de Guillermo, el reloj y la barra del obsequium
y habilita las interrupciones:

[`src/c64/juego_final/principal.s`](../../../src/c64/juego_final/principal.s#L89-L147), líneas 89–147:

```asm
.proc game_main
        jsr     plat_di                         ; 20BE
        lda     D64_SYS_STARTUP_DONE            ; 20BF-20C4: the start-up once
        cmp     #$0D
        beq     nueva
        jsr     sys_startup_init
nueva:                                          ; 20C7: a new game
::cert_nueva:
        jsr     plat_di
        jsr     snd_silence_all                 ; 20D2
        jsr     sys_read_keyboard               ; 20D5
        lda     #ESPACIO                        ; 20D8-20DD: while space is held
        jsr     sys_key_down
        beq     :+
.ifdef PRUEBA
        jsr     plat_pausa
.endif
::cert_pausa1:                                  ; (C64: a pass of the wait 20C7, for c64/certifica: the host's plat_pausa)
        jmp     nueva
:       jsr     game_init_new_game              ; 20DF
        jsr     vid_clear_play_area             ; 20E2
        lda     #6                              ; 20E5-20E7: the sound tempo
        sta     D64_SND_TEMPO_RELOAD
.ifndef COMPLETO
        lda     #$C3                            ; 20EA-20F5: of the four JPs only 4AFCh is data (in the
        sta     D64_VEC_4AFC                    ; hour durations' block)
.endif                                          ; (abadia128ks, the full game: no JP there, day 7's tercia
                                                ; lasts 0 as on the PC; the 64 KiB game: C3h x 256 frames)
        lda     D64_SYS_FRAME_TICKS_NORMAL      ; 210A-210D: the frame budget
        sta     D64_SYS_FRAME_TICKS
        lda     D64_GAME_START_POS              ; 2110-2113: Guillermo's x, y
        sta     D64_CHR_GUILLERMO_XY
        sec                                     ; 2116-211A: Adso at x - 2, y + 2
        sbc     #2
        sta     D64_CHR_ADSO_XY
        lda     D64_GAME_START_POS+1
        sta     D64_CHR_GUILLERMO_XY+1
        clc
        adc     #2
        sta     D64_CHR_ADSO_XY+1
        lda     D64_GAME_START_Z                ; 211D-2123: the same height
        sta     D64_CHR_GUILLERMO_Z
        sta     D64_CHR_ADSO_Z
        jsr     obj_init_mirror                 ; 2139
        jsr     ai_clock_init                   ; 213C
        lda     #$10                            ; 213F-214B: command 10h in the 5 command buffers
        ldx     #0
:       sta     D64_CHR_CMD_BUFFER_HEADS,x
        pha
        txa
        clc
        adc     #$2D
        tax
        pla
        cpx     #5 * $2D
        bne     :-
        lda     #0                              ; 214D-214E: ticks := 0
        sta     D64_SYS_TICKS
reanuda:                                        ; 2151: also after a game is loaded
```

## El fotograma

Cada vuelta de `bucle` es un fotograma del juego.  Los comentarios dan la dirección del Z80 de cada paso: el orden es
el del original, paso a paso.

[`src/c64/juego_final/principal.s`](../../../src/c64/juego_final/principal.s#L164-L220), líneas 164–220:

```asm
bucle:                                          ; 2179: the main loop, a frame
::cert_frame:                                   ; (the host's plat_frame point, for c64/certifica)
.ifdef PRUEBA
        jsr     plat_frame
.endif
        lda     D64_CHR_GUILLERMO               ; 217A-217D
        sta     D64_CHR_GUILLERMO_ANIM_COPY
        jsr     game_input_and_mirror           ; 2180
        jsr     sys_check_pause_save_load       ; 2183
        jsr     menu_disco                      ; 2186: the CTRL+TAB menu
        bcs     reanuda                         ; a game loaded: 2151
        lda     #7                              ; 2189-218E: key 7 (its CALL NZ,3557 is a lone RET)
        jsr     sys_key_down
        jsr     ai_timers_tick                  ; 2191
        jsr     game_check_end                  ; 2197 (a new game: it jumps to `nueva` itself)
        jsr     game_update_bonus_and_poison    ; 219A
        jsr     hud_scroll_hour_name            ; 219D
        jsr     ai_hour_update                  ; 21A0
        jsr     game_camera_update              ; 21A3
        jsr     iso_update_camera_room          ; 21A6
        lda     D64_ISO_ROOM_CHANGED            ; 21A9-21AD
        beq     :+
        jsr     iso_draw_room                   ; 21AF
        lda     #$80                            ; 21B2
:       sta     D64_OBJ_ROOM_REDRAW             ; 21B4
        jsr     obj_update_inventory            ; 21B7
        jsr     obj_update_doors                ; 21BA
        lda     #<D64_CHR_TABLE                 ; 21BD-21C0: Guillermo's entry of chr_table
        sta     zhl
        lda     #>D64_CHR_TABLE
        sta     zhl+1
        jsr     chr_update
        jsr     game_run_npc_behaviours         ; 21C3
        lda     #0                              ; 21C6-21CA
        sta     D64_ISO_ROOM_CHANGED
        sta     D64_CHR_PATH_FOUND_NOW
        jsr     spr_place_light                 ; 21CD
        jsr     obj_door_flip_graphics          ; 21D0
        jsr     iso_mirror_update               ; 21D3
espera: lda     D64_SYS_TICKS                   ; 21D6-21DB: the frame's ticks
        cmp     D64_SYS_FRAME_TICKS
        bcs     :+
.ifdef PRUEBA
        jsr     plat_espera
.endif
::cert_espera:                                  ; (a pass of the wait 21D6: the host's plat_espera, for c64/certifica)
        jmp     espera
:       lda     D64_CHR_GUILLERMO               ; 21DD-21E2: a footstep when mid-step
        and     #1
        beq     :+
        jsr     snd_play_footstep               ; (the footsteps off: the footstep's note a rest, cinta_paso)
:       lda     #0                              ; 21E5-21E6
        sta     D64_SYS_TICKS
        jsr     spr_draw_or_darken              ; 21E9
        lda     #ESC                            ; 21EC-21EE (then 3D05 is always Z: JP Z,2179)
        jsr     sys_key_down
        jmp     bucle
```

Dicho con palabras:

1. **La entrada**: se lee el teclado y se prueba la combinación de dos teclas del espejo (`game_input_and_mirror`);
   INST/DEL hace una pausa; CTRL + ← abre el menú de grabar y cargar (`menu_disco`; si se carga una partida, el bucle
   vuelve a `reanuda`).
2. **El tiempo**: el contador de fotogramas de la hora, la lámpara y el final de la noche (`ai_timers_tick`, ver
   [El reloj](Reloj.md)).
3. **El final**: si Guillermo ha muerto o la investigación está resuelta, se enseña el resultado (`game_check_end`).
4. **La bonificación y el veneno**: los bits de bonificación de la investigación y el contador del veneno del libro.
5. **El marcador**: el nombre de la hora entra desplazándose; un cambio de hora pendiente se hace cuando no hay
   ninguna frase sonando (`ai_hour_update`).
6. **La cámara**: a qué personaje sigue la pantalla (a Guillermo, o al monje que la historia quiere enseñar cuando
   Guillermo está quieto) y en qué sala está; al cambiar de sala, la sala se construye y se dibuja (`iso_draw_room`).
7. **Objetos y puertas**: coger y dejar objetos, las puertas que se abren y se cierran.
8. **Los personajes**: Guillermo se mueve con las teclas (`chr_update` sobre su entrada de la tabla de personajes) y
   después cada uno de los demás ejecuta su comportamiento y su siguiente orden de movimiento
   (`game_run_npc_behaviours`).
9. **La luz**: en una sala oscura, la luz de la lámpara sigue a Adso (`spr_place_light`); luego las puertas cambian su
   gráfico y el espejo se actualiza.
10. **La espera**: el fotograma no termina antes de que pase su presupuesto de ticks de la interrupción.
11. **El paso**, cuando Guillermo está entre dos pasos, y **los sprites**: cada sprite que ha cambiado se compone y se
    copia a la pantalla (`spr_draw_or_darken`).

## La interrupción de 300 Hz

El gate array del CPC interrumpe al Z80 cada 52 líneas de barrido: 300,48 veces por segundo.  En el C64 el temporizador
A de la CIA 1 interrumpe cada 3279 ciclos, al mismo ritmo, y su rutina hace lo mismo que hacía la del CPC
(`sys_tick`, 2899h): cuenta el tick, ejecuta el secuenciador de sonido cuando suena algún canal y, cada 45 ticks, mueve
un paso la frase del marcador:

[`src/c64/plataforma/interrupcion.s`](../../../src/c64/plataforma/interrupcion.s#L131-L167), líneas 131–167:

```asm
; the game's build (-D JUEGO; the speed work's round 5, brought back: the
; interrupt routines in their most optimised form): the game's sys_tick (2899h) inline: CIA 1 acknowledged,
; the tick counter [289C] + 1 kept at FFh, the sound (0CD0) and the phrase scroller (368A).  The sound's test is the
; opcode at plat_irq_sonido: JSR s_interrupcion while a channel plays (state bit 0), BIT abs (no call) else, written
; by objetos_sonido.s where a state's bit 0 changes (s_pon, a sequence's end, snd_silence_all).  The memory
; configuration kept and the I/O in (the C64: $01's bit 0 set, $34 -> $35, $35 stays; the C128: MEM_IO).  No CLD on
; the C64 (nothing in the game sets the decimal mode: no SED in its sources); the C128 keeps it (its KERNAL runs
; between games' frames).  Measured then: an empty tick 96 -> 69 cycles; the outputs, the SID's writes, identical.
.proc plat_irq
        pha
        lda     MEMCFG
        pha
.ifdef C128
        lda     #MEM_IO
        sta     MEMCFG
        cld
.else
        ora     #$01
        sta     MEMCFG
.endif
        lda     CIA1_ICR                ; acknowledged
        inc     D64_SYS_TICKS           ; 2899h: the tick counter, kept at FFh
        bne     :+
        dec     D64_SYS_TICKS
:
::plat_irq_sonido:
        bit     s_interrupcion          ; 0CD0: JSR ($20) while a channel plays (objetos_sonido.s), BIT ($2C) else
        inc     D64_TXT_SCROLL_TIMER    ; 368A's test: the scroller's 2Dh-th tick
        lda     D64_TXT_SCROLL_TIMER
        cmp     #$2D
        bne     :+
        jsr     t_frase                 ; (X and Y kept)
:       pla
        sta     MEMCFG
        pla
        rti
.endproc
```

Dos detalles de la versión 6502: la llamada al sonido es una instrucción que se reescribe sobre la marcha (`JSR`
mientras suena un canal, `BIT` cuando no suena ninguno: el caso más frecuente no cuesta ninguna llamada), y la rutina
pone visible la E/S por su cuenta, porque el juego puede estar leyendo los gráficos de debajo de la E/S cuando llega el
tick.  Un tick vacío cuesta 69 ciclos.

## La velocidad del juego

El presupuesto del fotograma, `SYS_FRAME_TICKS`, es de 36 ticks (120 ms) mientras se juega.  Cuando no se pulsa
ninguna tecla de movimiento durante 50 fotogramas el presupuesto pasa a 0 (el juego va tan rápido como dé la máquina,
salvo mientras se enseña una frase) y la cámara puede ir al personaje que la historia quiere enseñar:

[`src/c64/juego_final/logica_a.s`](../../../src/c64/juego_final/logica_a.s#L664-L695), líneas 664–695:

```asm
; 3CC5 game_camera_select: game_update_camera_and_bonus; a movement key puts the camera on Guillermo; else the
; idle frames count to 32h and then: the speed (normal while a phrase is shown, else no delay), the music, and
; the camera goes to ai_camera_target when it changed.
.proc game_camera_select
        jsr     game_update_camera_and_bonus
        jsr     ai_jorge_book_talk_with_gloves
        jsr     game_idle_camera_check
        beq     quieto
        lda     #0
        beq     camara                          ; (always)
quieto: inc     D64_GAME_IDLE_FRAMES
        lda     D64_GAME_IDLE_FRAMES
        cmp     #$32
        bcs     :+
        rts
:       dec     D64_GAME_IDLE_FRAMES
        lda     D64_TXT_PHRASE_BUSY
        beq     :+
        jsr     game_speed_default
        jmp     musica
:       jsr     game_speed_set                  ; A = 0: no delay
musica: jsr     snd_play_music_if_idle
        lda     D64_AI_CAMERA_TARGET
        cmp     D64_GAME_CAMERA_OTHER
        bne     camara
        rts
camara: sta     D64_GAME_CAMERA_OTHER           ; 3CF6
        sta     D64_GAME_IDLE_FRAMES
        tax
        beq     game_speed_default              ; Guillermo: the normal speed
        rts
.endproc
```

Así que la velocidad del original depende de cuánto dibuja cada fotograma.  El juego del CPC va muchas veces más
lento que su presupuesto; hice el juego del C64 más rápido que el del CPC (medido en VICE, sin teclas desde el
principio: los fotogramas 1-2000 en 122,5 s en el C64 frente a 294,2 s en un CPC 6128, ver `doc/ESTADO.md`), y el
C128 va a 2 MHz mientras el haz está en los bordes.
