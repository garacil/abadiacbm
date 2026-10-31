<!-- Made by tools/wiki.py from doc/wiki/fuentes/Sound.md: edit the template, not this page. -->
# Sound

[Home](Home.md) · previous: [Text and the score bar](Text.md) · next: [The Commodore 64 platform](Platform-C64.md)

The CPC's sound chip is the AY-3-8912: three square-wave channels and a noise generator.  The game drives it from the
300 Hz interrupt with a small **sequencer**; on the Commodores the same sequencer runs unchanged, and the platform
layer plays its register writes on the SID.

## The sequencer

Each of the three channels plays a **sequence**: notes (a pitch and a length in ticks), rests, noise, and commands
(jump, start a sequence on channel B or C, set the tone or the volume **envelope**).  Once per interrupt, every playing
channel advances; at each tempo tick a finished note gives way to the next byte:

[`src/c64/juego_final/objetos_sonido.s`](../../src/c64/juego_final/objetos_sonido.s#L971-L978), lines 971–978:

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

A note's period comes from a table of 16 periods shifted by the octave; the envelopes then move the volume and the
pitch every tick (the music's vibrato).  The game starts its sounds through small **triggers** (`snd_play_footstep`,
`snd_play_door_open`, `snd_play_hour_bells`, `snd_play_music_if_idle`...), each a sequence on a fixed channel: the
bells and the objects on A and B, the footsteps, the phrases' beep and the music on C.

## The AY on the SID

`plat_psg` receives the AY's register writes and translates them, keeping the notes and the timing exact: the same
frequencies, a SID voice gated and released on the same writes where the AY's tone starts and stops.  The voicing is
the SID's own:

[`src/c64/plataforma/psg.s`](../../src/c64/plataforma/psg.s#L25-L49), lines 25–49:

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

The tone registers are the hot path (a period written nearly every tick while a sound plays), so the game's
`snd_channel_output` calls `plat_psg_tono` directly with both bytes of a period, and the frequency comes from a table
of 129 values, with shifts for the other octaves.

## The C64's footsteps

On the CPC a footstep takes channel C whatever plays there, so walking cuts the music, which starts again from the
beginning after Guillermo stands still for 50 frames.  On the C64 the music keeps its channel:

[`src/c64/juego_final/objetos_sonido.s`](../../src/c64/juego_final/objetos_sonido.s#L1398-L1404), lines 1398–1404:

```asm
; The C64 build only: the music keeps channel C.  On the CPC the footstep (Guillermo's,
; at 21DD) takes channel C whatever plays there, so walking cuts the music, which starts again from its beginning
; once Guillermo has stood still for 50 frames (3CEA).  Here a footstep while the music plays is not started, and
; the music ends at its end instead of starting again (its F9 at D64_SND_SEQ_MUSIC + 7Eh jumps back to its start:
; it never ends on its own on the CPC; that byte becomes FFh, the end, until the music starts again); then the
; footsteps come back.  If Guillermo stands still meanwhile, it loops as on the CPC.  The phrases' beep (t_frase)
; still takes channel C as on the CPC.  The SID plays the footstep softer (psg_paso, c64/plataforma/psg.s).
```

The footsteps are also played softer than the other sounds, at half their loudness (`psg_paso`), and the start menu can
turn them off: then the one note of the footstep's sequence becomes a rest of the same length (`0Fh`, written by the
loader at `cinta_paso`), so the game still plays it on channel C (walking still ends the music) and its state stays
exactly the original's, silent.  The phrases' beep is turned off the same way (`cinta_pitido`): it still cuts the
music.  (Taking the call away instead left the music looping for ever: nothing else ends it.)

## The music

The game has one tune, a melody for channel C that starts when Guillermo stands still and loops.  The parchments of the
introduction and the ending have their own tunes, played by the same kind of player in the
presentation program (`src/c64/pergamino/musica.s`, see [Presentation and ending](Parchments.md)), with the same
register writes as the CPC's, checked one by one against the original.

On the C128, at completas, the game also plays the **Ave María** of the PC version: a digitised voice of 13.45 s, played
through the SID's volume register (see [The Commodore 128](C128.md)).
