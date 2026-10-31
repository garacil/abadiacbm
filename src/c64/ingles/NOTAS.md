# abadia64ks in British English (the C64 English release)

everything translated into English, a separate release for the C64 entirely in English, a d64 disk with
the same label and the suffix _english.d64, in British English, the text fitting where the Spanish did.

The Spanish build is untouched (`src/c64/disco/abadia64ks.d64` is byte for byte what it was).  The English release is made beside it:

    src/c64/ingles/construye.sh      ->  src/c64/disco/abadia64ks_english.d64      (disk header "abadia64ks,en")

It takes about two seconds.  Nothing is edited by hand: the English data, graphics and the four build trees
(`src/c64/plataforma_en`, `juego_final_en`, `presentacion_en`, `disco_en`: generated copies of the Spanish trees with exact, counted
replacements, `prepara_arbol.py`; safe to delete) are made from the sources in this directory.

## What is English

| What | How | Fit (the Spanish space) |
|---|---|---|
| the 56 phrases and their dictionary (the monks' speech, the abbot's, Adso's) | `frases_en.txt`, tokenised by `genera_ram_en.py` into the tape's own format (word tokens, `F9` glued pieces, `FA-FE` punctuation); the Latin phrase 0 of the mirror riddle is the tape's, byte for byte, and word 6 `AAA` stays at offset 1Eh where the mirror writes its numeral; the speaker byte of each phrase is untouched | words 1193 of 1257 bytes (235 of 239 words), phrases 748 of 924 bytes |
| the hour names in the score bar | NIGHT, PRIME, TERCE, SEXT, NONES, VESPERS, COMPLIN ("complin" is a recorded variant of compline: the field is 7 letters) | 7 x 7 bytes, as the Spanish |
| the letter W | the Spanish font draws W as N-tilde (the tape's words write the tilde as W); now a real W, the mirror image of M (3 x 7 C64 pixels) | the same 46 glyphs |
| the score bar's "Dia" | redrawn "Day" (`dia_en.py`) at the C64's resolution, in the original's two tones | the same bar |
| the end-of-game screen | YOU HAVE SOLVED / n PER CENT / OF THE INVESTIGATION / PRESS SPACE TO START / LOADING THE ENDING, centred on the same axis | the same lines and cursors |
| Adso's question | the score bar asks Y:N and the key **Y** gives yes (as **S** still does, and N no) | the key table, one byte |
| the introduction and ending parchments | `pergamino_intro_en.txt`, `pergamino_final_en.txt` (a fresh translation of the tape's Spanish text, not taken from any published English edition of the novel), broken into lines by `pergamino_en.py` with the glyphs' own widths and hyphenated by hand-marked syllables; credits and dedication in English | introduction text 7 pages (as the Spanish), ending 12 pages (as the Spanish); text1.bin 1452 bytes (Spanish 1491), text2.bin 2510 (2598); the malloc sizes re-derived |
| the glyphs the English text needs | capitals I, F, W and a real lower-case w, drawn in the parchment font's style (`glifos_en.py`); the tape's n-tilde glyph is dropped | the glyph block 2865 bytes (Spanish 2753): +112 in a heap with ~40 KB free |
| the loading picture's title | "The Abbey of Crime" (`titulo_en.py`) in the parchment's own blackletter, pink, brown and cyan; the monk, the skull, the book and OPERA soft untouched | the same 10000 bytes |
| the file names on the disk | abbey, abbey.koa, text1.bin, pp.bin, game, ending, text2.bin; save files ABBEY64.BSn | the loader and plat_final ask for GAME and ENDING |

The three-letter word for the "OBSEQUIUM" bar is Latin and stays; so do OPERA soft and the names of the authors.

## Names

Brother William (of Occam in the parchment), Adso, Jorge, Malachi, Berengar, Severinus, Venantius, Bernard Gui: the usual English forms
of the novel's names.  The game's Spanish "fray Guillermo" is "Brother William".

## Checked (VICE x64sc, true 1541 drive, Xvfb :99; `pruebas/prueba_en.py`, derived from `src/c64/presentacion/pruebas/disco_prueba/prueba.py`)

* the whole disk from `LOAD"*",8,1`: the introduction's nine pages are, on the emulated C64, exactly the page model made from the English
  files (0 bitmap bytes and 0 cell colours differ), its music is the CPC's (2828 AY writes); the picture, the loader reading GAME, the RAM
  equal to the image, the game's frames 50 and 200 equal to the image written straight into the RAM;
* the ending program loaded by name from the English disk (ENDING): its fourteen pages exactly as the model, its music as the CPC's;
* `pruebas/frase_en.py OUT N`: phrase N started in the running game as hud_say does and its strip captured every few frames (phrase 5,
  with the new W, "... THE MANUSCRIPT, BROTHER WILLIAM" scrolls as written);
* `pruebas/arranca_en.py`: the game from the image without the loader, screenshots at chosen frames.
All these checks passed (the whole-disk run, ending included, on the disk before the title and "Day" were added; the disk with them was
checked again up to the game's frame 200: the ending program is the same file in both).  Not run: the key Y (changed in the key table and read
from it, not tried in an emulator), the ending through the game's own code (the Spanish test's part C builds a memory state from the
Spanish game; here the ending program is loaded alone), a play through the game, the 56 phrases one by one on the screen.

## What still needs a visual review (drawn programmatically or by hand, not by the original artists)

the glyphs I F W w of the parchments, "Day" in the score bar, the title "The Abbey of Crime", the W of the font, and the translation itself
(a first pass: the register is the game's, capitals and no apostrophes, the voices of each character as in the Spanish).

## Rights

As the Spanish build: the game is Opera Soft's (Paco Menéndez, Juan Delcán); this port is Germán Luis Aracil Boned's, GPL 3 or
later for its code.  Whether the game may be distributed is a decision still to be made.
