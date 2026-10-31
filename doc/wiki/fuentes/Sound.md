# Sound

[Home](Home.md) · previous: [Text and the score bar](Text.md) · next: [The Commodore 64 platform](Platform-C64.md)

The CPC's sound chip is the AY-3-8912: three square-wave channels and a noise generator.  The game drives it from the
300 Hz interrupt with a small **sequencer**; on the Commodores the same sequencer runs unchanged, and the platform
layer plays its register writes on the SID.

## The sequencer

Each of the three channels plays a **sequence**: notes (a pitch and a length in ticks), rests, noise, and commands
(jump, start a sequence on channel B or C, set the tone or the volume **envelope**).  Once per interrupt, every playing
channel advances; at each tempo tick a finished note gives way to the next byte:

{{code src/c64/juego_final/objetos_sonido.s | ^; 0DBC snd_channel_tick | +8}}

A note's period comes from a table of 16 periods shifted by the octave; the envelopes then move the volume and the
pitch every tick (the music's vibrato).  The game starts its sounds through small **triggers** (`snd_play_footstep`,
`snd_play_door_open`, `snd_play_hour_bells`, `snd_play_music_if_idle`...), each a sequence on a fixed channel: the
bells and the objects on A and B, the footsteps, the phrases' beep and the music on C.

## The AY on the SID

`plat_psg` receives the AY's register writes and translates them, keeping the notes and the timing exact: the same
frequencies, a SID voice gated and released on the same writes where the AY's tone starts and stops.  The voicing is
the SID's own:

{{code src/c64/plataforma/psg.s | ^; Each AY channel is a SID voice | ^;   registers 11-13}}

The tone registers are the hot path (a period written nearly every tick while a sound plays), so the game's
`snd_channel_output` calls `plat_psg_tono` directly with both bytes of a period, and the frequency comes from a table
of 129 values, with shifts for the other octaves.

## The C64's footsteps

On the CPC a footstep takes channel C whatever plays there, so walking cuts the music, which starts again from the
beginning after Guillermo stands still for 50 frames.  On the C64 the music keeps its channel:

{{code src/c64/juego_final/objetos_sonido.s | ^; The C64 build only: the music keeps channel C | +7}}

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
