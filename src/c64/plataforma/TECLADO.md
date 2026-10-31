# abadia64ks on the C64: the keyboard and the joystick

`plat_teclado_fila` (`teclado.s`) gives the game the CPC's keyboard matrix (10 rows of 8 keys, active low; CPC
key number = 8 x row + bit) from the C64's keyboard (CIA 1) and joystick port 2.  The game reads the ten rows
once a frame (sys_read_keyboard 2D50h): reading row 0 scans the whole C64 matrix and the joystick, rows 1-9
return that scan.  Checked in VICE for every C64 key, the cursor combinations, the joystick and joystick +
keys (`pruebas/prueba.py teclado`, 85 cases).

## What the game reads (the CPC 64 KiB version)

| CPC key | number | what it does | on the C64 |
|---|---|---|---|
| cursor up | 00h | Guillermo walks | **Q** (without R), SHIFT + CRSR down, or joystick up |
| cursor right | 01h | turns right | **P**, CRSR right, L, or joystick right |
| cursor down | 02h | Adso steps ahead of Guillermo | **A**, CRSR down, Z, or joystick fire |
| cursor left | 08h | turns left | **O**, SHIFT + CRSR right, K, or joystick left |
| space | 2Fh | drop an object; start a new game | SPACE, or joystick down |
| Q + R | 43h + 32h | open the mirror (on its steps) | Q + R: press R first (Q alone walks) |
| S / N | 3Ch / 2Eh | yes / no to Adso's question | S / N |
| DEL | 4Fh | pause | INST/DEL |
| CONTROL + TAB | 17h + 44h | the save / load menu | CTRL + left-arrow key (`<-`, top left) |
| S / L / ESC | 3Ch / 24h / 42h | in that menu: save, load, leave | S / L / RUN/STOP |
| ESC | 42h | (also read by the main loop, no effect) | RUN/STOP |
| SHIFT, CONTROL | 15h, 17h | the developers' exit (dead code) | SHIFT, CTRL |
| ENTER (small), F. | 06h, 07h | read, nothing happens | not mapped |
| the digits | | not read by the game | choose the save slot (below) |

The game's own alias tables (2E2Eh-2E41h) make A, Z, K, L and the CPC joystick do what the cursors do, and
the joystick's down what space does: the C64 inherits Z, K, L and the joystick by giving those letters as letters
and joystick port 2 as the CPC's joystick.

**Q A O P**: the C64 has two cursor keys, up and left are SHIFT + CRSR down / right, so
while SHIFT + CRSR down (walk) is held, CRSR right reads as left: walking and turning right turns left (up + left
and up + right give the same matrix).  So the C64 also takes Q (walk), A (Adso), O (left), P (right) as the
cursors, with space as on the CPC.  Q is the mirror's Q too: Q walks unless R is down, then it is the CPC's Q (Q +
R opens the mirror on its steps: press R first, or Guillermo walks up a step).  The C64's A no longer gives the
CPC's A (the game's alias of cursor up: Q does that now); O and P are not read by the game otherwise.

## The map

### Joystick port 2

The CPC's joystick 0 (row 9): up, down, left, right as the C64's bits 0-3; the fire button as the CPC's fire 1
(row 9 bit 5).  So, as on a CPC with a joystick: up walks, left/right turn, **down is space** (drop an object,
start a game), **fire is cursor down** (Adso).  (Fire as space instead would be one byte of `teclado.s`;
this keeps the original's joystick.)  Joystick port 1 is not read (its lines are the keyboard's rows: its rows
are left out of the scan, so it makes no phantom keys either).

### The keyboard (by the C64's matrix, `tecla_cpc` in `teclado.s`)

| C64 key | CPC key | | C64 key | CPC key |
|---|---|---|---|---|
| A-Z | the same letter, but A O P Q (below) | | INST/DEL | DEL (4Fh, the pause) |
| SPACE | SPACE | | RETURN | RETURN (12h) |
| CRSR down | cursor down | | CRSR right | cursor right |
| SHIFT + CRSR down | cursor up | | SHIFT + CRSR right | cursor left |
| LEFT / RIGHT SHIFT | SHIFT | | CTRL | CONTROL |
| RUN/STOP | ESC | | `<-` (left arrow) | TAB |
| C= | COPY | | CLR/HOME | CLR |
| F1, F3, F5, F7 | F1, F3, F5, F7 | | `^` (up arrow) | `^` |
| `- . : @ , ; /` | the same | | `+ * = £` | nothing |
| 0-9 | the save slot | | RESTORE | nothing (an NMI: RTI) |

SHIFT + CRSR makes the C64's up and left cursors: when a SHIFT is down, CRSR down is read as cursor up and
CRSR right as cursor left (the CPC's SHIFT key stays down too: the game does not use it).  A, O, P give cursor
down, left, right; Q gives cursor up while R is up, the CPC's Q while R is down.

### The save slot

The CPC saved one game on tape; the C64 saves it on the disk as `ABADIA64.BSn`, n = 0-9: the last digit key
pressed (1 at first).  CTRL + `<-` opens the menu (the mark blinks at the top left), then a digit chooses the
slot and S saves or L loads (RUN/STOP leaves).  The slot can be chosen before the menu as well: any digit
pressed during the game sets it.

## Limits of the hardware

* Three keys at three corners of a rectangle of the C64 matrix make the fourth corner read as down (the
  keyboard has no diodes): e.g. LEFT SHIFT + CRSR down + CRSR right also reads A.  The combinations the game
  needs (SHIFT + one cursor, Q + R, CTRL + `<-`) are not such rectangles; RIGHT SHIFT with both cursors is not
  either.
* Joystick port 2 pulls the keyboard's columns 0-4 low: a key of those columns held with the joystick pushed
  in the same line would read as down in every column.  The scan leaves out the rows that read low with no
  column selected, so the joystick makes no phantom keys; the cost is that such a key (in a column the
  joystick is pulling) is not seen while the joystick is pushed.
