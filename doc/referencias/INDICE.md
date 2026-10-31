# Official references (index)

Facts this project relies on, each with its source and how it was checked.  The rule:
always from the official documentation, never from memory, and every official fact kept in the project, properly
indexed.  A fact is marked **checked** only when the real thing (VICE with
the real ROMs, the hardware, the original game) confirmed it; otherwise **from the source**.

| File | Subject |
|---|---|
| [cinta_c64.md](cinta_c64.md) | The C64 tape: the KERNAL's tape encoding (pulses, bytes, blocks, header), the TAP file format |
| [c128.md](c128.md) | The Commodore 128: the MMU (its registers bit by bit, from "Mapping the Commodore 128"), memory banks, common RAM, VIC-II video bank; the KERNAL (boot sector, LOAD's limit, SETBNK, the raster interrupt, JIRQ, 2 MHz), VICE |
| [p500.md](p500.md) | The Commodore P500 (CBM-II): the 6509 and its banks, the I/O of bank 15 (VIC-II, SID, 6526, the two 6525 TPIs), the interrupt's acknowledgement, the keyboard matrix, the KERNAL (its variables, LOAD, SAVE, the cross-bank call), cc65's cbm510 runtime, VICE |
| [vice.md](vice.md) | VICE 3.10 on hal9000/hal9000c/hal9000asus: emulators, disk and tape image tools |
