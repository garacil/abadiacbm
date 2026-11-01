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

{{code src/c64/juego_final/logica_b.s | ^; 5028 ai_clock_init | ^        rts}}

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

{{code src/c64/juego_final/logica_b.s | ^; 5060 ai_clock_load_duration | ^\s+rts}}

Cada fotograma el contador baja; cuando llega a 0, la hora avanza.  Después de completas avanza el día, su número
romano se vuelve a dibujar en el marcador y el nombre de la hora nueva entra desplazándose (`HUD_HOUR_SCROLL_STEPS` =
9 pasos):

{{code src/c64/juego_final/logica_b.s | ^; 507D ai_clock_tick | ^\s+jmp     ai_clock_load_duration}}

La llamada `sys_key_pressed(6)` seguida de `util_return_zero` es el rastro de una tecla de los programadores que
saltaba a la hora siguiente: el original la desactivó haciendo que la prueba siempre fuera falsa, y en la traducción la
dejé tal cual.  En el C128 y en el P500, a completas, el cambio de hora toca además el Ave María de la versión de PC
(`c128_ave`, ver [El Commodore 128](Commodore-128.md)).

## Las horas que acaba la historia

La mayoría de las horas no tienen límite de tiempo: un guion pone `AI_ADVANCE_HOUR` (por ejemplo el abad, cuando todos
los monjes están en la iglesia y ha dicho *OREMOS*; o Adso, cuando Guillermo contesta que sí a *¿DORMIMOS?, MAESTRO*).
Entonces la hora avanza en cuanto no se está enseñando ninguna frase (así siempre se oye la última frase de una escena)
y nunca mientras el personaje al que sigue la cámara está entre dos pasos:

{{code src/c64/juego_final/estado_texto.s | ^; 3A37 ai_hour_update | ^@r:     rts}}

## Qué pasa en cada hora

`ai_hour_change_events` se ejecuta una vez cada vez que la hora es distinta de la última atendida.  Es uno de los
guiones del juego: una lista de pruebas y acciones en el propio código de bytes del original (ver
[La mente de los monjes](Monjes.md)), que un generador traduce al mismo código de bytes con operandos del 6502, con
cada expresión escrita encima como comentario:

{{code src/c64/juego_final/logica_b_guiones.s | ^; 5A4F ai_hour_change_events | +45}}

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
