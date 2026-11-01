<!-- Made by tools/wiki.py from doc/wiki/fuentes/The-abbey.md: edit the template, not this page. -->
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

# The abbey as a game

[Home](Home.md) · next: [From the Z80 to the 6502](From-Z80-to-6502.md)

This page explains what the program has to do: the rules of *La abadía del crimen* as the code implements them.  The
following pages explain how.

## The story in one paragraph

In 1327 Brother William of Occam (Guillermo in the game) and his novice Adso of Melk arrive at a Benedictine abbey in
northern Italy.  A monk, Venancio, has died; the abbot asks Guillermo to find the culprit before the inquisitor
Bernardo Gui arrives, and orders him to obey the rule of the abbey: to be at the offices in the church and at the meal
in the refectory, and to be in his cell at night.  More monks die during the seven days.  The secret is a forbidden
book hidden in the *finis Africae* of the library, a labyrinth on the top floor of the building, and the blind
venerable Jorge who guards it.

## The cast

The game has six character records; two of them are reused by other characters as the story goes on.

| Slot | Character | Controlled by |
|---|---|---|
| 0 | **Guillermo** (Brother William) | the player: turn left, turn right, advance |
| 1 | **Adso**, his novice | his own script: he follows Guillermo, and the player moves him with *down* |
| 2 | **Malaquías** (Malachi), the librarian | his script |
| 3 | **the Abbot** | his script |
| 4 | **Berengario** (Berengar), the assistant librarian; from day 3 the hooded monk, then **Bernardo Gui** | his script |
| 5 | **Severino** (Severinus), the herbalist; from day 6 **Jorge** | his script |

On the C64 the keys are those of the CPC game mapped onto the C64 keyboard (`src/c64/plataforma/teclado.s`): Q
(SHIFT + CRSR down, joystick up) advances, O and P (SHIFT + CRSR right and CRSR right, joystick left and right) turn,
A (CRSR down, the fire button) moves Adso, SPACE (joystick down) drops an object, INST/DEL pauses and CTRL + ← opens
the menu that saves or loads the game.

## Time: seven days of seven hours

The game counts **days** (1 to 7) and the canonical **hours** of the monastic day:

| Hour | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|---|
| Spanish (score bar) | NOCHE | PRIMA | TERCIA | SEXTA | NONA | VÍSPERAS | COMPLETAS |
| English | night | prime | terce | sext | none | vespers | compline |

A new game starts on day I at **nona** (the data `GAME_START_DAY` / `GAME_START_HOUR`, read by `ai_clock_init`).  An
hour ends in one of two ways:

* by **time**: some hours have a duration, counted in frames (see [The clock](Clock.md)); when it runs out the hour
  advances whatever Guillermo is doing;
* by the **story**: most hours end when a script decides, for example when every monk has reached the church and the
  abbot has said *OREMOS* ("let us pray"), or when Guillermo answers Adso's question *¿DORMIMOS?, MAESTRO* ("shall we
  sleep, master?") at night.

Each hour has its obligations.  At **prima** and **vísperas** the monks gather in the church; at **sexta** in the
refectory; at **completas** the abbot sends everyone to their cells; at **noche** Guillermo should sleep — or explore
the forbidden places while the abbey sleeps.  The abbot checks that Guillermo is at his exact place, facing the altar
or the table: if he arrives late or stands elsewhere he is reprimanded.

## The obsequium

The bar at the bottom right of the score bar is Guillermo's *obsequium* (obedience): 31 points at the start.  Every
reprimand of the abbot (or of Bernardo Gui) takes away 2; when it would go below 0, the abbot comes for Guillermo and
expels him from the abbey — the end of the game.  The only routine that changes it:

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L1697-L1727), lines 1697–1727:

```asm
; 5129 hud_obsequium_sub: `JSR hud_obsequium_sub / .byte n`: hud_obsequium -= n; below 0 it becomes 0 and, unless
; the game is over, ai_abbot_state := 0Bh (the abbot expels Guillermo); the bar (CDB4h): obsequium / 4 bytes
; 0Fh, one byte FFh >> (obsequium & 3) (the CPC's tail table 5180h), the rest of the 8 bytes FFh.
hud_obsequium_sub:
        pla                             ; the inline byte, and the return past it
        clc
        adc     #1
        sta     zp0
        pla
        adc     #0
        sta     zp0+1
        pha
        lda     zp0
        pha
        ldy     #0
        lda     D64_HUD_OBSEQUIUM
        sec
        sbc     (zp0),y
        bcs     :+
        lda     D64_GAME_GUILLERMO_DEAD
        bne     @cero
        lda     #$0B
        sta     D64_AI_ABBOT_STATE
@cero:  lda     #0
:       sta     D64_HUD_OBSEQUIUM
        and     #$03
        tax
        lda     #$FF
        cpx     #0
        beq     @cola
:       lsr     a
```

The caller writes the amount as an inline byte after the `JSR` (`JSR hud_obsequium_sub / .byte 2`), as the Z80
program did after its `CALL`: the routine pulls its return address, reads the byte and pushes the address past it.
At every start of a game the main loop calls it with 0 just to draw the bar.

## Objects

There are nine objects: the **book**, the **gloves**, the **glasses** (Guillermo's lenses), the **parchment**
(Venancio's manuscript), **key 1**, **key 2**, **key 3**, an unused slot, and the **lamp**.  Each character that can
hold objects has a *holder* entry with a mask of what he may take; an object is taken by walking into it, and dropped
with SPACE.  Guillermo starts with the glasses; Adso may take only the lamp and key 3.  Reading the parchment
with the glasses shows the Latin riddle of the mirror, with a numeral chosen at random for the game (see
[Objects, doors and the mirror](Objects.md)).  The lamp is needed in the library, which is dark: without it Adso
refuses to go on, and a light that runs out leaves them lost.

## How the game ends

Every end sets one flag, `GAME_GUILLERMO_DEAD`; the main loop then waits for the phrase on the score bar to finish and
shows the result:

* expelled by the abbot (the obsequium exhausted, disobedience, entering his cell, the library at the wrong time);
* lost in the dark library, or the lamp exhausted;
* the time is over: on day VII at tercia the abbot dismisses Guillermo;
* poisoned: Guillermo turns the pages of the book without the gloves;
* **solved**: Jorge eats the book in the finis Africae.

[`src/c64/juego_final/principal.s`](../../src/c64/juego_final/principal.s#L224-L240), lines 224–240:

```asm
; ---- 3E29 game_check_end: the end of a game ---------------------------------------------------------------------
; Nothing unless Guillermo is dead (37E4h) and no phrase is being shown; then the play area filled, the
; percentage computed and printed; at 100 % the ending (3EC6), else "PULSA ESPACIO PARA EMPEZAR", the wait
; for space and a new game (3EC2 POP HL / JP 20C7: the JSR's return address dropped).
.proc game_check_end
        lda     D64_GAME_GUILLERMO_DEAD         ; 3E29-3E2D
        bne     :+
        rts
:       lda     #$80                            ; 3E2E-3E30
        sta     D64_GAME_CAMERA_OTHER
        lda     D64_TXT_PHRASE_BUSY             ; 3E33-3E37
        beq     :+
        rts
:       jsr     vid_fill_play_area_ff           ; 3E38 CALL 16A1
        jsr     game_compute_percentage         ; 3E3B CALL 3DA8 (the digits into D64_GAME_PERCENT_DIGITS)
        lda     D64_GAME_PERCENT_DIGITS         ; the digits into this code's own copy of the text (3E61)
        sta     digitos
```

The percentage of the investigation is computed from the day, the hour and the *bonus* bits — one bit for each
discovery the game rewards (holding the gloves, the keys, reaching certain rooms...), 4 % each:

[`src/c64/juego_final/logica_a.s`](../../src/c64/juego_final/logica_a.s#L831-L895), lines 831–895:

```asm
; 3DA8 game_compute_percentage: "100" when the investigation is solved; else 7 (day - 1) + hour + 4 per bit of
; the word game_bonus2 (8-bit sum), 0 below 5; its digits go to game_percent_digits (' ', tens, units).
; Out: A = 20h (31h when solved), BC = units << 8 | tens (0), HL = 3030h + BC.
.proc game_compute_percentage
        lda     D64_GAME_INVESTIGATION_OPEN
        bne     calc
        sta     zbc
        sta     zbc+1
        lda     #$31
        bne     guarda                          ; (always)
calc:   lda     D64_GAME_DAY
        sec
        sbc     #1
        sta     zt0
        asl
        sta     zt0+1
        asl
        clc
        adc     zt0
        clc
        adc     zt0+1
        clc
        adc     D64_GAME_HOUR
        sta     zt0
        ldx     #1                      ; + 4 per bit of the word game_bonus2 (8 bits)
palabra:
        ldy     D64_GAME_BONUS2,x
unbit:  tya
        beq     :+
        asl
        tay
        bcc     unbit
        lda     zt0
        adc     #4 - 1                  ; (C set)
        sta     zt0
        jmp     unbit
:       dex
        bpl     palabra
        lda     zt0
        cmp     #5
        bcs     :+
        lda     #0
:       ldx     #0
:       cmp     #10
        bcc     :+
        sbc     #10
        inx
        bne     :-
:       sta     zbc+1                           ; B = units
        stx     zbc                             ; C = tens
        lda     #$20
guarda: sta     D64_GAME_PERCENT_DIGITS
        tax
        lda     zbc
        clc
        adc     #$30
        sta     zhl
        sta     D64_GAME_PERCENT_DIGITS+1
        lda     zbc+1
        adc     #$30
        sta     zhl+1
        sta     D64_GAME_PERCENT_DIGITS+2
        txa
        rts
.endproc
```

100 % (the investigation solved) loads the ending parchment from tape or disk ([Presentation and ending](Parchments.md));
anything else shows *HAS RESUELTO EL nn POR CIENTO DE LA INVESTIGACIÓN* and waits for SPACE to start again.

## The two Commodore games

| | abadia64ks (C64) | abadia128ks (C128) |
|---|---|---|
| game logic | the CPC 64 KiB tape version, translated routine by routine | the same 6502 code plus, under `-D COMPLETO`, every difference of the full game (CPC 6128 / PC) |
| map | 129 rooms; seven rooms emptied by the CPC 64 KiB version (17h, 27h, 32h, 33h, 35h, 36h, 4Bh) | the full map |
| start | Guillermo in the cloister (x 88h, y 9Ch) | at the entrance (x 88h, y A8h), as the full game |
| day VII tercia | lasts C3h × 256 frames (a byte written by `game_main` into the table of durations) | ends only by the story, as on the PC |
| heads | the CPC's multicolour graphics | high resolution: a black hardware-sprite mask over each head |
| extras | start menu: language, footsteps, text sound | the same menu and the Ave María at compline, 2 MHz in the borders |

The differences of the full game were found by comparing the 64 KiB program with the PC version's functions and data
(`data/completo/PLAN.md`), and the C128 game is certified against the PC rebuild frame by frame.
