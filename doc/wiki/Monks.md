<!-- Made by tools/wiki.py from doc/wiki/fuentes/Monks.md: edit the template, not this page. -->
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

[`src/c64/juego_final/camino.s`](../../src/c64/juego_final/camino.s#L86-L89), lines 86–89:

```asm
; The common part of the drivers (X = 0 Malachi, 1 the abbot, 2 Berengar, 3 Severin, 4 Adso): ai_no_route
; [37E9] = 0; the behaviour (IY = record, IX = places, A = 0); the door permissions (C = the mask;
; Berengar's is the operand 04B0h, script variable A9); chr_update (HL = the chr_table entry).  Out: IY =
; the record chr_update worked on ([247E]), IX = the places.
```

[`src/c64/juego_final/camino.s`](../../src/c64/juego_final/camino.s#L145-L150), lines 145–150:

```asm
; 03AC (ai_plan_route, the shared tail of the drivers): a move already planned (bit 7 of [chr+9] clear) ->
; ai_check_planned_move; ai_no_route set -> nothing.  Destination d = [places-1]: FF/FE/FD/FC = Guillermo /
; the abbot / the book / the parchment, whose four neighbours are the candidates (slot 0201h); else the
; place p = places + 3d (8 bit) is copied to 0203h (FF after it) and its neighbours follow (slot 0204h).
; chr_path_alt_ptr [0213] = 0203h; a candidate -> chr_path_find; result FD (already there) -> [places-3] =
; [places-1].  In: IY = chr, IX = places.
```

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

[`src/c64/juego_final/logica_b.s`](../../src/c64/juego_final/logica_b.s#L62-L90), lines 62–90:

```asm
; logica_b_vm: a script function is `JSR logica_b_vm` followed by its bytecode.  Runs it until its RET (or a
; tail call of a native routine).  The instruction pointer is zhl + Y: Y (0-127 at each dispatch) moves along
; the instructions and is folded into zhl when it reaches 128, at a jump and at an expression (ai_script_eval
; leaves zhl at the expression's end, as the Z80's HL).  The Z80's A and flags live in lb_va / lb_vf (lb_vf: N Z C
; as in a 6502 P; a P built from it takes the 6502's own I flag), from the entry's (5FDD, 6016, 6040 switch on
; their caller's C and Z).  The bytecode (guiones64.py; v = 2 x the variable's number mod 256, the offset of its
; word in D64_AI_SCRIPT_VARS):
;   CF expr       test: A = C = the value, Z = (value = 0)       D7 v expr     assignment
;   20 e / 18 e   JR NZ / JR                                     C2 nn         JP NZ to bytecode
;   C3 nn         JP to bytecode                                 C3 k 00       JP to lb_tabla[k] (native)
;   CD nn         CALL a native routine                          CD k 00 b     CALL lb_tabla[k] with the inline b
;   CD 0A 00 w..0 the switch of util_jump_table_inline 3A5D      C9            RET
;   3E n          LD A,n                                         01            XOR A
;   F8+p a n e    the test `v n =` (n a literal; the variable at page p 0-7 and low byte a), A = C = 00h
;                 true / FFh false and the flags of AND A, and its jump (e from the next instruction) when false
;   E2 v n e      the same (v as above), the jump when true
;   E3 / E4 v n e `v n >` (v >= n), the jump when false / true          E5 / E6 v n e  `v n <`
;   E7 / E8 v w e `v w =` (two variables)                              E9 / EA v m n e  `v m * n =` (v AND m = n)
;   EB v e / EC v m e  the value [v] / [v] AND m, the jump when not 0 (only the last test of a chain)
;   F0+p a n e    F8+p leaving A, C and the flags as they were (nothing reads them before setting them again)
;   A0+p / A8+p / B0+p a n e  `v n >` the jump when false / `v n =` when true / `v n <` when false, the same
;                 A test is a chain of these (guiones64.py)
;   DB/DC/DD/DE v n  [v] := [v] OR / + / AND / - n
;   D8 v n        assignment of a literal                        D9 v n        the same and RET
;   DA v n w m    two D8 in a row
;   D0 b / D1 b   CALL hud_say / hud_say_now b                   D2 / D3       CALL ai_guillermo_is_close /
;   D4            JP ai_stay                                                   hud_obsequium_minus_2
; The expressions are evaluated by ai_script_eval 3926 (group estado_texto; its entry estado_texto_eval_y takes
; the expression at zhl + Y): out zhl -> the terminator (A), zbc (C) = X = the value, N/Z of it.
```

The beginning of the abbot's script: the rules that come before anything else (Guillermo in the left wing at prima
or on day I; Guillermo in the library after the night; the expulsion):

[`src/c64/juego_final/logica_b_guiones.s`](../../src/c64/juego_final/logica_b_guiones.s#L1244-L1283), lines 1244–1283:

```asm
; 5B21 ai_abbot_think
ai_abbot_think:
        jsr     logica_b_vm
L5B21:
        ; [guillermo_x] 60h < [game_hour] 01h = [game_day] 01h = and or
        PRUEBAP $B0, D64_CHR_GUILLERMO+2, $60, L5B32
M5B21_0:
        PRUEBAP $A8, D64_CHR_BACKUP+25, $01, T5B21
M5B21_1:
        PRUEBAP $F0, D64_CHR_BACKUP+24, $01, L5B32
T5B21:
        .byte   $D8, $18, $0B  ; [ai_abbot_state] := 0Bh
L5B32:
        ; [game_hour] 01h >= [guillermo_z] 16h >= or
        PRUEBAP $A0, D64_CHR_BACKUP+25, $01, L5B43
M5B32_0:
        PRUEBAP $A0, D64_CHR_GUILLERMO+4, $16, L5B43
T5B32:
        .byte   $D8, $16, $09  ; [ai_abbot_dest] := 09h
        .byte   $D9, $18, $0B  ; [ai_abbot_state] := 0Bh / RET
L5B43:
        ; [ai_abbot_state] 0Bh =
        PRUEBAP $F0, D64_GAME_BOOK_POISON_COUNT+66, $0B, L5B67
T5B43:
        .byte   $D8, $16, $FF  ; [ai_abbot_dest] := FFh
        .byte   $D2  ; CALL ai_guillermo_is_close
        JRNZ    L5B66
        ; [game_guillermo_dead] 01h =
        PRUEBAP $F8, D64_GAME_BOOK_POISON_COUNT+18, $01, L5B59
T5B52:
        .byte   $C9
L5B59:
        ; [txt_phrase_busy] 00h =
        PRUEBAP $F8, D64_CHR_BACKUP+57, $00, L5B66
T5B59:
        .byte   $D0, $0E  ; hud_say
        .byte   $D8, $38, $01  ; [game_guillermo_dead] := 01h
L5B66:
        .byte   $C9
L5B67:
```

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
