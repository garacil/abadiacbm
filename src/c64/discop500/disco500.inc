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


; abadia128ks on the P500 (c64/discop500/NOTAS.md): what the menu, the presentation's loader (carga500.s) and the last
; stage (etapa500.s) share.  The options' bits are the C128's (c64/disco128/disco128.inc), as the game reads them
; (plat_opciones).

OPC_INGLES    = 1                       ; English (else Spanish)
OPC_SIN_PASOS = 2                       ; no footsteps
OPC_SIN_TEXTO = 4                       ; no sound for the text
OPC_SIN_AVE   = 8                       ; no Ave Maria at completas
ETAPA         = $0200                   ; the last stage, in bank 1 (etapa500.cfg)
ETAPA_OPCIONES = ETAPA + 3              ; its two bytes the loader writes: the options, the drive
ETAPA_UNIDAD  = ETAPA + 4
ETAPA_FINAL   = ETAPA + 5               ; its second entry: the game's ending (plat_final)
FINAL_OPCIONES = $0FFF                  ; bank 1: the options for "FINAL" (final500.s)
