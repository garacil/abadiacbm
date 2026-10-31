# VICE (checked on the machines)

- VICE 3.10 (Arch package `vice`, repository extra) on hal9000, hal9000c and hal9000asus (installed there with
  pacman): x64sc (C64), x128 (C128), xcbm5x0 (P500), xcbm2 (B series), c1541, petcat.
- xcbm5x0 drive types (`xcbm5x0 -help`, `-drive8type`): 0 none, 2031, 2040, 3040, 4040, 1001, 8050, 8250, 9000.
- c1541 makes D64, D71 and D80 images (`c1541 -format "name,id" d80 file.d80`: 533248 bytes; d71: 349696 bytes).
- The binary monitor (`-binarymonitor`) drives every test of this project (src/c64/plataforma/pruebas/vice_mb.py).
- Palette files: /usr/share/vice/C64/colodore.vpl (the editor's C64 colours).
