# Heights and path finding

[Home](Home.md) · previous: [Sprites and the screen](Sprites.md) · next: [The monks' minds](Monks.md)

The monks walk on their own through the whole abbey: up and down stairs, through doors, from one room to another and
from one floor to another.  They do it with two breadth-first searches — one inside a room, one between rooms — and
a writer that turns the path found into movement commands.  It is the heaviest work of the game: almost half of the
C64's cycles in the recorded sessions.

## The height buffer

Every room has a **height buffer**: 24 x 24 cells (the room's 16 x 16 positions and a border of 4), each the height
of the floor there (low nibble) or the mark of a character standing on it (10h, 20h).  It is filled when the room
changes, from the floor's list of height records (flat areas, slopes, steps):

{{code src/c64/juego_final/personajes.s | ^; 2873 chr_fill_height_buffer | +3}}

The characters' probes read it to decide each step (see [Characters and movement](Characters.md)); the searches use a
second buffer of the same kind, built around the character that is looking for a route, so that a monk in another
room can plan without disturbing the room on the screen.

## Choosing the kind of search

`chr_path_find` is the entry: route a character to a target position.  Another floor: towards the stairs that go up
or down; another room of the same floor: through the graph of rooms; the same room: a search in the height buffer:

{{code src/c64/juego_final/camino.s | ^; 05FA chr_path_find | ^\.proc chr_path_find}}

## The search inside a room

The search is a breadth-first expansion over the height buffer from the character's cell: each queued position
tries its four neighbours, which must be walkable from it (the same height or one unit up or down, for a character
of 2 x 2 cells), and marks them visited (bit 7), until a cell marked as a target (bit 6) is reached.  The room's border
is marked visited first, so that the search stays inside:

{{code src/c64/juego_final/logica_a_cam.s | ^\.proc la_sala | ^\.endproc}}

The Z80 used its own **stack** as the search's queue: it pushed the positions and walked the stack pointer through
them.  The 6502's stack has only 256 bytes, so the translation keeps the queue in memory, at the same addresses,
growing downwards as the Z80's did — and writes into it the same words the Z80's `CALL`s and `PUSH`es left there, so
that the memory stays equal to the original's byte for byte (the certification compares it).

## Between rooms and floors

The floor map (one byte per room) works as a smaller grid: the same search runs over it to find the sequence of rooms
towards the target room, the doors being edges that the doors' permissions open or close.  The character then
searches a route inside its room to the band of cells that leads to the next room.  To change floor, every cell of
the stairs' height becomes a target.

## From the path to the commands

The search leaves, in its queue, the cell that reached the target.  `chr_cmd_write_path` walks the queue backwards
to rebuild the path, then simulates the character's walk along it and writes the commands — turns and steps — into
its command buffer as the bit stream the character will read one step at a time:

{{code src/c64/juego_final/logica_a_cam.s | ^; 41C9 chr_cmd_write_path | +8}}

## Adso

Adso does not plan when he follows Guillermo: his driver measures the path length between them and takes one step
when they are far enough apart; when Guillermo walks into him, Adso steps aside, and the player can push him with the
*down* key (`chr_adso_step_aside`, `chr_adso_step_guillermo_dir`).

## The memo of the C128

With no keys pressed, the original repeats every frame some searches that fail in the same way (Severino from the
frame 674 of the start, for example: 1328 identical calls of 91 152 cycles each).  The C128's speed work keeps the
last failing room-to-room search — every byte it reads as the key, every byte it writes as the result — and replays
it when the same call comes again: the 6502 being deterministic, the same inputs give the same outputs, and the
certification against the PC shows no difference.

{{code src/c64/juego_final/camino_memo.s | ^; abadia64ks, 6502 code of the game: a memo of the whole route | +8}}
