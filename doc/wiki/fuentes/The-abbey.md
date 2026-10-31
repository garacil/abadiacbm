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

{{code src/c64/juego_final/logica_b.s | ^; 5129 hud_obsequium_sub | +31}}

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

{{code src/c64/juego_final/principal.s | ^; ---- 3E29 game_check_end | +17}}

The percentage of the investigation is computed from the day, the hour and the *bonus* bits — one bit for each
discovery the game rewards (holding the gloves, the keys, reaching certain rooms...), 4 % each:

{{code src/c64/juego_final/logica_a.s | ^; 3DA8 game_compute_percentage | ^.endproc}}

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
