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

# Presentation and ending

[Home](Home.md) · previous: [Loading: tape and disks](Loading.md) · next: [Building and certification](Building.md)

The game begins and ends with a **parchment**: a page of gothic writing that fills itself letter by letter, with
music.  On the Commodores these are separate programs, written in C with cc65 in September 2016 for this game (`abadia.c`,
`manuscrito.c`, `io.c` in `src/c64/presentacion/`), kept as they were with only the changes the releases needed
(`src/c64/presentacion/NOTAS.md` lists each one as a diff, with its reason).

## The introduction

`abadia.c` reads the loading picture first ("Loading"), then writes the introduction's parchment; a key ends it, the
music stops, and `gameload` puts the picture on the game's screen and starts the game's loader under it:

{{code src/c64/presentacion/abadia.c | ^int main\(void\) | ^\x7d}}

## Writing a parchment

`manusrun` reads the text — the CPC tape's own text, byte for byte, in the CPC's codes — and draws each glyph pixel by
pixel at the pace of the original; a capital letter is drawn in red, two pixels to the left; at the bottom of the page
it turns the page:

{{code src/c64/presentacion/manuscrito.c | ^void manusrun\(unsigned char \*text\) | ^				color = }}

The glyphs and the page's border are those of the CPC tape (`pp.bin`), plus four glyphs drawn in the font's style for
the credits (0, 6, @ and B).  The credits page comes after the original text: *version commodore: German Luis Aracil
Boned, garacilb@gmail.com, 2016 - 2026* (the font has no accents).

## The music

The parchments' tunes are the CPC tape's: its player was translated to 6502 (`src/c64/pergamino/musica.s`) and its
register writes go to the SID through the same voicing as the game's sound (`src/c64/presentacion/sid.s`), which also
scans the keyboard every fifth tick so that the C code's key tests work.  The writes are checked one by one against the
CPC's: 2828 identical writes over the introduction's first 64 seconds.

## The ending

At 100 % the game loads "FINAL": the same parchment code with the CPC's ending text, then the dedication to all of Opera
Soft's team, over and over, as the CPC did:

{{code src/c64/presentacion/final.c | ^/\* "final": the ending parchment | ^#include}}

## Both languages

The tape and the disks carry both languages' texts, glyphs and pictures inside the programs (the English parchments
are a translation made for this version, broken into lines with the glyphs' own widths and hyphenated by syllables:
`src/c64/ingles/pergamino_en.py`); the menu's language decides which are shown.

## The test disk

`src/c64/presentacion/pruebas/disco_prueba/` builds a disk with the presentation, the game and the ending, and checks it
in VICE: every page of both parchments against a model of the pages (which is itself checked against the CPC's
screen, page for page), the music's writes against the CPC's, the picture during the load, the game's memory at its
start, and the ending reached through the game's own code.  40 checks, all passing.
