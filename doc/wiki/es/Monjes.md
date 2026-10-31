<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Monjes.md: se edita la plantilla, no esta página. -->
# La mente de los monjes

[Inicio](Inicio.md) · anterior: [Alturas y búsqueda de caminos](Caminos.md) · siguiente: [Objetos, puertas y el espejo](Objetos.md)

Cada uno de los otros cinco personajes tiene un **guion**: una rutina escrita en un pequeño lenguaje del programa
original, que decide **adónde va** el personaje y **qué dice**, según el día, la hora, dónde está Guillermo y las
variables de la historia.  El movimiento en sí (la ruta, los pasos) es cosa del buscador de caminos.  Los guiones están
en `src/c64/juego_final/logica_b_guiones.s` y su máquina virtual en `logica_b.s`.

## Los conductores

Cada fotograma `game_run_npc_behaviours` llama al conductor de cada personaje (Adso, Malaquías, el abad, el registro de
Berengario y el de Severino).  Un conductor apunta IY al registro del personaje e IX a su tabla de **lugares**, ejecuta
su guion, le da las puertas que puede abrir, le mueve un paso y después planea una ruta si el guion ha cambiado su
destino:

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L86-L89), líneas 86–89:

```asm
; The common part of the drivers (X = 0 Malachi, 1 the abbot, 2 Berengar, 3 Severin, 4 Adso): ai_no_route
; [37E9] = 0; the behaviour (IY = record, IX = places, A = 0); the door permissions (C = the mask;
; Berengar's is the operand 04B0h, script variable A9); chr_update (HL = the chr_table entry).  Out: IY =
; the record chr_update worked on ([247E]), IX = the places.
```

[`src/c64/juego_final/camino.s`](../../../src/c64/juego_final/camino.s#L145-L150), líneas 145–150:

```asm
; 03AC (ai_plan_route, the shared tail of the drivers): a move already planned (bit 7 of [chr+9] clear) ->
; ai_check_planned_move; ai_no_route set -> nothing.  Destination d = [places-1]: FF/FE/FD/FC = Guillermo /
; the abbot / the book / the parchment, whose four neighbours are the candidates (slot 0201h); else the
; place p = places + 3d (8 bit) is copied to 0203h (FF after it) and its neighbours follow (slot 0204h).
; chr_path_alt_ptr [0213] = 0203h; a candidate -> chr_path_find; result FD (already there) -> [places-3] =
; [places-1].  In: IY = chr, IX = places.
```

Los tres bytes que hay antes de la tabla de lugares son la interfaz del guion: el lugar **alcanzado**, el **estado** del
personaje y el **destino** (un número de lugar, o FF Guillermo, FE el abad, FD el libro, FC el pergamino).  Los lugares
son los puntos fijos de la abadía: la iglesia, el refectorio, las mesas del scriptorium, las celdas, la entrada, la
cocina, el paso a la biblioteca…

## El lenguaje de los guiones

Los guiones del original son código del Z80 con dos ayudantes, `RST 08h` (probar) y `RST 10h` (asignar), cada uno
seguido de una **expresión en notación postfija** sobre las variables del juego: `[87] 08 = [94] 02 = &` se lee
«Malaquías ha llegado al lugar 8 y Severino al lugar 2».  Las comparaciones dan 00 cuando son verdad; `*` y `&` son el
*o* y el *y* lógicos sobre esos valores.  Hay 570 de esas llamadas en el programa, todas en los guiones (51E7h-60F2h en
el juego de 64 KiB).

Traducirlas como llamadas del 6502 con datos detrás habría costado unos 7 KiB; en vez de eso, los guiones siguen siendo
**código de bytes**: cada rutina de guion es `JSR logica_b_vm` seguido de los propios bytes del Z80 (los mismos códigos,
`JR`, `JP`, `CALL`, `RET`, las expresiones detrás de la instrucción) con operandos del 6502, más unas cuantas formas
compactas para las pruebas más frecuentes.  Un generador (`guiones64.py`) traduce los guiones del Z80 de la memoria de
la cinta a esta forma, con cada expresión escrita como comentario.  Este es el contrato de la máquina virtual:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L62-L90), líneas 62–90:

```asm
; logica_b_vm: a script function is `JSR logica_b_vm` followed by its bytecode.  Runs it until its RET (or a
; tail call of a native routine).  The instruction pointer is zhl + Y: Y (0-127 at each dispatch) moves along
; the instructions and is folded into zhl when it reaches 128, at a jump and at an expression (ai_script_eval
; leaves zhl at the expression's end, as the Z80's HL).  The Z80's A and flags live in lb_va / lb_vf (lb_vf: N Z C
; as in a 6502 P; a P built from it takes the 6502's own I flag), from the entry's (5FDD, 6016, 6040 switch on
; their caller's C and Z).  The bytecode (guiones64.py; v = 2 x the variable's number mod 256, the offset of its
; word in D64_AI_SCRIPT_VARS):
;   CF expr       test: A = C = the value, Z = (value = 0)       D7 v expr     assignment
;   20 e / 18 e   JR NZ / JR                                     C2 nn         JP NZ to bytecode
;   C3 nn         JP to bytecode                                 C3 k 00       JP to lb_tabla[k] (native)
;   CD nn         CALL a native routine                          CD k 00 b     CALL lb_tabla[k] with the inline b
;   CD 0A 00 w..0 the switch of util_jump_table_inline 3A5D      C9            RET
;   3E n          LD A,n                                         01            XOR A
;   F8+p a n e    the test `v n =` (n a literal; the variable at page p 0-7 and low byte a), A = C = 00h
;                 true / FFh false and the flags of AND A, and its jump (e from the next instruction) when false
;   E2 v n e      the same (v as above), the jump when true
;   E3 / E4 v n e `v n >` (v >= n), the jump when false / true          E5 / E6 v n e  `v n <`
;   E7 / E8 v w e `v w =` (two variables)                              E9 / EA v m n e  `v m * n =` (v AND m = n)
;   EB v e / EC v m e  the value [v] / [v] AND m, the jump when not 0 (only the last test of a chain)
;   F0+p a n e    F8+p leaving A, C and the flags as they were (nothing reads them before setting them again)
;   A0+p / A8+p / B0+p a n e  `v n >` the jump when false / `v n =` when true / `v n <` when false, the same
;                 A test is a chain of these (guiones64.py)
;   DB/DC/DD/DE v n  [v] := [v] OR / + / AND / - n
;   D8 v n        assignment of a literal                        D9 v n        the same and RET
;   DA v n w m    two D8 in a row
;   D0 b / D1 b   CALL hud_say / hud_say_now b                   D2 / D3       CALL ai_guillermo_is_close /
;   D4            JP ai_stay                                                   hud_obsequium_minus_2
; The expressions are evaluated by ai_script_eval 3926 (group estado_texto; its entry estado_texto_eval_y takes
; the expression at zhl + Y): out zhl -> the terminator (A), zbc (C) = X = the value, N/Z of it.
```

Dicho en una tabla (v es el número de la variable por dos, el desplazamiento de su palabra en `AI_SCRIPT_VARS`):

| Código | Qué hace |
|---|---|
| `CF` expr | probar: A = C = el valor, Z si es 0 |
| `D7` v expr | asignar una expresión |
| `20` e / `18` e | `JR NZ` / `JR` |
| `C2` nn / `C3` nn | `JP NZ` / `JP` dentro del código de bytes |
| `C3` k `00` | saltar a una rutina nativa (la k de una tabla) |
| `CD` nn, `CD` k `00` b | llamar a una rutina nativa (con un byte detrás si lo lleva) |
| `CD 0A 00` w… `0` | el *switch* de `util_jump_table_inline` |
| `C9` | `RET` |
| `3E` n / `01` | `LD A,n` / `XOR A` |
| `F8`+p a n e, `E2` v n e | la prueba `v n =`, con el salto cuando es falsa / verdadera |
| `E3`/`E4`, `E5`/`E6` v n e | `v n >` (v ≥ n) y `v n <`, saltando cuando es falsa / verdadera |
| `E7`/`E8` v w e | `v w =` entre dos variables |
| `E9`/`EA` v m n e | `v m * n =` (v AND m = n) |
| `EB` v e / `EC` v m e | el valor de v (o v AND m), saltando si no es 0 |
| `A0`+p, `A8`+p, `B0`+p a n e | las mismas pruebas encadenadas |
| `DB`/`DC`/`DD`/`DE` v n | v := v OR / + / AND / − n |
| `D8` v n, `D9` v n, `DA` v n w m | asignar un literal; asignarlo y volver; dos asignaciones seguidas |
| `D0` b / `D1` b | `hud_say` / `hud_say_now` con la frase b |
| `D2` / `D3` / `D4` | `ai_guillermo_is_close` / quitar 2 de obsequium / quedarse quieto (`ai_stay`) |

El puntero de instrucción es `zhl + Y`: Y avanza por las instrucciones y se suma a `zhl` cuando llega a 128, en cada
salto y en cada expresión.  La A y las banderas del Z80 viven en dos bytes (`lb_va`, `lb_vf`), porque los guiones las
miran después de muchas instrucciones.  Las expresiones las evalúa `ai_script_eval` (3926h).

El principio del guion del abad: las reglas que van antes que nada (Guillermo en el ala izquierda a prima o el día I;
Guillermo en la biblioteca después de la noche; la expulsión):

[`src/c64/juego_final/logica_b_guiones.s`](../../../src/c64/juego_final/logica_b_guiones.s#L1244-L1283), líneas 1244–1283:

```asm
; 5B21 ai_abbot_think
ai_abbot_think:
        jsr     logica_b_vm
L5B21:
        ; [guillermo_x] 60h < [game_hour] 01h = [game_day] 01h = and or
        PRUEBAP $B0, D64_CHR_GUILLERMO+2, $60, L5B32
M5B21_0:
        PRUEBAP $A8, D64_CHR_BACKUP+25, $01, T5B21
M5B21_1:
        PRUEBAP $F0, D64_CHR_BACKUP+24, $01, L5B32
T5B21:
        .byte   $D8, $18, $0B  ; [ai_abbot_state] := 0Bh
L5B32:
        ; [game_hour] 01h >= [guillermo_z] 16h >= or
        PRUEBAP $A0, D64_CHR_BACKUP+25, $01, L5B43
M5B32_0:
        PRUEBAP $A0, D64_CHR_GUILLERMO+4, $16, L5B43
T5B32:
        .byte   $D8, $16, $09  ; [ai_abbot_dest] := 09h
        .byte   $D9, $18, $0B  ; [ai_abbot_state] := 0Bh / RET
L5B43:
        ; [ai_abbot_state] 0Bh =
        PRUEBAP $F0, D64_GAME_BOOK_POISON_COUNT+66, $0B, L5B67
T5B43:
        .byte   $D8, $16, $FF  ; [ai_abbot_dest] := FFh
        .byte   $D2  ; CALL ai_guillermo_is_close
        JRNZ    L5B66
        ; [game_guillermo_dead] 01h =
        PRUEBAP $F8, D64_GAME_BOOK_POISON_COUNT+18, $01, L5B59
T5B52:
        .byte   $C9
L5B59:
        ; [txt_phrase_busy] 00h =
        PRUEBAP $F8, D64_CHR_BACKUP+57, $00, L5B66
T5B59:
        .byte   $D0, $0E  ; hud_say
        .byte   $D8, $38, $01  ; [game_guillermo_dead] := 01h
L5B66:
        .byte   $C9
L5B67:
```

## Los personajes

**El abad.**  Primero las reglas: Guillermo en el ala izquierda a prima o el primer día, o en la biblioteca cuando no
debe, significa la expulsión (estado 0Bh: va hacia Guillermo y, cuando está cerca, *NO HABÉIS RESPETADO MIS ÓRDENES.
ABANDONAD PARA SIEMPRE ESTA ABADÍA*).  El día I a nona hace la visita de bienvenida (la entrada, la primera parada, su
celda, la celda de Guillermo), y se para cada vez que Guillermo se queda atrás (*OS ORDENO QUE VENGÁIS*, y −2 de
obsequium).  Dirige las ceremonias (ver [El reloj](Reloj.md)), manda a todos a sus celdas en completas, vigila de
noche, pide el pergamino cuando Berengario le ha contado que Guillermo lo cogió, y a tercia y a nona de algunos días
llama a Guillermo (*VENID AQUÍ, FRAY GUILLERMO*) para darle las noticias: la muerte de Venancio, la desaparición de
Berengario, la llegada de Bernardo Gui, la muerte de Severino y, el día VII, el final de la investigación.

Mientras lleva a Guillermo a algún sitio (su estado 13h), el abad solo avanza hacia su destino si Guillermo está
«cerca» (`ai_guillermo_is_close`); si no, se vuelve a buscarlo:

[`src/c64/juego_final/logica_b_guiones.s`](../../../src/c64/juego_final/logica_b_guiones.s#L1709-L1717), líneas 1709–1717:

```asm
        ; [ai_abbot_dest] 08h = [ai_abbot_state] 13h >= and
        PRUEBAP $A8, D64_GAME_BOOK_POISON_COUNT+67, $08, T5ECA
M5ECA_0:
        PRUEBA   $E3, $18, $13, L5EF5
T5ECA:
        .byte   $D8, $32, $00  ; [ai_wait_count] := 00h
        ; [ai_abbot_state] 13h =
        PRUEBAP $F8, D64_GAME_BOOK_POISON_COUNT+66, $13, L5EE9
T5ED7:
```

**Malaquías**, el bibliotecario, está sentado en su mesa junto al paso a la biblioteca y lo bloquea cuando Guillermo se
acerca (*LO SIENTO, VENERABLE HERMANO, NO PODÉIS SUBIR A LA BIBLIOTECA*); en vísperas coge la llave 3 de su mesa, saca a
Guillermo del edificio, avisa al abad si se queda, cierra las puertas del ala izquierda y se va a la cocina.  El día V
mata a Severino a tercia, y en vísperas muere envenenado (*ERA VERDAD, TENÍA EL PODER DE MIL ESCORPIONES*).

**El registro de Berengario**: Berengario en su mesa del scriptorium (que denuncia el pergamino si Guillermo lo coge),
luego el monje encapuchado que se lleva el libro de noche, la presentación de Jorge y, desde el día IV, **Bernardo
Gui**, que le pide el pergamino a Guillermo y al final se va de la abadía.

**El registro de Severino**: Severino el herbolario, que se presenta, avisa de las cosas extrañas de la abadía y
encuentra un libro extraño en su celda; desde el día VI **Jorge**, que espera en el finis Africae la última escena: el
libro, los guantes, el veneno y el final.

**Adso** sigue a Guillermo, va a la iglesia y al refectorio en las ceremonias, necesita la lámpara en la biblioteca
(*DEBEMOS ENCONTRAR UNA LÁMPARA, MAESTRO*), avisa cuando se agota y, de noche en la celda, pregunta *¿DORMIMOS?,
MAESTRO*: S (o Y en inglés) o no contestar pasan al día siguiente; N los deja despiertos.

## Hablar

Un guion dice una frase con `hud_say` y un número de frase detrás; la frase se desplaza por el marcador mientras el
juego sigue (ver [El texto y el marcador](Texto.md)).  `ai_guillermo_is_close` (Guillermo en el mismo piso y dentro de
una caja delante del monje) decide cuándo un monje le habla.  La caja es de 24 × 12 casillas, tumbada según hacia dónde
mira el monje (la tabla `AI_CLOSE_BOX_TABLE`, cuatro bytes por orientación):

| El monje mira hacia | Guillermo cerca si x − x del monje está en | y y − y del monje está en |
|---|---|---|
| +x (0) | −6 … +17 | −6 … +5 |
| −y (1) | −6 … +5 | −12 … +11 |
| −x (2) | −12 … +11 | −6 … +5 |
| +y (3) | −6 … +5 | −6 … +17 |


[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L209-L245), líneas 209–245:

```asm
; 39AE ai_guillermo_is_close: Z set when Guillermo is on the floor of the character at ziy and inside the box
; in front of it (ai_close_box_table, 4 bytes per orientation: x offset, x size, y offset, y size).
ai_guillermo_is_close:
        lda     D64_CHR_GUILLERMO+4
        jsr     iso_floor_base
        lda     zbc+1
        sta     ET_T
        ldy     #4
        lda     (ziy),y
        jsr     iso_floor_base
        lda     zbc+1
        cmp     ET_T
        bne     @r
        ldy     #1
        lda     (ziy),y
        asl
        asl
        tax
        lda     D64_CHR_GUILLERMO+2
        clc
        adc     D64_AI_CLOSE_BOX_TABLE,x
        iny
        sec
        sbc     (ziy),y
        cmp     D64_AI_CLOSE_BOX_TABLE+1,x
        bcs     @no
        lda     D64_CHR_GUILLERMO+3
        clc
        adc     D64_AI_CLOSE_BOX_TABLE+2,x
        iny
        sec
        sbc     (ziy),y
        cmp     D64_AI_CLOSE_BOX_TABLE+3,x
        bcs     @no
        lda     #0
@r:     rts
@no:    lda     #$FF
```

## Todas las rutinas de la lógica

| Original | Rutina | Línea |
|---|---|---|
| 4C46h | [`lb_pu_next`](../../../src/c64/juego_final/logica_b.s#L616) | 616 |
| — | [`lb_contador`](../../../src/c64/juego_final/logica_b.s#L764) | 764 |
| 4EA5h | [`obj_front_position`](../../../src/c64/juego_final/logica_b.s#L779) | 779 |
| 4D2Ah | [`hud_draw_guillermo_objects`](../../../src/c64/juego_final/logica_b.s#L830) | 830 |
| 4D30h | [`hud_draw_objects`](../../../src/c64/juego_final/logica_b.s#L838) | 838 |
| 4D97h | [`obj_update_key_permissions`](../../../src/c64/juego_final/logica_b.s#L911) | 911 |
| — | [`lb_espejado`](../../../src/c64/juego_final/logica_b.s#L942) | 942 |
| 4DC3h | [`obj_drop_on_space`](../../../src/c64/juego_final/logica_b.s#L978) | 978 |
| 4DCDh | [`obj_drop_object`](../../../src/c64/juego_final/logica_b.s#L992) | 992 |
| 4ECAh | [`iso_mirror_update`](../../../src/c64/juego_final/logica_b.s#L1181) | 1181 |
| 4EF4h | [`iso_mirror_character`](../../../src/c64/juego_final/logica_b.s#L1199) | 1199 |
| 4F03h | [`iso_mirror_reflect`](../../../src/c64/juego_final/logica_b.s#L1227) | 1227 |
| 4FC9h | [`iso_mirror_draw_callback`](../../../src/c64/juego_final/logica_b.s#L1365) | 1365 |
| 4FEFh | [`hud_scroll_hour_name`](../../../src/c64/juego_final/logica_b.s#L1421) | 1421 |
| 5028h | [`ai_clock_init`](../../../src/c64/juego_final/logica_b.s#L1480) | 1480 |
| 5035h | [`ai_clock_redraw`](../../../src/c64/juego_final/logica_b.s#L1489) | 1489 |
| 5060h | [`ai_clock_load_duration`](../../../src/c64/juego_final/logica_b.s#L1520) | 1520 |
| 507Dh | [`ai_clock_tick`](../../../src/c64/juego_final/logica_b.s#L1547) | 1547 |
| 5094h | [`ai_clock_advance_hour`](../../../src/c64/juego_final/logica_b.s#L1567) | 1567 |
| 50AFh | [`hud_set_and_draw_day`](../../../src/c64/juego_final/logica_b.s#L1586) | 1586 |
| 50D9h | [`hud_draw_day_numeral`](../../../src/c64/juego_final/logica_b.s#L1624) | 1624 |
| 510Ch | [`ai_timers_tick`](../../../src/c64/juego_final/logica_b.s#L1668) | 1668 |
| 5124h | [`hud_obsequium_minus_2`](../../../src/c64/juego_final/logica_b.s#L1692) | 1692 |
| 5129h | [`hud_obsequium_sub`](../../../src/c64/juego_final/logica_b.s#L1700) | 1700 |
| 5164h | [`hud_fill_bar`](../../../src/c64/juego_final/logica_b.s#L1752) | 1752 |
| 5184h | [`obj_read_manuscript`](../../../src/c64/juego_final/logica_b.s#L1774) | 1774 |
| 5199h | [`obj_set_mirror_numeral`](../../../src/c64/juego_final/logica_b.s#L1788) | 1788 |
| — | [`lb_blit`](../../../src/c64/juego_final/logica_b.s#L1815) | 1815 |
| — | [`lb_scr`](../../../src/c64/juego_final/logica_b.s#L1890) | 1890 |
| — | [`lb_nextline`](../../../src/c64/juego_final/logica_b.s#L1939) | 1939 |
| — | [`lb_der`](../../../src/c64/juego_final/logica_b.s#L1957) | 1957 |
| — | [`lb_espejos`](../../../src/c64/juego_final/logica_b.s#L1990) | 1990 |
| — | [`lb_esp_nue`](../../../src/c64/juego_final/logica_b.s#L1995) | 1995 |
| — | [`lb_masc`](../../../src/c64/juego_final/logica_b.s#L2000) | 2000 |
| — | [`lb_alu`](../../../src/c64/juego_final/logica_b.s#L2003) | 2003 |
| — | [`lb_brx`](../../../src/c64/juego_final/logica_b.s#L2005) | 2005 |
| — | [`lb_tabla`](../../../src/c64/juego_final/logica_b.s#L2007) | 2007 |
| — | [`lb_tramp`](../../../src/c64/juego_final/logica_b.s#L2013) | 2013 |

| Original | Rutina | Línea |
|---|---|---|
| 51E7h | [`game_update_camera_and_bonus`](../../../src/c64/juego_final/logica_b_guiones.s#L59) | 59 |
| 52B4h | [`ai_malachi_think`](../../../src/c64/juego_final/logica_b_guiones.s#L153) | 153 |
| 5495h | [`ai_berengar_think`](../../../src/c64/juego_final/logica_b_guiones.s#L401) | 401 |
| 571Ch | [`ai_severin_think`](../../../src/c64/juego_final/logica_b_guiones.s#L716) | 716 |
| 58F7h | [`ai_adso_think`](../../../src/c64/juego_final/logica_b_guiones.s#L951) | 951 |
| 5A4Fh | [`ai_hour_change_events`](../../../src/c64/juego_final/logica_b_guiones.s#L1119) | 1119 |
| 5B21h | [`ai_abbot_think`](../../../src/c64/juego_final/logica_b_guiones.s#L1245) | 1245 |
| 5FDDh | [`ai_abbot_count_vespers`](../../../src/c64/juego_final/logica_b_guiones.s#L1852) | 1852 |
| 5FEEh | [`ai_ready_ber_adso_sev_mal`](../../../src/c64/juego_final/logica_b_guiones.s#L1860) | 1860 |
| 5FF8h | [`ai_ready_adso_sev_mal`](../../../src/c64/juego_final/logica_b_guiones.s#L1867) | 1867 |
| 6000h | [`ai_ready_vespers_day5`](../../../src/c64/juego_final/logica_b_guiones.s#L1874) | 1874 |
| 6012h | [`ai_ready_adso`](../../../src/c64/juego_final/logica_b_guiones.s#L1886) | 1886 |
| 6016h | [`ai_abbot_count_prima`](../../../src/c64/juego_final/logica_b_guiones.s#L1893) | 1893 |
| 6040h | [`ai_abbot_count_sexta`](../../../src/c64/juego_final/logica_b_guiones.s#L1912) | 1912 |
| 6076h | [`ai_abbot_wait_ceremony`](../../../src/c64/juego_final/logica_b_guiones.s#L1943) | 1943 |
