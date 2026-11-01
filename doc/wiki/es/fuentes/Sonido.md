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

# El sonido

[Inicio](Inicio.md) · anterior: [El texto y el marcador](Texto.md) · siguiente: [La plataforma del Commodore 64](Plataforma-C64.md)

El chip de sonido del CPC es el AY-3-8912: tres canales de onda cuadrada y un generador de ruido.  El juego lo maneja
desde la interrupción de 300 Hz con un pequeño **secuenciador**; en los Commodore el mismo secuenciador funciona sin
cambios, y la capa de plataforma toca sus escrituras de registros en el SID.  Está en
`src/c64/juego_final/objetos_sonido.s` y `src/c64/plataforma/psg.s`.

## El secuenciador

Cada uno de los tres canales toca una **secuencia**: notas (un tono y una duración en ticks), silencios, ruido y órdenes
(saltar, empezar una secuencia en el canal B o en el C, fijar la **envolvente** de tono o de volumen).  Una vez por
interrupción avanza cada canal que suena; en cada tick del tempo, una nota terminada deja paso al byte siguiente:

{{code src/c64/juego_final/objetos_sonido.s | ^; 0DBC snd_channel_tick | +8}}

Los bytes de una secuencia son:

| Byte | Significado |
|---|---|
| `F9`-`FE` w | una orden con un argumento de dos bytes (la tabla `SND_COMMANDS`): `F9` saltar, `FE` / `FD` empezar una secuencia en el canal B / C, `FB` / `FA` la envolvente de tono / de volumen, `FC` nada |
| `FF` | el final: el canal se calla (estado 0) |
| n, ticks | una nota: el tono es una de 16 frecuencias (los cuatro bits bajos) desplazada por la octava (bits 4-6); con el bit 7, un byte más con el periodo del ruido; con los cuatro bits bajos a `F`, un silencio de la misma duración |

El periodo de una nota sale de una tabla de 16 periodos desplazada por la octava; después las envolventes mueven el
volumen y el tono en cada tick (el vibrato de la música).

## Los sonidos y sus canales

El juego empieza sus sonidos con pequeños **disparadores**, cada uno una secuencia en un canal fijo.  Varios comparten
código: el byte 2Ch (`BIT abs`) se salta el `LDY` del disparador siguiente, así que cada uno solo carga su secuencia y
cae en el que elige el canal:

{{code src/c64/juego_final/objetos_sonido.s | ^        ENTRADA snd_play_mirror_open | +27}}

| Canal | Sonidos |
|---|---|
| A | el espejo que se abre, las campanas de las horas y las de tercia |
| B | las puertas que se cierran y se abren, Severino, un objeto que se deja, un objeto que se coge |
| C | los pasos de Guillermo, el pitido de las frases y la música (que solo empieza si el canal C está libre) |

## El AY en el SID

`plat_psg` recibe las escrituras de registros del AY y las traduce manteniendo exactos las notas y el ritmo: las mismas
frecuencias, y una voz del SID que se abre y se suelta en las mismas escrituras en las que el tono del AY empieza y
termina.  El timbre es el propio del SID:

{{code src/c64/plataforma/psg.s | ^; Each AY channel is a SID voice | ^;   registers 11-13}}

Los registros de tono son el camino más usado (se escribe un periodo casi en cada tick mientras suena algo), así que
`snd_channel_output` del juego llama directamente a `plat_psg_tono` con los dos bytes de un periodo, y la frecuencia sale
de una tabla de 129 valores, con desplazamientos para las demás octavas.

## Los pasos en el C64

En el CPC un paso ocupa el canal C toque lo que toque allí, así que andar corta la música, que vuelve a empezar desde el
principio cuando Guillermo lleva 50 fotogramas quieto.  En el C64 la música conserva su canal:

{{code src/c64/juego_final/objetos_sonido.s | ^; The C64 build only: the music keeps channel C | +7}}

Además, los pasos suenan más flojos que los demás sonidos, a la mitad (`psg_paso`).

## Quitar los pasos o el sonido del texto

El menú de inicio deja quitar los pasos y el pitido de las frases.  No basta con no llamarlos: la música de espera se
repite sin fin, y lo único que la termina es justamente un paso (que la deja acabar al final de su vuelta) o el pitido
de una frase (que la corta).  Si se quitara la llamada, la música no pararía nunca.  Así que cuando una opción está
quitada, el cargador escribe `0Fh` sobre la única nota de la secuencia del paso o del pitido: un silencio de la misma
duración.  El juego toca la secuencia igual que siempre, con los mismos efectos en el canal C, pero sin que se oiga, y
su estado sigue siendo exactamente el del original:

{{code src/c64/juego_final/objetos_sonido.s | ^; The options menu's footsteps or text's sound off | +7}}

## La música

El juego tiene una sola melodía, para el canal C, que empieza cuando Guillermo se queda quieto y se repite.  Los
pergaminos de la presentación y del final tienen sus propias melodías, tocadas por un reproductor del mismo tipo en el
programa de presentación (`src/c64/pergamino/musica.s`, ver [Presentación y final](Pergaminos.md)), con las mismas
escrituras de registros que el CPC, comprobadas una a una contra el original.

En el C128 y en el P500, en completas, el juego toca además el **Ave María** de la versión de PC: una voz digitalizada
de 13,45 s que suena a través del registro de volumen del SID (ver [El Commodore 128](Commodore-128.md)).
