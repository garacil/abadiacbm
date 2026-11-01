<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Sonido.md: se edita la plantilla, no esta página. -->
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

[`src/c64/juego_final/objetos_sonido.s`](../../../src/c64/juego_final/objetos_sonido.s#L971-L978), líneas 971–978:

```asm
; 0DBC snd_channel_tick: the sequence of the channel, once an interrupt.  Nothing unless playing (bit 0); the
; state keeps bits 0, 1, 2, 7.  On the tempo tick ([D64_SND_TEMPO] = 0) when the note ends (left - 1 = 0):
; state 1, the sequence commands (D64_SND_COMMANDS) run; FFh ends the sequence (state 0); else a note: byte n,
; its ticks, [the noise period when bit 7 of n: state bits 1, 3], the envelopes restart, volume 0; n & 0Fh =
; 0Fh is a rest (state bit 7), else the period = D64_SND_NOTE_PERIODS[n & 0Fh] >> ((n >> 4) & 7).  Then,
; unless silent (bit 7) or starting (bit 2): snd_vol_env_step, and every tone rate ticks a tone envelope step:
; steps - 1 (at 0 snd_tone_env_next), period += delta (signed), state bit 6.  In: IX = ch (s_tick_activo: X,
; A = the state, its bit 0 tested by the caller).
```

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

[`src/c64/juego_final/objetos_sonido.s`](../../../src/c64/juego_final/objetos_sonido.s#L725-L751), líneas 725–751:

```asm
        ENTRADA snd_play_mirror_open, D64_SND_SEQ_MIRROR_OPEN, SND_P0             ; 0C6D (2DE4)
        SALTA   SND_P0, 0
        ENTRADA snd_play_hour_bells, D64_SND_SEQ_HOUR_BELLS, SND_P1               ; 0C7C
        .byte   $2C
        ENTRADA snd_play_tercia_bells, D64_SND_SEQ_TERCIA_BELLS, SND_P1, 1           ; 0C81
        SALTA   SND_P1, 0
        ENTRADA snd_play_door_close, D64_SND_SEQ_DOOR_CLOSE, SND_P1               ; 0C86
        .byte   $2C
        ENTRADA snd_play_door_open, D64_SND_SEQ_DOOR_OPEN, SND_P1, 1                 ; 0C8B
        .byte   $2C
        ENTRADA snd_play_severino, D64_SND_SEQ_SEVERINO, SND_P1, 1                   ; 0C9A
        .byte   $2C
        ENTRADA snd_play_object_dropped, D64_SND_SEQ_OBJECT_DROPPED, SND_P1, 1       ; 0C9F
        SALTA   SND_P1, $18
        ENTRADA snd_play_object_taken, D64_SND_SEQ_OBJECT_TAKEN, SND_P0           ; 0C95
        SALTA   SND_P0, $18
        ENTRADA snd_play_footstep, D64_SND_SEQ_FOOTSTEP, SND_P0                   ; 0C72
.ifdef PRUEBA
        SALTA   SND_P0, $30
.else
        jmp     s_paso                  ; the C64: not while the music plays (BAJO)
.endif
        ENTRADA snd_play_beep, D64_SND_SEQ_BEEP, SND_P1                           ; 0C90
        SALTA   SND_P1, $30
        ENTRADA snd_play_music_if_idle, D64_SND_SEQ_MUSIC, SND_P0                 ; 0C77
        lda     #SND_P0
        bne     s_si_libre
```

| Canal | Sonidos |
|---|---|
| A | el espejo que se abre, las campanas de las horas y las de tercia |
| B | las puertas que se cierran y se abren, Severino, un objeto que se deja, un objeto que se coge |
| C | los pasos de Guillermo, el pitido de las frases y la música (que solo empieza si el canal C está libre) |

## El AY en el SID

`plat_psg` recibe las escrituras de registros del AY y las traduce manteniendo exactos las notas y el ritmo: las mismas
frecuencias, y una voz del SID que se abre y se suelta en las mismas escrituras en las que el tono del AY empieza y
termina.  El timbre es el propio del SID:

[`src/c64/plataforma/psg.s`](../../../src/c64/plataforma/psg.s#L25-L49), líneas 25–49:

```asm
; Each AY channel is a SID voice (A -> voice 1, B -> 2, C -> 3).  The notes and their timing are the AY's: the
; same frequencies, a voice gated and released on the same register writes as the AY's tone starts and stops; the
; voicing is the SID's (c64/optimizacion/sid/NOTAS.md):
;   tone period P (registers 0-5; the coarse byte, written after the fine one, makes the change: the game
;     always writes both, fine first) -> SID frequency 2^24 * (1 MHz / 16 P) / 985248 = 1064277 / P: P in
;     128-255 from a table of 129 values (65 stored, the odd ones the mean of their neighbours), P < 128 by
;     P << k into that range, P >= 256 by P >> s rounded (within 7 cents); P < 17 -> $FFFF (3.9 kHz, the SID's
;     top; the AY goes higher);
;   noise period N (register 6, 0-31, 0 = 1): the AY's noise generator changes 62500 / N times a second; the
;     SID's noise waveform changes once every 2^20 / 985248 / F seconds, so F = 66517 / N = the tone frequency
;     of the period 16 N (the same table);
;   mixer (register 7, bit c clear: tone of channel c on; bit c + 3 clear: its noise on): noise on -> the SID's
;     noise waveform (with the tone too: the AY ANDs both, the SID cannot; the noise is what is heard), else
;     tone on -> triangle (a recorder; the footsteps: pulse), else the voice stops (its waveform 0: the 6581 lets a silent voice's running waveform
;     through; a release before it comes from the volume, below);
;   the pulse's width moves at each tone period written (the music's vibrato writes one every 4 ticks, the
;     footsteps every 2): a phase + PASO, its triangle t (0-255), the low byte of the width: $500 + t (31 % - 37.5 %)
;     on voice 3 (the music, the footsteps, the beep), $600 + t (37.5 % - 44 %) on voices 1 and 2 (the bells, the
;     objects); voice 3 sounds through the SID's low-pass filter (cut-off FILTRO, resonance 8): sid_inicial;
;   volume (registers 8-10, 0-15) -> the SID envelope's sustain level (the AY's logarithmic levels, MAME's
;     table, x 15, at least 1): attack 24 ms, decay 72 ms, release 72 ms (RATE: one rate, the SID's envelope delay bug
;     never comes in, a gate is heard at once); a lower volume lowers the sustain level (the SID decays to it), a
;     higher one gates the voice again (it rises to the top and decays to the new level), 0 releases it (the
;     waveform kept: the release fades the note out instead of the AY's cut);
;   registers 11-13 (the hardware envelope; the volume's bit 4) and 14-15 (ports): not used by the game (no
```

Los registros de tono son el camino más usado (se escribe un periodo casi en cada tick mientras suena algo), así que
`snd_channel_output` del juego llama directamente a `plat_psg_tono` con los dos bytes de un periodo, y la frecuencia sale
de una tabla de 129 valores, con desplazamientos para las demás octavas.

## Los pasos en el C64

En el CPC un paso ocupa el canal C toque lo que toque allí, así que andar corta la música, que vuelve a empezar desde el
principio cuando Guillermo lleva 50 fotogramas quieto.  En el C64 la música conserva su canal:

[`src/c64/juego_final/objetos_sonido.s`](../../../src/c64/juego_final/objetos_sonido.s#L1398-L1404), líneas 1398–1404:

```asm
; The C64 build only: the music keeps channel C.  On the CPC the footstep (Guillermo's,
; at 21DD) takes channel C whatever plays there, so walking cuts the music, which starts again from its beginning
; once Guillermo has stood still for 50 frames (3CEA).  Here a footstep while the music plays is not started, and
; the music ends at its end instead of starting again (its F9 at D64_SND_SEQ_MUSIC + 7Eh jumps back to its start:
; it never ends on its own on the CPC; that byte becomes FFh, the end, until the music starts again); then the
; footsteps come back.  If Guillermo stands still meanwhile, it loops as on the CPC.  The phrases' beep (t_frase)
; still takes channel C as on the CPC.  The SID plays the footstep softer (psg_paso, c64/plataforma/psg.s).
```

Además, los pasos suenan más flojos que los demás sonidos, a la mitad (`psg_paso`).

## Quitar los pasos o el sonido del texto

El menú de inicio deja quitar los pasos y el pitido de las frases.  No basta con no llamarlos: la música de espera se
repite sin fin, y lo único que la termina es justamente un paso (que la deja acabar al final de su vuelta) o el pitido
de una frase (que la corta).  Si se quitara la llamada, la música no pararía nunca.  Así que cuando una opción está
quitada, el cargador escribe `0Fh` sobre la única nota de la secuencia del paso o del pitido: un silencio de la misma
duración.  El juego toca la secuencia igual que siempre, con los mismos efectos en el canal C, pero sin que se oiga, y
su estado sigue siendo exactamente el del original:

[`src/c64/juego_final/objetos_sonido.s`](../../../src/c64/juego_final/objetos_sonido.s#L1410-L1416), líneas 1410–1416:

```asm
; The options menu's footsteps or text's sound off: the loaders write 0Fh over the one note of the footstep's or the
; beep's sequence (FB w, FA w, the note, its ticks, FFh), a rest as long (n & 0Fh = 0Fh, no noise byte).  The sequence
; still takes channel C as when it sounds: walking ends the music at its end, a phrase cuts it, only silent (a JSR
; taken away instead left the music looping for ever).  The loaders' tools check the notes (17h, 54h).
cinta_paso   = D64_SND_SEQ_FOOTSTEP + 6            ; 17h 04h
cinta_pitido = D64_SND_SEQ_BEEP + 6                ; 54h 0Ah
        .export cinta_paso, cinta_pitido
```

## La música

El juego tiene una sola melodía, para el canal C, que empieza cuando Guillermo se queda quieto y se repite.  Los
pergaminos de la presentación y del final tienen sus propias melodías, tocadas por un reproductor del mismo tipo en el
programa de presentación (`src/c64/pergamino/musica.s`, ver [Presentación y final](Pergaminos.md)), con las mismas
escrituras de registros que el CPC, comprobadas una a una contra el original.

En el C128 y en el P500, en completas, el juego toca además el **Ave María** de la versión de PC: una voz digitalizada
de 13,45 s que suena a través del registro de volumen del SID (ver [El Commodore 128](Commodore-128.md)).
