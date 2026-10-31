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

{{code src/c64/juego_final/logica_a.s | ^; 4B71 hud_say_now | ^\.endproc}}

{{code src/c64/juego_final/logica_a.s | ^; 4B7C hud_say: | +3}}

## The scroller

The phrase scrolls in the 300 Hz interrupt: every 45 ticks the strip moves left by one character's width and the
next letter is drawn at its right end, with a beep in the speaker's voice.  Since the scroll belongs to the interrupt,
the phrase goes on while the frame draws, as on the CPC:

{{code src/c64/juego_final/estado_texto.s | ^; 368A txt_phrase_tick | ^\.ifdef PRUEBA}}

On the C64 a CPC character is 2 bytes wide (8 CPC pixels = 4 multicolour pixels): one bitmap byte.  The glyphs are
the CPC font's halved to 4 pixels (two glyph rows a byte; the N retouched by hand); the letters of a phrase are drawn
inverted:

{{code src/c64/juego_final/estado_texto.s | ^; 3649 txt_draw_char_inverted | +4}}

## The rest of the score bar

* **The hour's name** scrolls into its box in 9 steps when the hour changes (`hud_scroll_hour_name`); the names are 7
  characters each (*NOCHE*, *PRIMA*, *TERCIA*, *SEXTA*, *NONA*, *VÍSPERAS*, *COMPLETAS*: the last two written to fit).
* **The day's numeral** is three glyphs from a small table (blank, V, I) per day: I, II, III, IV, V, VI, VII.
* **The object slots** show what Guillermo holds, drawn from the objects' own sprites:

{{code src/c64/juego_final/logica_b.s | ^; 4D30 hud_draw_objects | +4}}

* **The obsequium bar**: 8 bytes, a quarter-step of the bar per point (see [The abbey as a game](The-abbey.md)).

## Languages

The Commodore releases are in Spanish and English, chosen in the start menu.  The English game is the Spanish one with
a different dictionary and phrases (the same 56 phrases, the same voices, translated into British English to fit the
same bytes), the hour names (*NIGHT*, *PRIME*, *TERCE*, *SEXT*, *NONES*, *VESPERS*, *COMPLIN*), *Day* on the score bar,
a real W in the font, Y:N for Adso's question, and the end screen's lines: the generator is
`src/c64/ingles/genera_ram_en.py`, from `src/c64/ingles/frases_en.txt`.  The tape carries the English bytes as a
separate block, read only when English is chosen.  Phrase 0, the mirror's Latin riddle, is the same in both.
