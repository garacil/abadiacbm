<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Reloj.md: se edita la plantilla, no esta página. -->
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

# El reloj y las ceremonias

[Inicio](Inicio.md) · anterior: [Arranque y bucle principal](Bucle-principal.md) · siguiente: [Las salas y el motor isométrico](Motor-isometrico.md)

## El día y la hora

Dos bytes guardan el tiempo: `GAME_DAY` (de 1 a 7) y `GAME_HOUR` (0 noche, 1 prima, 2 tercia, 3 sexta, 4 nona, 5
vísperas, 6 completas).  Una partida nueva los copia de dos bytes de datos (día 1, hora 4: nona):

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L1479-L1485), líneas 1479–1485:

```asm
; 5028 ai_clock_init: a new game: game_day := [BF4Fh], game_hour := [BF4Eh].  Out: A = the hour.
ai_clock_init:
        lda     D64_GAME_START_DAY
        sta     D64_GAME_DAY
        lda     D64_GAME_START_HOUR
        sta     D64_GAME_HOUR
        rts
```

## Cuánto dura una hora

Una tabla de siete bytes por día da la duración de cada hora en unidades de 256 fotogramas; un 0 significa que la hora
no tiene límite de tiempo y solo la puede terminar la historia.  Estos son los valores del juego de 64 KiB del CPC (la
tabla de 4AD0h), que he comprobado en la imagen del C64:

| día | noche | prima | tercia | sexta | nona | vísperas | completas |
|---|---|---|---|---|---|---|---|
| I | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| II | 0 | 0 | 5 | 0 | 5 | 0 | 0 |
| III | 0 | 0 | 5 | 0 | 5 | 0 | 0 |
| IV | 0Fh | 0 | 0 | 0 | 5 | 0 | 0 |
| V | 0Fh | 0 | 5 | 0 | 0 | 0 | 0 |
| VI | 0Fh | 0 | 5 | 0 | 5 | 0 | 0 |
| VII | 0Fh | 0 | 0 (C3h en el juego de 64 KiB) | 0 | 2 | 0 | 0 |

La tercia del día VII es una curiosidad de la versión de 64 KiB: en cada partida nueva `game_main` escribe el byte C3h
(el código de operación `JP`, parte de la preparación de la interrupción del Z80) en 4AFCh, que cae dentro de esta
tabla, así que esa hora dura C3h × 256 fotogramas.  El juego completo del C128 y del P500 no lo escribe, como la
versión de PC.  Las cuatro últimas entradas del día VII quedan fuera de los 45 bytes de la tabla: son los primeros
bytes de la tabla siguiente (los números romanos de los días), sin consecuencias porque el juego acaba en la tercia
del día VII.

Cuando empieza la hora, su duración se carga en un contador de 16 bits, `AI_HOUR_FRAMES_LEFT`:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L1519-L1543), líneas 1519–1543:

```asm
; 5060 ai_clock_load_duration: ai_hour_frames_left := ai_hour_durations[7 (day - 1) + hour] << 8.  Out: HL.
ai_clock_load_duration:
        lda     D64_GAME_DAY
        sec
        sbc     #1
        sta     zt0
        asl     a
        asl     a
        asl     a
        sec
        sbc     zt0                     ; 7 (day - 1), 8-bit
        clc
        adc     #<D64_AI_HOUR_DURATIONS
        sta     zp0
        lda     #>D64_AI_HOUR_DURATIONS
        adc     #0
        sta     zp0+1
        ldy     D64_GAME_HOUR
        lda     (zp0),y
        sta     zhl+1
        sta     D64_AI_HOUR_FRAMES_LEFT+1
        lda     #0
        sta     zhl
        sta     D64_AI_HOUR_FRAMES_LEFT
        rts
```

Cada fotograma el contador baja; cuando llega a 0, la hora avanza.  Después de completas avanza el día, su número
romano se vuelve a dibujar en el marcador y el nombre de la hora nueva entra desplazándose (`HUD_HOUR_SCROLL_STEPS` =
9 pasos):

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L1545-L1619), líneas 1545–1619:

```asm
; 507D ai_clock_tick: once a frame: sys_key_pressed(6) and util_return_zero (the CPC's skip-the-hour test,
; always Z), then ai_hour_frames_left counts down when not 0; at 0 the hour advances.
ai_clock_tick:
        lda     #6
        jsr     sys_key_pressed
        jsr     util_return_zero
        bne     ai_clock_advance_hour
        lda     D64_AI_HOUR_FRAMES_LEFT
        ora     D64_AI_HOUR_FRAMES_LEFT+1
        bne     :+
        rts
:       lda     D64_AI_HOUR_FRAMES_LEFT
        bne     :+
        dec     D64_AI_HOUR_FRAMES_LEFT+1
:       dec     D64_AI_HOUR_FRAMES_LEFT
        lda     D64_AI_HOUR_FRAMES_LEFT
        ora     D64_AI_HOUR_FRAMES_LEFT+1
        beq     ai_clock_advance_hour
        rts

; 5094 ai_clock_advance_hour: hour + 1, the scroll of its name (9 steps) and its duration; after completas:
; the first name, day + 1 (8 -> 1) and hud_set_and_draw_day.
ai_clock_advance_hour:
        lda     D64_GAME_HOUR
        clc
        adc     #1
        cmp     #7
        bne     lb_hora
        lda     #<D64_HUD_HOUR_NAMES
        sta     D64_HUD_HOUR_NAME_PTR
        lda     #>D64_HUD_HOUR_NAMES
        sta     D64_HUD_HOUR_NAME_PTR+1
        lda     D64_GAME_DAY
        clc
        adc     #1
        sta     D64_GAME_DAY
        cmp     #8
        bcc     lb_dia
        lda     #1
; 50AF hud_set_and_draw_day: game_day := A and its three numeral glyphs (hud_roman_days + 3 (day - 1)) at
; ED09h; game_hour := 0, the scroll (9) and the duration.
hud_set_and_draw_day:
        sta     D64_GAME_DAY
lb_dia: sec
        sbc     #1
        sta     zt0
        asl     a
        clc
        adc     zt0
        clc
        adc     #<D64_HUD_ROMAN_DAYS
        sta     zde
        lda     #>D64_HUD_ROMAN_DAYS
        adc     #0
        sta     zde+1
        lda     #<$ED09
        sta     zhl
        lda     #>$ED09
        sta     zhl+1
        jsr     hud_draw_day_numeral
        jsr     hud_draw_day_numeral
        jsr     hud_draw_day_numeral
        lda     #0
lb_hora:
        sta     D64_GAME_HOUR
.ifdef C128
        cmp     #6                      ; the C128: completas, the PC version's Ave Maria (its 5AAF-5AB3;
        bne     :+                      ; plataforma/c128.s c128_ave; 3 NOPs when the menu's option 4 is off)
::c128_ave_llamada:
        jsr     c128_ave
:
.endif
        lda     #9
        sta     D64_HUD_HOUR_SCROLL_STEPS
        jmp     ai_clock_load_duration
```

La llamada `sys_key_pressed(6)` seguida de `util_return_zero` es el rastro de una tecla de los programadores que
saltaba a la hora siguiente: el original la desactivó haciendo que la prueba siempre fuera falsa, y en la traducción la
dejé tal cual.  En el C128 y en el P500, a completas, el cambio de hora toca además el Ave María de la versión de PC
(`c128_ave`, ver [El Commodore 128](Commodore-128.md)).

## Las horas que acaba la historia

La mayoría de las horas no tienen límite de tiempo: un guion pone `AI_ADVANCE_HOUR` (por ejemplo el abad, cuando todos
los monjes están en la iglesia y ha dicho *OREMOS*; o Adso, cuando Guillermo contesta que sí a *¿DORMIMOS?, MAESTRO*).
Entonces la hora avanza en cuanto no se está enseñando ninguna frase (así siempre se oye la última frase de una escena)
y nunca mientras el personaje al que sigue la cámara está entre dos pasos:

[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L373-L394), líneas 373–394:

```asm
; 3A37 ai_hour_update: txt_phrase_busy := txt_phrase_active; nothing more while the camera character is
; between two steps; when ai_advance_hour is set and no phrase is shown, it is cleared and the hour advances;
; then the hour-change actions (tail call).
ai_hour_update:
        lda     D64_TXT_PHRASE_ACTIVE
        sta     D64_TXT_PHRASE_BUSY
        lda     D64_CHR_CAMERA_TARGET
        sta     zhl
        lda     D64_CHR_CAMERA_TARGET+1
        sta     zhl+1
        ldy     #0
        lda     (zhl),y
        and     #1
        bne     @r
        lda     D64_AI_ADVANCE_HOUR
        beq     @ev
        lda     D64_TXT_PHRASE_BUSY
        bne     @r
        sta     D64_AI_ADVANCE_HOUR
        jsr     ai_clock_advance_hour
@ev:    jmp     ai_hour_change_events
@r:     rts
```

## Qué pasa en cada hora

`ai_hour_change_events` se ejecuta una vez cada vez que la hora es distinta de la última atendida.  Es uno de los
guiones del juego: una lista de pruebas y acciones en el propio código de bytes del original (ver
[La mente de los monjes](Monjes.md)), que un generador traduce al mismo código de bytes con operandos del 6502, con
cada expresión escrita encima como comentario:

[`src/c64/juego_final/logica_b_guiones.s`](../../../src/c64/juego_final/logica_b_guiones.s#L1118-L1162), líneas 1118–1162:

```asm
; 5A4F ai_hour_change_events
ai_hour_change_events:
        jsr     logica_b_vm
L5A4F:
        ; [game_hour] [ai_last_hour_done] =
        PRUEBA   $E7, $10, $54, L5A58
T5A4F:
        .byte   $C9
L5A58:
        .byte   $D7, $54, $88  ; [ai_last_hour_done] := [game_hour]
        .byte   $CD, 4, 0, $00  ; game_set_c004_inline
        ; [game_hour]
        PRUEBA3  $EB, $10, T5A5F
T5A5F:
        .byte   $CD, 10, 0  ; util_jump_table_inline
        .word   L5A75, L5A91, L5AE2, L5AE9, L5AFC, L5B0F, L5B13, 0
        .byte   $C9
L5A75:
        ; [game_day] 05h =
        PRUEBAP $F8, D64_CHR_BACKUP+24, $05, L5A81
T5A75:
        .byte   $CD
        .word   obj_place_glasses
        .byte   $CD
        .word   obj_place_key1
L5A81:
        ; [game_day] 06h =
        PRUEBAP $F8, D64_CHR_BACKUP+24, $06, L5A90
T5A81:
        .byte   $CD
        .word   obj_place_key3
        .byte   $CD
        .word   chr_jorge_appears
        .byte   $D8, $5A, $00  ; [ai_severin_slot_busy] := 00h
L5A90:
        .byte   $C9
L5A91:
        .byte   $CD
        .word   vid_spiral_wipe
        .byte   $D8, $3C, $EF  ; [obj_door_check_mask] := EFh
        .byte   $CD
        .word   vid_palette_day
        .byte   $CD
        .word   obj_open_left_wing_doors
        .byte   $CD
```

| Hora | Todos los días | Algunos días |
|---|---|---|
| noche | | día V: se colocan las gafas y la llave 1; día VI: se coloca la llave 3 y Jorge aparece en el registro de Severino |
| prima | la transición en espiral, la máscara de puertas del día, la paleta de día, se abren las puertas del ala izquierda, las campanas | desde el día III la lámpara en la cocina; el día II Guillermo pierde las gafas; el día III Jorge recibe el libro, Berengario desaparece y el pergamino pasa al abad si Guillermo no lo ha cogido; el día V se quita la llave 1 si Guillermo no la tiene |
| tercia | la transición en espiral, las campanas | |
| sexta | las campanas | día IV: llega Bernardo Gui en el registro de Berengario |
| nona | la transición en espiral, las campanas | día III: queda libre el registro de Berengario |
| vísperas | las campanas | |
| completas | la transición en espiral, la paleta de noche, la máscara de puertas de la noche, las campanas | |

La *transición en espiral* (`vid_spiral_wipe`) llena el área de juego con dos espirales cuadradas y hace que la sala se
dibuje otra vez; la *máscara de puertas* (`OBJ_DOOR_CHECK_MASK`) decide qué puertas puede abrir cada personaje a esa
hora del día.

## Las ceremonias

En prima y vísperas los monjes van a la iglesia; en sexta, al refectorio.  El abad va a su sitio, y solo cuando todos
los monjes vivos han llegado al suyo (el guion suma sus valores de *llegado*) comprueba a Guillermo:

* ausente: el abad cuenta; después de C8h fotogramas viene a expulsarlo;
* presente pero tarde (tras 32h fotogramas de espera): *LLEGÁIS TARDE, FRAY GUILLERMO*, y el obsequium baja 2;
* en la sala pero no en su sitio exacto (iglesia: x 84h, y 4Bh mirando al altar; refectorio: 38h, 39h): cada 1Eh
  fotogramas *OCUPAD VUESTRO SITIO, FRAY GUILLERMO*, y −2;
* en su sitio: la oración o el anuncio del día, y la hora avanza.

Adso se lo recuerda a Guillermo una vez por ceremonia (*DEBEMOS IR A LA IGLESIA, MAESTRO*).  En completas el abad
manda a los monjes a sus celdas y sigue a Guillermo hasta la suya; de noche, cuando Guillermo lleva un rato fuera de su
celda, el abad sale de la suya a buscarlo y lo expulsa si lo encuentra.
