# The C64 version's pictures: every graphic and the map (src/c64/mapa)

The same as for the PC version, for the Commodore 64's graphics: a PNG with all of them and a complete map.

    python3 -I src/c64/mapa/hoja64.py      # graficos_c64.png
    python3 -I src/c64/mapa/mapa64.py      # mapa_c64.png (needs gcc: builds salas64.c)

* `graficos_c64.png`: every graphic of the C64 disk in its C64 format and colours, twice its size (a multicolour
  pixel two screen pixels wide), labelled with its C64 address and the CPC address it comes from: the inks (day,
  night, the game's parchment as C64 colours, VICE's colodore palette), Guillermo's and Adso's frames, the door,
  the objects, the robes, the faces, the 218 tile slots at $D000 by day and by night, the score bar, the day
  numerals, the score bar's font, the lamp's light, the obsequium tail; the loading picture (`abadia.koa`)
  and the parchment's gothic letters (`pp.bin`) with a VICE capture of its first page.  Read from
  `src/c64/juego_final/juego.bin` at the addresses of `mapa64.tsv`, frames from `data/c64graf/marcos64.tsv`.
* `mapa_c64.png`: per floor a plan seen from above (north up) and the 95 screens as the 6502 game draws them.
  `salas64.c` starts the 6502 game (`src/c64/juego_final`, the -D PRUEBA image the host's --juego6502 runs) on the
  hybrid host's 6502 core (`src/juego/m6502`) at `principal_inicio`, runs it to its first frame point, then for every
  room puts Guillermo in it and calls the game's own `iso_update_camera_room`, `iso_draw_room`,
  `spr_draw_or_darken` and `chr_fill_height_buffer`: the screens are the C64 bitmap byte for byte.  The plan is
  drawn from those heights (the cells a character can reach by `chr_path_check_square`'s rule), with the room
  links, the doors, the door table and the mirror read from the 6502 memory; on each screen every passage has a
  green line on its threshold and the room it leads to, and the staircases E1-E4 are marked at both ends.
  The 64 KiB version shows here what it cut: rooms 17h, 27h, 32h, 33h, 35h, 36h and 4Bh are emptied and closed
  (no cell of them can be reached), which leaves the cloister an L of its north and west walks.
