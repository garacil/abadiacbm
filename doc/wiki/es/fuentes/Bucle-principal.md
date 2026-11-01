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

{{code src/c64/juego_final/principal.s | ^\.proc principal_inicio | ^\.endproc}}

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

{{code src/c64/juego_final/principal.s | ^\.proc game_main | ^reanuda:}}

## El fotograma

Cada vuelta de `bucle` es un fotograma del juego.  Los comentarios dan la dirección del Z80 de cada paso: el orden es
el del original, paso a paso.

{{code src/c64/juego_final/principal.s | ^bucle:  +; 2179 | ^        jmp     bucle}}

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

{{code src/c64/plataforma/interrupcion.s | ^; the game's build \(-D JUEGO; the speed | ^\.endproc}}

Dos detalles de la versión 6502: la llamada al sonido es una instrucción que se reescribe sobre la marcha (`JSR`
mientras suena un canal, `BIT` cuando no suena ninguno: el caso más frecuente no cuesta ninguna llamada), y la rutina
pone visible la E/S por su cuenta, porque el juego puede estar leyendo los gráficos de debajo de la E/S cuando llega el
tick.  Un tick vacío cuesta 69 ciclos.

## La velocidad del juego

El presupuesto del fotograma, `SYS_FRAME_TICKS`, es de 36 ticks (120 ms) mientras se juega.  Cuando no se pulsa
ninguna tecla de movimiento durante 50 fotogramas el presupuesto pasa a 0 (el juego va tan rápido como dé la máquina,
salvo mientras se enseña una frase) y la cámara puede ir al personaje que la historia quiere enseñar:

{{code src/c64/juego_final/logica_a.s | ^; 3CC5 game_camera_select | ^\.endproc}}

Así que la velocidad del original depende de cuánto dibuja cada fotograma.  El juego del CPC va muchas veces más
lento que su presupuesto; hice el juego del C64 más rápido que el del CPC (medido en VICE, sin teclas desde el
principio: los fotogramas 1-2000 en 122,5 s en el C64 frente a 294,2 s en un CPC 6128, ver `doc/ESTADO.md`), y el
C128 va a 2 MHz mientras el haz está en los bordes.
