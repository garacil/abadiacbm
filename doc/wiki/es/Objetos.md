<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Objetos.md: se edita la plantilla, no esta página. -->
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

[`src/c64/juego_final/logica_a.s`](../../../src/c64/juego_final/logica_a.s#L1243-L1246), líneas 1243–1246:

```asm
; 4BEC obj_update_inventory: once a frame: the objects picked up (4C46 from Guillermo's holder), dropped (4DC3),
; the key permissions (4D97); the inventory sounds of Adso (objects, lamp) and Guillermo; the manuscript read when
; Guillermo's glasses/parchment bits changed and he has both; the changed slots redrawn (4D30); bit 0 cleared in
; every object record.  Out: HL = the FFh record, BC = 5, A = FFh, ZF = 1.
```

Un objeto se coge cuando está en la celda de delante de un portador cuyas máscaras lo permiten; así Adso, que anda
detrás de Guillermo, recoge él mismo la lámpara o la llave 3:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L611-L615), líneas 611–615:

```asm
; 4C46 obj_pick_up_objects: for each holder from IX to the FFh entry whose counter +6 runs out, the first object
; not taken this frame, not hidden, allowed by its masks and lying in front of it (its own position, or its
; holder's character's when held and the taker is not locked) is taken: from its old holder, spr_mark_leaving,
; record +0 := 81h, +2/+3 := the holder, holder +6 := 10h and its bit set.  The search stops when no allowed
; object is left (the Z80 goes on to the FFh record without effect).  Out: IX = the FFh entry.
```

ESPACIO deja el primer objeto de Guillermo delante de él, si ese suelo está libre y llano:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L977-L991), líneas 977–991:

```asm
; 4DC3 obj_drop_on_space: the space bar (CPC key 2Fh) down: Guillermo drops an object (into 4DCD).
obj_drop_on_space:
        lda     #$2F
        jsr     sys_key_down
        bne     :+
        rts
:       lda     #<D64_OBJ_CHAR_OBJECTS
        sta     zix
        lda     #>D64_OBJ_CHAR_OBJECTS
        sta     zix+1
; 4DCD obj_drop_object: holder IX drops its first object (the highest bit of +3) when its counter +6 runs out:
; in front of it if that cell of the height buffer (on the floor shown) is free, below 0Dh, at most 4 above the
; floor level and level with its three neighbours (else nothing); at its character's position when the floor
; or the buffer do not allow the test.  Then its record (bit 7 cleared, +4 height, +1 an orientation read
; where the original reads it, +2/+3 x/y) and obj_redraw_one_object.
```

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

[`src/c64/juego_final/objetos_sonido.s`](../../../src/c64/juego_final/objetos_sonido.s#L448-L456), líneas 448–456:

```asm
; 0B1D obj_door_check_open_close: opens or closes door IY (sprite IX).  Fixed doors (bit 7 of [door+1]) are left
; alone.  C = [door+1] & 1Fh & ([D64_OBJ_DOOR_CHECK_MASK] | 10h); E, D = x - 2, y - 2.  If Guillermo or Adso
; lacks the bit (the other's mask ORed in) and stands near (obj_door_unpermitted_near), the door closes; else a
; permission entry with the bit standing at x-1..x+2, y-1..y+2 opens it; none closes it.  The change: the old
; leaf's cells get the door's height (obj_door_mark_cells with [door+4]), bit 6 set or cleared,
; [D64_OBJ_DOOR_MOVED] = 80h, the orientation -1 or +1 (opening with bit 5 set -1, closing with bit 5 clear
; -1); if the third cell of the new leaf holds a character ([cell] & F0h) the door bytes are restored,
; [D64_OBJ_DOOR_MOVED] = 0 and the leaf is marked again.  The Z80 keeps the door bytes in B', C' (EXX): o_guarda.
; The permission table (D64_OBJ_DOOR_PERMISSIONS: mask, word -> the character's x, y; FFh) is read indexed by X
```

Quién puede abrir cada puerta sale de tres sitios: las **llaves** (la llave 1 y la llave 2 dan a Guillermo una puerta
cada una, la llave 3 le da una a Adso), la **hora del día** (`OBJ_DOOR_CHECK_MASK`: algunas puertas se cierran de
noche) y los **guiones** (las máscaras de puertas de los monjes).  Los mismos permisos abren o cierran los enlaces
entre salas que usa el buscador de caminos:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L909-L910), líneas 909–910:

```asm
; 4D97 obj_update_key_permissions: Adso's key 3 (bit 1 of his objects) -> bit 4 of his doors (292Dh);
; Guillermo's key 1 (bit 3) -> bit 0, key 2 (bit 2) -> bit 2 of his (292Ah).  Out: A = his new byte.
```

[`src/c64/juego_final/estado_texto.s`](../../../src/c64/juego_final/estado_texto.s#L271-L274), líneas 271–274:

```asm
; 39F1 obj_set_door_permissions: ai_random := chr_command_buffers[0]; for the 6 doors of obj_door_link_table
; ((index into chr_room_links, bits) pairs, FFh ends a door) the bits are cleared when the door's bit of
; zbc (C) AND obj_door_check_mask is set (the opcode at 3A24 = CCF), else set (NOP).  Out: A = FFh, B = 0,
; C = that mask >> 6, zhl = chr_room_links.
```

## El manuscrito y el espejo

Cuando Guillermo lleva a la vez las gafas y el pergamino, lee el manuscrito: se elige un número romano al azar, una vez
por partida (el `LD A,R` del CPC; aquí, el temporizador de la CIA y la línea del haz), se escribe sobre la palabra `AAA`
del diccionario y aparece la frase en latín: *SECRETUM FINIS AFRICAE, MANUS SUPRA XIX IDOLUM AGE PRIMUM ET SEPTIMUM DE
QUATUOR*, con IXX, XIX o XXI:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L1772-L1784), líneas 1772–1784:

```asm
; 5184 obj_read_manuscript: Guillermo holds the glasses and the parchment: the stair numeral, chosen once at
; random (the CPC's LD A,R: plat_aleatorio; & 3, 0 -> 1), set again, and phrase 00h.
obj_read_manuscript:
        lda     D64_OBJ_MIRROR_NUMERAL
        bne     :+
        jsr     plat_aleatorio
        and     #$03
        bne     :+
        lda     #1
:       jsr     obj_set_mirror_numeral
        jsr     hud_say
        .byte   $00
        rts
```

En la sala del espejo de la biblioteca, Guillermo tiene que ponerse en el escalón que nombra el número y pulsar Q y R a
la vez.  `game_check_qr_mirror` mira si Guillermo está en x = 22h, a la altura 1Ah, con las dos teclas pulsadas, y
devuelve el escalón por su y (6Dh, 69h, 65h: el 1, el 2 y el 3).  El escalón bueno abre el espejo, el camino al finis
Africae; cualquier otro es una trampa y Guillermo cae:

[`src/c64/juego_final/personajes.s`](../../../src/c64/juego_final/personajes.s#L2045-L2049), líneas 2045–2049:

```asm
; 2D99 game_input_and_mirror: the input step of the main loop: sys_read_keyboard, EI.  While the mirror is closed
; ([28DD]): game_check_qr_mirror; with Q+R down on a step: a numeral [290D] other than 4 sets bit 2 of [2910];
; the numeral = the step opens the mirror (FF at [[2EDE]], 51h at [[2EE5]], between DI and EI); numeral 4 or
; another step is the trap ([37E4] = 1, [23E4] = 14h, 6Bh two bytes before [[2EE5]], hud_say_now with its
; inline phrase 22h).  Both: [28C6] = 0 (the room is rebuilt), [28DD] = 0, snd_play_mirror_open (0C6D).
```

En el C64 las teclas son las del CPC: Q y R juntas (primero R, como explica `teclado.s`, porque Q sola también hace
andar).  La versión de PC elegía siempre el mismo número; el juego completo del C128 conserva el azar del CPC.

### Los reflejos

Mientras el espejo está cerrado, Guillermo y Adso se reflejan en él.  `iso_mirror_reflect` dibuja la imagen de un
personaje cuando el búfer de alturas es el de la sala del espejo y el personaje está en su suelo (x de 20h a 29h, y de
62h a 6Bh): la refleja (x := 42h − x, la orientación cambiada) y la anima con una rutina de volteo propia:

[`src/c64/juego_final/logica_b.s`](../../../src/c64/juego_final/logica_b.s#L1220-L1226), líneas 1220–1226:

```asm
; 4F03 iso_mirror_reflect: the mirror image of character IY (sprite IX) when the height buffer is at the
; mirror's room (origin 1Ch, 5Ch) and the character stands on floor 16h (below +8), x 20h-29h, y 62h-6Bh:
; mirrored (x := 42h - x, one less with bit 7 of +5; orientation XOR 2 when even; +0 XOR 2), chr_cur_flip :=
; 4FC9, chr_cur_anim := DE, sprite +0Bh bit 7, chr_animate; the sprite's old position and size from the
; previous image when one was shown; the state words := the new ones; the character restored.  The operands
; 4FD9 (buffer), 4FA9 (state +0), 4F9A/4FA2 (state+1), 4F9E/4FA6 (state+3) are set first.
; In: HL = buffer, BC = state, DE = animation table, IX = sprite, IY = character.  Out: L = 00h or FEh.
```

## Todas las rutinas de objetos y sonido

| Original | Rutina | Línea |
|---|---|---|
| 0983h | [`obj_redraw_one_object`](../../../src/c64/juego_final/objetos_sonido.s#L77) | 77 |
| 0993h | [`obj_place_objects_in_room`](../../../src/c64/juego_final/objetos_sonido.s#L93) | 93 |
| 09ABh | [`obj_for_each_visible`](../../../src/c64/juego_final/objetos_sonido.s#L111) | 111 |
| 09D7h | [`obj_update_doors`](../../../src/c64/juego_final/objetos_sonido.s#L152) | 152 |
| — | [`o_siguiente`](../../../src/c64/juego_final/objetos_sonido.s#L196) | 196 |
| — | [`o_spr_ix`](../../../src/c64/juego_final/objetos_sonido.s#L211) | 211 |
| 0A2Bh | [`obj_object_sprite_update`](../../../src/c64/juego_final/objetos_sonido.s#L222) | 222 |
| 0A89h | [`obj_door_mark_cells`](../../../src/c64/juego_final/objetos_sonido.s#L310) | 310 |
| 0A9Ch | [`obj_door_cells`](../../../src/c64/juego_final/objetos_sonido.s#L329) | 329 |
| 0ABCh | [`spr_project_entity`](../../../src/c64/juego_final/objetos_sonido.s#L352) | 352 |
| 0AD6h | [`obj_door_flip_graphics`](../../../src/c64/juego_final/objetos_sonido.s#L376) | 376 |
| 0AFCh | [`obj_door_adjust_grid_pos`](../../../src/c64/juego_final/objetos_sonido.s#L424) | 424 |
| 0B1Dh | [`obj_door_check_open_close`](../../../src/c64/juego_final/objetos_sonido.s#L460) | 460 |
| — | [`antigua`](../../../src/c64/juego_final/objetos_sonido.s#L553) | 553 |
| — | [`o_no_permitido`](../../../src/c64/juego_final/objetos_sonido.s#L591) | 591 |
| — | [`o_cerca`](../../../src/c64/juego_final/objetos_sonido.s#L598) | 598 |
| — | [`o_ix_mas_bc`](../../../src/c64/juego_final/objetos_sonido.s#L646) | 646 |
| 0BF8h | [`chr_path_reset_alternatives`](../../../src/c64/juego_final/objetos_sonido.s#L659) | 659 |
| — | [`s_pon`](../../../src/c64/juego_final/objetos_sonido.s#L782) | 782 |
| — | [`s_interrupcion`](../../../src/c64/juego_final/objetos_sonido.s#L837) | 837 |
| — | [`s_siguiente`](../../../src/c64/juego_final/objetos_sonido.s#L1028) | 1028 |
| 0F88h | [`snd_cmd_jump`](../../../src/c64/juego_final/objetos_sonido.s#L1308) | 1308 |
| 0F8Bh | [`snd_cmd_start_b`](../../../src/c64/juego_final/objetos_sonido.s#L1318) | 1318 |
| 0FA9h | [`snd_cmd_tone_env`](../../../src/c64/juego_final/objetos_sonido.s#L1331) | 1331 |
| 0FBEh | [`snd_psg_write`](../../../src/c64/juego_final/objetos_sonido.s#L1362) | 1362 |
| 0FE6h | [`snd_silence_all`](../../../src/c64/juego_final/objetos_sonido.s#L1383) | 1383 |
| — | [`s_paso`](../../../src/c64/juego_final/objetos_sonido.s#L1425) | 1425 |
| — | [`s_canal_c`](../../../src/c64/juego_final/objetos_sonido.s#L1440) | 1440 |
