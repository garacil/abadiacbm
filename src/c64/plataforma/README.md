# abadia64ks: the Commodore 64 platform layer (6502, ca65)

The game's hardware accesses are `JSR`s to the platform calls (`src/c64/CODIGO6502.md`, "The platform calls");
this directory has the C64's (the checked build has mirrors instead: `src/c64/juego/plataforma_prueba.s`).  The
memory map they work in: `src/c64/MAPA.md` ($01 = $35, VIC bank 3, screen RAM $C000, bitmap $E000, the cells
outside columns 4-35 of rows 0-23 black: their bitmap bytes are data).

| File | Calls |
|---|---|
| `plat64.inc` | the hardware addresses and constants (the tick, the game's cells, the KERNAL's entries) |
| `tinta.s` | `plat_tinta` |
| `teclado.s` | `plat_teclado_fila` (the map: `TECLADO.md`) |
| `psg.s` | `plat_psg`, `psg_inicio`, `psg_paso` (the footstep's voicing; part of it in segment BAJO, $079D-$07FF) |
| `interrupcion.s` | `plat_inicio`, `plat_irq` (the 300 Hz interrupt, which calls the game's `sys_tick`), `plat_nmi`, `plat_di`, `plat_ei`, `plat_crtc`, `plat_modo`, `plat_aleatorio` |
| `disco.s` | `plat_disco_guarda`, `plat_disco_carga`, `plat_final`; `plat_ranura`, `plat_unidad` |
| `pruebas/` | the tests (below) |
| `pantalla.s`, `prueba_pantalla.*`, `tabla_pantalla.inc`, `captura_pantalla.png` | the first display test (CPC screen bytes -> the bitmap, room 16h; from the parchment work, VIC bank 2) |

The sources assemble with plain `ca65` (no target: the strings the KERNAL sees are written as PETSCII bytes),
with `-I src/c64/juego` for `zp.inc`; they import `sys_tick` (the game's 2899h) and export the calls.  Segments
CODE, RODATA, DATA, BSS (the game's `juego.cfg` places them in the code area); no zero page of their own.

## The calls

All need the I/O visible ($01 = $35, the game's normal state) except `plat_di` / `plat_ei`; the interrupt
handler sets it itself.  Cycles: JSR + routine + RTS, measured on the C64 in VICE (`pruebas/prueba.py ciclos`
and `tinta`), the display blanked.

| Call | In | Out | Clobbers | Cycles | What it does on the C64 |
|---|---|---|---|---|---|
| `plat_tinta` | A = pen 0-16, X = C64 colour | | Y | pen 0/1: 4104, pen 2: 4559, pen 3: 28, border: 23, pens 4-15: 25 | pen 3 -> $D021; pen 0 / 1 -> the high / low nibble of the screen RAM of the 32 x 24 game cells; pen 2 -> their colour RAM; 16 -> $D020 |
| `plat_psg` | A = AY register, X = value | | Y | fine period 33; coarse 128 for the periods 128-255 (the game's, nearly always: from the table; 108 to a silent voice), 215-385 for the others (the conversion); volume 119-140; mixer 277-312 (67 unchanged); noise period 258 | the AY on the SID, voiced as the SID's (below) |
| `plat_teclado_fila` | A = row 0-9 | A = the row, active low | Y | row 0 (the scan): 401 with nothing down; rows 1-9: 21 | the CPC matrix from the C64's keyboard and joystick port 2 (`TECLADO.md`) |
| `plat_crtc` | A = register, X = value | | (nothing) | 12 | nothing (below) |
| `plat_modo` | A = mode | | (nothing) | 12 | nothing (mode 1 is the multicolour bitmap) |
| `plat_di`, `plat_ei` | | | nothing | 14 | SEI, CLI |
| `plat_aleatorio` | | A = a random byte | (flags) | 20 | CIA 1 timer A's low byte EOR the raster line (the Z80's LD A,R at 518Ah: the mirror's numeral) |
| `plat_inicio` | | | A, X, Y | once | the C64 as the game needs it; interrupts left off (below) |
| `plat_disco_guarda` | zhl = block, zde = length | C = 1: error | A, X, Y | seconds (6 blocks) | the saved game to `ABADIA64.BSn` (below) |
| `plat_disco_carga` | zhl = where, zde = length | C = 1: no file / error / other length | A, X, Y | seconds | loads it back |
| `plat_final` | | never returns | | ~45 s of disk | loads and runs the ending parchment `FINAL` |

### plat_tinta

The CPC's palette is global and no pixel is redrawn when an ink changes: every game cell gets the same byte, so
a pen change is a fill of 768 bytes, unrolled by rows (24 `STA abs,X` per column, 32 columns, ~4000 cycles;
the screen RAM and the colour RAM share the loop, its 24 operands switched by EOR $18 when the target changes,
~450 cycles).  The screen RAM byte holds pens 0 and 1: their colours are kept (`pen01`).  Pens 4-15 do
nothing (mode 1).  The game changes the palette at the start (black), at the hours of the day and night (5
calls: pens 3, 2, 1, 0, border: ~13 000 cycles, ~13 ms, once).

### plat_psg: the AY on the SID

Each AY channel is a SID voice (A, B, C -> 1, 2, 3); the state of each is kept, the SID written only when
something changes.  The notes and their timing are the AY's: the same frequencies, a voice gated, struck again and
released on the same register writes as before the SID voicing (`pruebas/prueba.py sid`, below); the voicing is the
SID's (a SID touch; src/c64/optimizacion/sid/NOTAS.md): pulse waves whose width moves, one
voice through the SID's resonant filter, envelope rates of the SID's, releases.

* Tone period P (registers 0-5): SID frequency = 2^24 x (1 MHz / 16 P) / 985248 = 1064277 / P (PAL).  P in
  128-255 from a table of 1064277 / m (65 values for the even m, the odd ones the mean of their neighbours:
  130 bytes, exact to 0.2 cents); P < 128 shifted up into that range (exact), P >= 256 shifted down with
  rounding (within 7 cents); P < 17 -> $FFFF (3.9 kHz, the SID's top).  The conversion runs at the coarse
  byte's write (the game writes the fine byte first, always both): 150-330 cycles (P < 128, the music's and the
  beep's periods, through a short entry, `convierte_bajo`).
* Noise period N (register 6): the AY's noise changes 62500 / N times a second; the SID's noise waveform
  changes 0.9396 F times a second, so F = 66517 / N = the tone frequency of the period 16 N (the same routine).
* Mixer (register 7): noise on (with or without the tone) -> the SID's noise waveform at the noise's frequency;
  tone on -> pulse; neither -> the voice stops (its waveform 0, gated or not: a 6581 lets the tone of a voice at
  the envelope's zero through, ~35 dB down, while its waveform runs; VICE's 6581 does too: the old player left the
  last note of a voice released by its volume humming until the voice played again).  The
  AY's tone AND noise cannot be made on one SID voice (a combined waveform with noise locks the SID's noise
  generator): the noise is what is heard.  The game uses it in the doors, the mirror and Severino's death
  (notes 8xh of its sequences: the tone there is a period of ~3400, 18 Hz, gating the noise).
* The pulse's width: its low byte moves at each tone period written (the music's vibrato writes one every 4
  ticks, the footsteps every 2, the beep every tick): a phase + 3, its triangle t (0-255), the width $500 + t
  (31-37.5 %) on voice 3 (the music, the footsteps, the beep: the width sweeps through the 3rd harmonic's null)
  and $600 + t (37.5-44 %) on voices 1 and 2 (the bells, the objects); a turn of the music's in ~1.1 s.  Voice 3
  sounds through the SID's low-pass filter, resonance 8, cut-off $50 (bits 3-10: ~3 kHz on a 6581, ~5 on an 8580:
  it rounds the music's and the beep's top off, the footsteps a thud).  All set by `psg_inicio`'s table
  `sid_inicial` (the 25 SID registers).
* Volume (registers 8-10) -> the SID envelope's sustain level: the AY's logarithmic level (MAME's table) x 15,
  at least 1 (0, 1, 1, 1, 1, 1, 1, 2, 3, 4, 5, 7, 9, 10, 13, 15); attack 8 ms, decay 24 ms, release 24 ms (one
  rate for all three: the SID's envelope delay, its rate counter overrunning a faster rate's period for up to
  33 ms, never comes in, so a gate is heard on its tick; with rate 0 for the attack and a longer release the
  notes would start up to 33 ms late).  A lower volume lowers the sustain level (the SID decays to it); a higher
  one gates the voice again (it rises to the top and decays to the new level: the only way up on the SID); 0
  releases it with its waveform kept (the release fades the note out in 24 ms, where the AY cut it).
* Registers 11-13 (the hardware envelope, volume bit 4) and 14-15: ignored.  The game's sound data never uses
  the hardware envelope (no volume envelope of 0F76h's sequences has an 8xh entry).
* Registers 6-15 run with the interrupts off (PHP / SEI / PLP): they are written from the interrupt
  (snd_interrupt) and from the main code (snd_silence_all, the pause, the tape menu: the mixer).  The tone
  registers 0-5 do not: the game writes them only from the interrupt (snd_channel_output), the hot path (a
  period nearly every tick while a sound plays), so the fine byte is only stored and the coarse one, for the
  periods 128-255, is a table lookup straight into the channel's frequency; a write of them from the main code
  would have to come with the interrupts off.
* `psg_inicio` clears the whole state (BSS, which the game's loader does not load): the tone and noise
  frequencies too, so a voice switched on before its period is written (the game never does it: its periods
  and noise period are always written before the mixer that turns them on) starts at frequency 0, not at
  leftovers.
* `psg_paso` (the footsteps at half): the game's sound (objetos_sonido.s, s_canal_c) calls it
  at every start on channel C, Z = 1 for the footstep.  The footstep's volume rises 0 -> 12 a step a tick and falls
  back: gated again at each rise, voice 3 stayed at the attack's top all the rise.  As the footstep it is released
  at its start and gated once at its first volume with the sustain level 4: no gate again on the rises, half the
  usual sustain level on the falls (`paso_c`); the rates unchanged (the envelope delay bug).  Checked in VICE by
  src/c64/juego_final/vice/pasos.py: voice 3's envelope computed from VICE's dump of the SID writes, its RMS over the
  footstep against the earlier voicing.

### plat_inicio and the 300 Hz interrupt

`plat_inicio` (call it first, with the stack set: the game's entry `LDX #$FF / TXS / JSR plat_inicio`):
$01 = $35; CIA 1 and 2 interrupts off, the VIC-II's off, sprites off; the IRQ vector $FFFE -> `plat_irq`, the
NMI and RESET vectors -> `plat_nmi` (an RTI: the RESTORE key does nothing); CIA 1's ports for the keyboard;
VIC bank 3, bitmap $E000, screen RAM $C000, multicolour; border and background black, the whole screen RAM and
colour RAM black (the game's palette then fills its cells); the SID at rest; CIA 1 timer A every **3279
cycles**: the CPC's interrupt (52 lines of 64 us = 3328 us, 300.48 Hz; 985248 / 300 would be 3284, 0.16 %
slower than the CPC), its interrupt the only one.  The interrupts stay off: the game's EI (2178h) lets them in.
161 bytes, run once (it could live in memory the game reuses later).

`plat_irq`: PHA, $01 pushed, $01 = $35, CLD, CIA 1 acknowledged, `JSR sys_tick` (the game's 2899h), $01 / A
back, RTI.  X and Y are the game's sys_tick's to keep (it saves them only on its paths that use them: the sound
when a channel plays, a character of a phrase), the flags come back with the RTI.  On the C64 the I flag is set
from the interrupt's entry to the RTI (the checked build's sys_tick keeps the EI, the IFF mirror the host compares),
but while the phrase scroller draws a character: after its beep starts, a CLI as the Z80's EI there (snd_start's),
since the character takes up to ~9600 cycles (nearly three ticks the music lost before); a tick that
falls due then comes nested, once, and this handler keeps its own A and $01 on the stack.  **56 cycles of its own** per interrupt (measured, as
counted: the IRQ sequence, the handler, the JSR and the RTS; 78 when it kept X and Y itself): 16 800 cycles a
second, 1.7 % of the C64.  The game's work in sys_tick comes on top: 53 cycles when there is nothing to do (no
channel playing, no character due: the tests are inline in sys_tick).  A BRK would come here too (the game has
none).

### plat_crtc, plat_modo: nothing

The game programs the CRTC only for the geometry of its screen: R1 = 20h, R2 = 2Bh, R6 = 18h (32 x 24
characters: the 256 x 192 picture) at every new game (20C8h, vid_set_crtc 1E6Eh), and back to the standard
screen in the developers' exit (1E63h), never reached.  It sets mode 1 once (3568h).  On the C64 the picture's
geometry is fixed by `plat_inicio` (the game's cells 4-35 of rows 0-23, the rest black, as the CPC's border):
both calls are an RTS (12 cycles with the JSR).

### The disk: plat_disco_guarda, plat_disco_carga, plat_final

The CPC saved one game on tape (CTRL + TAB, then S or L: 1500 bytes from 7F80h, the tape menu 31DFh); the C64
saves it on the disk as `ABADIA64.BSn`, n = `plat_ranura` (the last digit key pressed, "1" at first:
`TECLADO.md`), on drive `plat_unidad` (8; the loader may store the drive it loaded from).  A save scratches the
old file first (`S0:`), then SAVEs the block; a load LOADs it at the block's address and checks its length.
The game's 6502 tape menu calls them in place of its tape blocks (with the interrupts off, as there).

The KERNAL is switched in only for the call ($01 = $36: the KERNAL and the I/O; $A000-$BFFF stays RAM, the
data there readable), and it needs the zero page and pages 2-3, which the game uses (`src/c64/NOTAS_MAPA.md`,
question 1).  The KERNAL's part of them is put aside and given the values it starts with:

| Area | Bytes | Put aside, then |
|---|---|---|
| $90-$FF | 112 | cleared: the KERNAL's status, file, serial and message variables at rest (messages off) |
| $0314-$0333 | 32 | the KERNAL ROM's vectors (copied from $FD30: RESTOR would also write the RAM under $FD30, a piece of the bitmap's row 23); NMI -> an RTI; IRQ -> an acknowledge |
| $0259-$0276 | 30 | (the file tables: OPEN writes entry 0) |
| $02A1 | 1 | cleared (the RS-232 flags: the serial LISTEN waits while bits 0-1 are set) |

**Where:** $0100-$01AE, the bottom of the stack page: at the tape menu the stack is shallow, and the calls with
the KERNAL went down to $01F1 (15 bytes from $01FF) in the test, far above it.  No other memory is free then
(the block itself is in the path scratch; the tile buffer must survive a save).  CIA 1's timer A interrupt
is off during the call (the KERNAL's serial code polls CIA 1 itself; its CLIs then let nothing in) and back
after it; no tick is delivered meanwhile, as during the CPC's tape operations.  The VIC bank and the screen
stay as the game has them (the serial code keeps $DD00's bits 0-1).

`plat_final`: the game is over, so everything may go.  It silences the SID, copies a 93-byte stub to $C400
(the tile merge tables, free now, out of the way of the load, RAMTAS and CINT) and runs it: the KERNAL's
variables at rest as above, LOAD "FINAL",unit,1 (the cc65 program `src/c64/pergamino/final.prg`, $0801-$5117: the
game's screen stays while it loads, ~45 s at the 1541's speed), then the machine as after a reset without BASIC
(IOINIT, RAMTAS, RESTOR, CINT, CLRCHN: the ending expects the KERNAL's interrupt chain and screen editor),
CLI, JMP $080D.  A load error flashes the border and tries again.

## Tests (`pruebas/`)

`python3 -I pruebas/prueba.py [tamanos] [tinta] [teclado] [ciclos] [disco] [psg] [sid]` (no argument: all; ~6
minutes, the sound recordings in real time; `tamanos` prints the sizes below) builds each test
program (`t_*.s` + the whole platform layer, `pruebas.cfg`: a PRG at $0801 with `10 SYS 2061`) into
`pruebas/obj/`, runs it in VICE (x64sc) on Xvfb :99 and writes pictures, recordings and logs into
`pruebas/resultados/`.  VICE is driven through its binary monitor (`vice_mb.py`: checkpoints, memory, the
display buffer as a PNG, snapshots), only while the emulation is stopped, so the results depend on emulated
cycles alone (VICE's random autostart delay off, its random seed fixed: two runs give the same numbers).
Inputs (keys, joystick) are set in a snapshot of the machine (VICE's KEYBOARD and JOYSTICK0 modules) at a barrier of the test program (`label: JMP label`), restored, and the program moved past it.

| Test | What | Result |
|---|---|---|
| `tinta` | room 16h with the score bar (`pantalla_prueba.py`: the CPC screen converted as `src/c64/MAPA.md` says, the invisible bytes full of random data) under the black, day and night palettes as vid_set_palette sets them, and a test palette (pen 3 red, border green); the cycles of each pen | `resultados/tinta_*.png`; in every game palette the game's cells show exactly its 4 colours and everything else (the 4 + 4 data columns, row 24, the border) is black; the test palette shows $D021 in the data cells' 00 pairs and $D020 |
| `teclado` | every C64 key alone, SHIFT + CRSR, Q + R, Q A O P alone and with each other, CTRL + `<-`, the joystick's 5 bits and some together, joystick + keys of its own columns, digits -> slot: the 10 rows read as sys_read_keyboard reads them (X kept) against `teclado_mapa.py` (the map written by key names) | 94 of 94 |
| `ciclos` | the 300 Hz interrupt's cost (a loop timed with CIA 2's cascaded timers, the interrupts off and on), its period, an NMI (CIA 2 timer A, as the RESTORE key), each call's cycles | 56 cycles per interrupt, 3279 cycles apart; the NMI returns; the table above |
| `disco` | `ABADIA64.BS3` saved and loaded with drive 8 (true drive emulation), the zero page and $0200-$03FF full of a pattern compared byte by byte around each call, a slot with no file, a second save over the first, the interrupt after it, the stack's depth; the file read back with c1541; `plat_final` with "FINAL" on the disk (warp, a fixed cycle count, VICE's picture) | all as expected: 0 bytes changed, C as said, the file's 1500 bytes and load address $9CCD; `resultados/disco_final.png` (the ending parchment) |
| `sid` | (no VICE) `plat_psg` against `psg_referencia.s` (the player before the SID voicing: the AY as it is, pulse 50 %, envelope rates 0) on sim65's core (`sid_igual.c`, a copy of src/juego/m6502 with `memoria_gancho.h`, a write hook): for every write, each voice's gate changes during the call (a note started, struck again, stopped), and after it the gate and, while gated, the frequency and the waveform's kind (tone or noise); A, X, the I flag kept; from memory full of $A5 the same SID writes.  Streams: every period of every channel with the tone on, off and with the noise, every noise period and volume; 400 000 random writes; the gallery; the session azar1 | 868 145 calls, 95 761 gate changes: the same |
| `psg` | the game's AY writes played by the interrupt through `plat_psg` (`t_psg.s`, the stream of `secuencia_ay.py`), recorded from VICE (`-sounddev wav`, in real time: VICE's wav device does not record in warp mode); two logs: the GNU build's session azar1 (`abadia64ks-puro --ay`, its first 20 s) and `galeria_ay` (every sound of the game from start to end by the game's own sequencer, src/juego/f_objetos_sonido.c: footstep, objects, beep, doors, mirror, Severino, bells, 12 s of music: the noise is only there); compared with `tools/compara_audio.py` against the log and against the GNU build's synthesis of the same log (`galeria_ay --sintetiza`, a copy of src/juego/gnu/abadia64ks.c's, checked sample for sample against its `--wav`) | see "The sound check" |

### The sound check

| Log | Tone windows agreeing with the AY's notes: C64 (GNU synthesis) | Noise windows sounding as noise: C64 (GNU) | Loudness correlation with the GNU synthesis |
|---|---|---|---|
| azar1, 20 s (10608 writes) | 81.3-82.4 % (78.0 %) | (none) | 0.831-0.838 |
| gallery, 31 s (6273 writes) | 98.9-99.1 % (91.0 %) | 100 % (100 %) | 0.928-0.932 |
| (the intro parchment's music, src/c64/pergamino, before) | 95.7 % | | |

(Ranges of recordings: VICE's audio is not bit-exact between runs, below.  Before the SID voicing: azar1 75.9-81.3 %,
0.838-0.905; the gallery 94.1-99.1 %, 98.7-100 %, 0.956-0.965.)

The tone measure's ceiling is the GNU synthesis's own score on the same log (two channels at once, the
strongest peak a harmonic, notes changing inside a 50 ms window: azar1 is mostly footsteps, pitch sweeps of a
period step every 2 ticks): the C64 is within 2 points of it, or above.  The loudness correlation (RMS about
the mean of 50 ms windows) is lower in azar1 because of the footsteps: a volume that rises by one step a tick
gates the SID voice again at each step (the overshoot above), and with the SID's envelope rates (attack 8 ms,
decay 24 ms) the footstep reaches its top sooner and leaves it later than the AY's ramp.  VICE's wav device
starts at a moment of the host's: two recordings differ by milliseconds of offset and their resampling phase, so
the comparisons align
on the first note (the test waits a second first, and `--salta 0.5` skips the click of the SID's volume
register).  `resultados/psg_*_c64.wav` (the C64) and `psg_*_gnu.wav` (the GNU synthesis) are there to listen to.
`compara_audio.py` got for this (its old use unchanged: the parchment still 424 of 443): `--hz` (logs in ticks),
32-bit float WAVs, the noise windows (spectral flatness above 0.03: the SID's and the synthesis's tones stay
below it in 99 % / 97 % of their windows), `--salta`, and `--referencia` (the loudness correlation).

## Sizes (bytes)

| Module | CODE | RODATA | DATA | BSS | Total |
|---|---|---|---|---|---|
| `tinta.s` | 160 (`plat_tinta`) | | 2 | | 162 |
| `teclado.s` | 228 (`plat_teclado_fila` 18, `escanea` 156 with the Q rule, `aplica` 54) | 72 (the key map 64, masks 8) | | 16 | 316 |
| `psg.s` | 586 (`otros` 108, `plat_psg` 145, `actualiza` 61, `pon_volumen` 57, `suelta` 25, `pon_frecuencia` 34, `convierte_bajo` / `convierte` 88, `tabla` 41, `psg_inicio` 27) | 180 (the frequency table 130, the SID's registers at rest 25, volumes 16, voices and mixer bits 9) | | 28 | 794 |
| `interrupcion.s` | 193 (`plat_inicio` 161, `plat_irq` 19, `plat_nmi` 1, `plat_di` 2, `plat_ei` 2, `plat_crtc` / `plat_modo` 1, `plat_aleatorio` 7) | | | | 193 |
| `disco.s` | 309 (`plat_disco_guarda` 51, `plat_disco_carga` 40, `fin_bloque` 12, `pon_nombre` 19, `kernal_entra` 94, `irq_kernal` 6, `kernal_sale` 56, `plat_final` 31) | 93 (the ending's stub) | 16 (the names, slot, unit) | 1 | 419 |
| **all** | **1476** | **345** | **18** | **45** | **1884** |

Room to give back if the code does not fit: `plat_inicio` and `psg_inicio` (188, and `sid_inicial`'s 25) run once
and could live in memory the game reuses after its start-up; the key map (64) and the frequency table (2 x 65) fit
the bitmap's invisible 64-byte pieces (`src/c64/MAPA.md`); the ending's stub (93) could be read from anywhere.

## Open issues

* The checked build's mirrors (`src/c64/juego/plataforma_prueba.s`) leave A = X in `plat_tinta` / `plat_psg` /
  `plat_crtc` (`TAY / TXA`), while the interface (and these calls) keep A: a routine that relies on A after
  them works on the C64 and is not caught by the host, or the other way round.  The mirrors have no
  `plat_aleatorio` nor the disk calls yet.
* Done: the game's entry (src/c64/juego_final/principal.s, principal_inicio) calls `plat_inicio` first,
  its tape menu (31DFh) calls `plat_disco_guarda` / `plat_disco_carga` and its end `plat_final`; the loader
  (src/c64/pergamino/cargador.s) stores the drive it loaded from ($BA) in `plat_unidad`.
* PAL only: the tick (3279 cycles) and the frequency table assume 985248 Hz (an NTSC C64 would play 3.8 %
  sharp and tick 3.8 % fast).
* The loading of the ending takes ~49 s at the 1541's KERNAL speed (the first stage ~54 s, the game's
  compressed stream ~125 s: src/c64/cinta/FLUJO.md); the CPC's tape took 82 s, 82 s and 502 s.
* The volume's rises gate the SID voice again (an overshoot of a few ms at each step); the SID has no other
  way up.  Heard in the footsteps' attack.
* A tone turned off by the mixer stops at once (its waveform 0), as the AY's: a release there would leave the
  voice's waveform running after it, which a 6581 lets through (~35 dB down) until the voice plays again, and the
  game has no tick of the platform's to stop it later without a cost in every interrupt.  The releases come from
  the volume going to 0 (the footsteps, the doors closing, the mirror, Severino, the bells' and the music's last
  notes).
* VICE's audio recording is not bit-exact between runs (host-timed start); the program and the comparisons are.
