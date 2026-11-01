# abadia128ks on the P500: the disk of the CBM-II 510

The Commodore 128's full game (`-D C128`: the second bank's data, the hires heads, the Ave Maria) on the P500, the
CBM-II 510 with 128 KiB (`-D P500`: its own platform, src/c64/plataforma/p500.s, interrupcion500.s, teclado500.s,
tinta500.s, io500.inc).  Every machine fact used here is in doc/referencias/p500.md, from Commodore's 700 Reference
Guide, the KERNAL ROM 901234-02 and cc65's cbm510 runtime, and checked in VICE (xcbm5x0 3.10, 128 KiB, PAL).

## Building and testing

    src/c64/discop500/construye.sh          # everything from the sources: abadia128ks_p500.d80 (8050) and .d64 (2031, 4040)

The disks were checked in VICE: DLOAD"ABADIA" and RUN (SHIFT + RUN/STOP types the same), the menu in both languages
and with every option off, the parchment with its music, the loading, the game, the Ave Maria's samples in bank 1, the
save and load on disk (the file ABADIA64.BSn written, a block loaded back the same), the ending ("FINAL") in both
languages; a long run with the interrupt and the main loop's frames always there.

## The disk

| File | What | Where it goes |
|---|---|---|
| ABADIA | the menu (`presentacion/menu500.c`), the presentation (the parchment with the CPC's music) and the game's loader (`presentacion/carga500.s`), cc65's cbm510 target (`presentacion/p500.cfg`), both languages inside | bank 0, from $0003 |
| B | the game's bank 1 (the room table, the texts, the heads' blacks) | bank 1, $1000 |
| J | the game's bank 0 ($0002-$FFF5) crunched by Exomizer in one piece | bank 1, ending at $FF00 |
| E | English only: the bytes the English image has different (records: bank 0's, then bank 1's) | bank 1, at the game's ave_muestra |
| AVE | the Ave Maria's samples (`c64/disco128/ave128.py`), only when option 4 is on | bank 1, ave_muestra, loaded by the last stage |
| FINAL | the ending (`presentacion/final.c` with `final500.s`), both languages inside | bank 0, loaded by the last stage at the game's end |

## The loading

1. ABADIA (cc65): the menu keeps the options in `opciones500` and the drive (the KERNAL's FA) in `unidad500`; the
   parchment; then `carga500.s`: the loading picture on the game's screen (bitmap $E000, screen RAM $C000, colour
   RAM $D400 of bank 15; TPI 1's CA and CB as the game wants them), but for row 24's cells 24-39, whose bitmap bytes
   are cc65's cross-bank call and jump table ($FEC0 on: needed by the loads, those cells black); B, J and (English) E
   into bank 1 with the KERNAL's LOAD (A = bank 1, X = Y = $FF), the name and the file written into the KERNAL's zero
   page; the last stage copied to bank 1's $0200 with the options and the drive; every interrupt source off; the CPU
   moved to bank 1 (bank 0's $FFF6 is cc65's STA $00, bank 1's $FFF8 a JMP to the stage).
2. The last stage (`etapa500.s`, bank 1 $0200-$0FFF, its own zero page and stack): the display blanked; J decrunched
   by Exomizer's own decruncher: its literals read in bank 1 (get_crunched_byte), its copies and its output to bank 0
   by LDA / STA (zp),Y with the indirect bank register $01 = 0; the English bytes; the options (plat_opciones,
   plat_unidad; footsteps or the text's sound off: the note of the footstep's or the beep's sequence a rest, 0Fh;
   the Ave Maria off: its call 3 NOPs); AVE loaded with the
   KERNAL from bank 1 (the KERNAL's own cross-bank call, coming back to bank 1: bank 1's $FF26 and $FFF6 as bank 15's,
   bank 1's $01FF the way back); bank 0's $FFF6-$FFFA = STA $00, JMP principal_inicio, and bank 1's $FFF6 moves the
   CPU there.
3. The stage stays in bank 1 for the whole game (the game's bank 1 starts at $1000): its second entry, $0205, is the
   ending.  The game's `plat_final` leaves the options at $0203, writes bank 1's $FFF8 = JMP $0205 and goes there;
   the stage loads FINAL into bank 0 with the KERNAL, leaves the options at bank 1's $0FFF (FINAL's `final500.s`
   reads them at its start), puts TPI 1's mask back as the KERNAL's reset leaves it, takes the system's stack pointer
   ($F:01FF) and starts FINAL as BASIC's SYS 256 does: SEI, LDA #0, STA $00 at $0100, the CPU moving to bank 0's
   $0105 (cc65's start-up).

## The game on the P500 (src/c64/juego_final with P500=1; src/c64/plataforma)

- `-D C128 -D P500`: the C128's game, its map in `juego_final/p500` (C64_MAQUINA=p500: mapa64.py also keeps $FF20-$FF2F
  and $FFF6 on free, the KERNAL's return path in bank 0), MEMCFG = $01 (the indirect bank register; MEM_RAM = MEM_IO =
  0, MEM_B1 = 1).
- Bank 1 through the 6509's two cross-bank instructions: far_lee, far_pon, far_sala, far_texto, far_palabras,
  far_frases, far_numeral (`$01`: 0 -> 1 -> 0 by INC / DEC) and the heads' blacks (`cabezas128.s` neg_b1_copia).
  A plain `LDA abs` always reads the execution bank: the C128's way (the MMU mapping block 1) does not apply.
- The I/O of bank 15 through `io500.inc`'s macros (VIC_STA, VIC_LDA, SID_STA: on the C64 and the C128 the plain
  instruction, the same bytes) and the platform's own code: the 300 Hz tick from the 6526's timer A through TPI 1
  (the acknowledgement: the 6526, TPI 1, the 6526 again; doc/referencias/p500.md), the keyboard's 16 x 6 matrix
  (TPI 2) and both game ports (the 6526), the inks, the SID.
- The disk (save, load) through the KERNAL of bank 15, its own zero page and stack there (nothing of the game's moved):
  `p500.s` k15, the KERNAL's cross-bank call; the game's interrupt off meanwhile and its tick, TPI 1's mask and the
  game ports set again after.
- The platform's code in the C128's fixed areas the P500 does not need for their purpose (COMUN $0800-$09FF, the C128
  KERNAL's page $0A00-$0AFF), the rest in CODE.
- Certified against the PC rebuild as the C128: `CORRE=corre500.py src/c64/certifica/pc/lote.sh
  src/c64/juego_final/p500 PC_BUILD OUT 6000 4 1 2 3 4`: four random sessions of 6000 frames from this disk (menu,
  parchment, loader, stage), 237 data compared at every frame, 0 differences.
