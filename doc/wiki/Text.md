<!-- Made by tools/wiki.py from doc/wiki/fuentes/Text.md: edit the template, not this page. -->
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

# Text and the score bar

[Home](Home.md) · previous: [Objects, doors and the mirror](Objects.md) · next: [Sound](Sound.md)

The bottom of the screen is the **score bar**: the day's numeral and the hour's name, the six object slots, the
obsequium bar, and a strip where the monks' phrases scroll from right to left.  On the C64 the score bar is part of the
bitmap image itself, already in place when the game loads.

## Words and phrases

The game stores no sentences: a **dictionary** of words (`TXT_WORDS`, the last letter of each with bit 7 set) and 56
**phrases** (`TXT_PHRASES`), each a list of word numbers ended by `FF`:

| Byte | Meaning |
|---|---|
| below F9h | word n, preceded by a space |
| `F9 n` | word n joined to the previous one (no space) |
| `FA`-`FE` | punctuation: ¿ ? ; . , |
| `FF` | the end of the phrase |

The font has no Ñ: the dictionary writes it as W, and the glyph of W is drawn as Ñ (the English version draws a real W).
Each phrase also has a **voice** byte (`TXT_PHRASE_SOUND`): the pitch of the beep that accompanies its letters, one per
speaker (the abbot, Adso, Malaquías, Berengario, Severino, Jorge, Bernardo, the manuscript).

## Saying a phrase

A script calls `hud_say` with the phrase number as an inline byte; the phrase starts unless another one is being shown
(`hud_say_now` interrupts the current one):

[`src/c64/juego_final/logica_a.s`](../../src/c64/juego_final/logica_a.s#L1119-L1132), lines 1119–1132:

```asm
; 4B71 hud_say_now: `JSR hud_say_now`, the phrase: a phrase with priority (busy and active cleared, the phrase
; line cleared), then falls into hud_say with the same inline byte.  Its DI is the checked build's only: with the
; phrase inactive the interrupt's t_frase draws nothing, and the C64 clearing the line took ~4800 cycles (a tick
; of the music lost); hud_say makes its own DI ... EI around what the interrupt reads.
.proc hud_say_now
.ifdef PRUEBA
        jsr     plat_di
.endif
        lda     #0
        sta     D64_TXT_PHRASE_BUSY
        sta     D64_TXT_PHRASE_ACTIVE
        jsr     hud_clear_phrase_area
        ; falls into hud_say
.endproc
```

[`src/c64/juego_final/logica_a.s`](../../src/c64/juego_final/logica_a.s#L1134-L1136), lines 1134–1136:

```asm
; 4B7C hud_say: `JSR hud_say`, the phrase: starts it unless one is shown (DI ... EI): its voice, busy = active =
; word done := 1, txt_phrase_ptr := the phrase, no trailing blanks.  Out: CF = 1 started (A = 0, B = 0,
; DE = the voice entry, HL = the phrase), CF = 0 busy (A = txt_phrase_busy).
```

## The scroller

The phrase scrolls in the 300 Hz interrupt: every 45 ticks the strip moves left by one character's width and the
next letter is drawn at its right end, with a beep in the speaker's voice.  Since the scroll belongs to the interrupt,
the phrase goes on while the frame draws, as on the CPC:

[`src/c64/juego_final/estado_texto.s`](../../src/c64/juego_final/estado_texto.s#L1517-L1526), lines 1517–1526:

```asm
; 368A txt_phrase_tick: the phrase scroller (300 Hz interrupt): every 2Dh-th call while a phrase is active, a
; beep and the next character (the next letter of the word; at its end a trailing blank or the next phrase byte:
; FFh the end, FA-FE punctuation, F9 nn word nn without a blank, else a blank and word n): the strip (lines
; A4h-ABh, CPC bytes 10h-2Fh) scrolls one C64 byte to the left and the character is drawn inverted at its right
; end.  Every Z80 register is kept.  The game's sys_tick makes the test (the counter + 1 = 2Dh) inline and calls
; t_frase; this entry (the Z80's, with its DI) is for the checks only.
; t_frase: the 2Dh-th tick: the counter to 0 and, while a phrase is active, the character.  X and Y kept (the
; C64's interrupt saves neither); the zero page it uses ($14-$1D: the word pointer in zp0, a flag in zt0,
; txt_draw_char's zt0-zt0+6 and zp0) and txt_cursor are saved and restored.
.ifdef PRUEBA
```

On the C64 a CPC character is 2 bytes wide (8 CPC pixels = 4 multicolour pixels): one bitmap byte.  The glyphs are
the CPC font's halved to 4 pixels (two glyph rows a byte; the N retouched by hand); the letters of a phrase are drawn
inverted:

[`src/c64/juego_final/estado_texto.s`](../../src/c64/juego_final/estado_texto.s#L1358-L1361), lines 1358–1361:

```asm
; 3649 txt_draw_char_inverted / 364D txt_draw_char: draws code A (bit 7 ignored; 20h the blank glyph, below
; 2Dh nothing, C set) at txt_cursor (x in CPC bytes, y in lines), opaque: a set pixel pen 3 and a clear one pen
; 2 (inverted: the other way round); a glyph at an odd x straddles two C64 bytes.  Then txt_cursor x += 2.
; Uses only zt0 and zp0 (it runs from the phrase scroller's interrupt too).
```

## The rest of the score bar

* **The hour's name** scrolls into its box in 9 steps when the hour changes (`hud_scroll_hour_name`); the names are 7
  characters each (*NOCHE*, *PRIMA*, *TERCIA*, *SEXTA*, *NONA*, *VÍSPERAS*, *COMPLETAS*: the last two written to fit).
* **The day's numeral** is three glyphs from a small table (blank, V, I) per day: I, II, III, IV, V, VI, VII.
* **The object slots** show what Guillermo holds, drawn from the objects' own sprites:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L834-L837), lines 834–837:

```asm
; 4D30 hud_draw_objects: the score bar's object slots whose bit is set in A (bit 7 slot 0 .. bit 2 slot 5),
; from C591h, 5 bytes apart and one more after the third: an object held (its bit in C) from its sprite (+5
; width & 7Fh, +6 rows, +7 graphics: objects under the I/O), else cleared (4 x 12 of 00h).  Stops when no bit
; of A is left.
```

* **The obsequium bar**: 8 bytes, a quarter-step of the bar per point (see [The abbey as a game](The-abbey.md)).

## Languages

The Commodore releases are in Spanish and English, chosen in the start menu.  The English game is the Spanish one with
a different dictionary and phrases (the same 56 phrases, the same voices, translated into British English to fit the
same bytes), the hour names (*NIGHT*, *PRIME*, *TERCE*, *SEXT*, *NONES*, *VESPERS*, *COMPLIN*), *Day* on the score bar,
a real W in the font, Y:N for Adso's question, and the end screen's lines: the generator is
`src/c64/ingles/genera_ram_en.py`, from `src/c64/ingles/frases_en.txt`.  The tape carries the English bytes as a
separate block, read only when English is chosen.  Phrase 0, the mirror's Latin riddle, is the same in both.
