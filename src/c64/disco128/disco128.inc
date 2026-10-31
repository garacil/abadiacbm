; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
; Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
; option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
; implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
; You should have received a copy of the GNU General Public License along with this program.  If not, see
; <https://www.gnu.org/licenses/>.


; abadia128ks, the disk of the 128 KiB machines (milestone H10): what its programs share (c64/disco128/NOTAS.md).
; The C128 boots the disk (its boot sector, arranque128.py), which loads the menu ("M", $1300); the menu keeps the
; options in the last byte of the boot sector's buffer ($0B00-$0BFF, unused once the boot sector has run; the crunched
; presentation, placed by Exomizer for an in-place decrunch, starts at $1BFE); the presentation reads them, its loader
; passes them to the game (plat_opciones).  Addresses checked against "Mapping the Commodore 128"
; (doc/referencias/c128.md): $1300-$1BFF is free for programs; SETBNK $FF68 (A = the data's bank, X = the name's),
; FA $BA the current device, NDX $D0 the keyboard buffer's count, VM1 $0A2C the 40-column screen's $D018
; shadow ($16: the lower/upper-case set), LOCKS $F7 (bit 7: SHIFT + C= does not switch the set).

OPCIONES      = $0BFF                   ; the menu's options (bits below)
UNIDAD        = $0BFE                   ; the drive the disk booted from (FA when the menu starts)
OPC_INGLES    = 1                       ; English (else Spanish)
OPC_SIN_PASOS = 2                       ; no footsteps
OPC_SIN_TEXTO = 4                       ; no sound for the text
OPC_SIN_AVE   = 8                       ; no Ave Maria at completas (the PC version plays it)

SETBNK  = $FF68
SETLFS  = $FFBA
SETNAM  = $FFBD
LOAD    = $FFD5
FA      = $BA
NDX     = $D0
VM1     = $0A2C
LOCKS   = $F7
MMU_CR  = $FF00
CFG_CC65 = $0E                          ; RAM of block 0 up to $BFFF, the KERNAL ROM and the I/O (cc65's c128 setup)
PRES_INICIO = $1C0D                     ; the presentation: its BASIC line's SYS
