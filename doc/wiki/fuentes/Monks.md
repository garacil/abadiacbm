# The monks' minds

[Home](Home.md) · previous: [Heights and path finding](Paths.md) · next: [Objects, doors and the mirror](Objects.md)

Each of the five other characters has a **script**: a routine written in a small language of the original program,
which decides **where the character goes** and **what he says**, from the day, the hour, where Guillermo is and the
story's variables.  The movement itself — the route, the steps — belongs to the path finder.

## The drivers

Every frame `game_run_npc_behaviours` calls the driver of each character (Adso, Malaquías, the abbot, Berengario's
slot, Severino's slot).  A driver points IY at the character's record and IX at his table of **places**, runs his
script, gives him the doors he may open, moves him one step, and then plans a route if the script changed his
destination:

{{code src/c64/juego_final/camino.s | ^; The common part of the drivers | +4}}

{{code src/c64/juego_final/camino.s | ^; 03AC \(ai_plan_route | +6}}

Three bytes before the places table hold the script's interface: the place **reached**, the character's **state**,
and the **destination** — a place number, or FF (Guillermo), FE (the abbot), FD (the book), FC (the parchment).  The
places are the abbey's fixed points: the church, the refectory, the desks of the scriptorium, the cells, the entrance,
the kitchen, the passage to the library...

## The script language

The original's scripts are Z80 code with two helpers, `RST 08h` (test) and `RST 10h` (assign), each followed by an
inline **postfix expression** over the game's variables: `[87] 08 = [94] 02 = &` reads "Malaquías has reached place 8
and Severino place 2".  The comparisons give 00 for true; `*` and `&` are the logical *or* and *and* on such values.
570 of these calls are in the program, all in the scripts (51E7h-60F2h in the 64 KiB game).

Translating them as 6502 calls with inline data would have cost about 7 KiB; instead, the scripts stay **bytecode**:
each script routine is `JSR logica_b_vm` followed by the Z80's own bytes — the same opcodes, `JR`, `JP`, `CALL`, `RET`,
the inline expressions — with 6502 operands, plus a few compact forms for the most common tests.  A generator
(`guiones64.py`) translates the Z80 scripts from the tape's memory into this form, with every expression written as a
comment:

{{code src/c64/juego_final/logica_b.s | ^; logica_b_vm: a script function is | ^; the expression at zhl}}

The beginning of the abbot's script: the rules that come before anything else (Guillermo in the left wing at prima
or on day I; Guillermo in the library after the night; the expulsion):

{{code src/c64/juego_final/logica_b_guiones.s | ^; 5B21 ai_abbot_think | +40}}

## The characters

**The abbot.**  The rules first: Guillermo in the left wing at prima or on the first day, or in the library when he
should not be, means expulsion (state 0Bh: he walks to Guillermo and, when close, *NO HABÉIS RESPETADO MIS ÓRDENES.
ABANDONAD PARA SIEMPRE ESTA ABADÍA*).  On day I at nona he gives the welcome tour (the entrance, the first stop, his
cell, Guillermo's cell), stopping whenever Guillermo falls behind (*OS ORDENO QUE VENGÁIS*, and −2 of obsequium).  He
leads the ceremonies (see [The clock](Clock.md)), sends everyone to their cells at completas, watches at night, asks
for the parchment when Berengario has told him that Guillermo took it, and on the days' tercia and nona calls Guillermo
(*VENID AQUÍ, FRAY GUILLERMO*) to give the news: Venancio's death, Berengario's disappearance, Bernardo Gui's arrival,
Severino's death, and on day VII the end of the investigation.

**Malaquías**, the librarian, sits at his desk by the passage to the library and blocks it when Guillermo comes near
(*LO SIENTO, VENERABLE HERMANO, NO PODÉIS SUBIR A LA BIBLIOTECA*); at vísperas he takes key 3 from his table, sends
Guillermo out of the building, warns the abbot if he stays, closes the left wing's doors and goes to the kitchen.  On
day V he kills Severino at tercia, and at vísperas he dies poisoned (*ERA VERDAD, TENÍA EL PODER DE MIL
ESCORPIONES*).

**Berengario's slot**: Berengario at his scriptorium desk (who reports the parchment if Guillermo takes it), then the
hooded monk who takes the book at night, Jorge's presentation, and from day IV **Bernardo Gui**, who asks Guillermo
for the parchment and finally leaves the abbey.

**Severino's slot**: Severino the herbalist, who introduces himself, warns of the strange things in the abbey and finds
a strange book in his cell; from day VI **Jorge**, waiting in the finis Africae for the last scene: the book, the
gloves, the poison, and the end.

**Adso** follows Guillermo, goes to the church and the refectory at the ceremonies, needs the lamp in the library
(*DEBEMOS ENCONTRAR UNA LÁMPARA, MAESTRO*), warns when it runs out, and at night in the cell asks *¿DORMIMOS?,
MAESTRO*: S (or Y in English) or no answer passes to the next day; N keeps them awake.

## Talking

A script says a phrase with `hud_say` and an inline phrase number; the phrase scrolls along the score bar while the
game goes on (see [Text and the score bar](Text.md)).  `ai_guillermo_is_close` — Guillermo on the same floor and inside
a box in front of the monk — decides when a monk speaks to him.
