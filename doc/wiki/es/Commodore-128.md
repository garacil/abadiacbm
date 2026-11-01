<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/Commodore-128.md: se edita la plantilla, no esta página. -->
<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# El Commodore 128

[Inicio](Inicio.md) · anterior: [La plataforma del Commodore 64](Plataforma-C64.md) · siguiente: [El Commodore P500](Commodore-P500.md)

abadia128ks funciona en el propio modo C128, no en su modo C64.  Es el mismo juego 6502, ensamblado con `-D C128` (la
máquina), `-D COMPLETO` (el juego completo de las versiones de CPC 6128 y PC) y `-D VELOZ` (el trabajo de velocidad), y
aprovecha lo que añade el C128: otros 64 KiB de RAM, los 2 MHz y sitio para las cabezas en alta resolución.  Cada dato
del C128 que uso lo leí en *Mapping the Commodore 128* (Ottis R. Cowper, COMPUTE! Books, 1986;
`doc/referencias/c128.md`) y lo comprobé en el x128 de VICE.

## Dos bloques de RAM

El juego corre en el bloque 0, como en el C64; el registro de configuración de la MMU, `$FF00`, hace el papel del `$01`
del C64.  El bloque 1 guarda lo que el generador del mapa sacó del bloque 0: la tabla de salas, los textos y los
trazos negros de las cabezas.  La RAM común de abajo (4 KiB, siempre del bloque 0) guarda las rutinas que llegan al
bloque 1 y las rutinas de interrupción, para que una interrupción pueda llegar esté puesto el bloque que esté:

[`src/c64/plataforma/c128.s`](../../../src/c64/plataforma/c128.s#L17-L32), líneas 17–32:

```asm
; abadia64ks, the Commodore 128's own platform (milestone H10, assembled only with -D C128; the MMU:
; doc/referencias/c128.md, from "Mapping the Commodore 128").  The game runs in block 0 as on the C64 (the MMU's
; $FF00 = $3E / $3F where the C64 writes $35 / $34 into the 6510's $01: MEMCFG, plat64.inc); block 1 holds what
; mapa64.py moved out of block 0 (zone banco1, from $1000: the room table D64_ISO_ROOM_TABLE), loaded there
; from juego.bin.banco1.  Everything here lives in segment COMUN at $0800, inside the 4 KiB of common RAM
; ($0000-$0FFF, always block 0, set by c128_inicio), so it runs whichever block is mapped; plat_irq and plat_nmi
; (interrupcion.s) are there too: an interrupt that comes while block 1 is mapped takes block 1's vectors at
; $FFFA-$FFFF, which c128_inicio makes the same as block 0's.
;
; c128_inicio: the common RAM and block 1's vectors.  Called by plat_inicio with the I/O visible, the vectors of
;   block 0 set and the interrupts off.  A, Y clobbered.
; far_lee: A = the byte at (zhl),Y of block 1.  X, Y, C and V kept; N and Z of A (as LDA (zhl),Y).
; far_pon: the byte A into (zhl),Y of block 1.  A, X, Y and the flags kept (as STA (zhl),Y).
; far_sala: the room record at [D64_ISO_ROOM_PTR] (block 1) copied into SALA (block 0, common RAM), whole: its
;   first byte is its length.  iso_draw_room builds the room from SALA + 1.  A, Y clobbered; X kept.
; SALA: 256 bytes (segment SALA128, $0B00: the common RAM).
```

El juego lee la tabla de salas a través de dos macros (`LEE_SALA`, `PON_SALA`, ver [Del Z80 al 6502](Del-Z80-al-6502.md))
que en el C128 se convierten en `JSR far_lee` / `JSR far_pon`, y el registro de una sala se copia entero a la RAM común
antes de construirla.

## 2 MHz en los bordes

El 8502 puede ir a 2 MHz, pero entonces el VIC-II no puede enseñar imagen.  El juego pasa a 2 MHz mientras el haz está
por encima y por debajo de la ventana de imagen, donde el VIC-II no lee nada (112 de las 312 líneas de un cuadro PAL),
con dos temporizadores de la CIA 2 sincronizados con el haz, cuyas NMI cambian el reloj:

[`src/c64/plataforma/c128.s`](../../../src/c64/plataforma/c128.s#L44-L52), líneas 44–52:

```asm
; Speed (everything optimised for speed): the 8502 runs at 2 MHz (CLKRATE $D030 bit 0)
; while the beam is below and above the display window, where the VIC-II reads nothing from memory (it cannot show a
; picture at 2 MHz: "Mapping the Commodore 128"; the I/O chips are reached at 1 MHz by the C128's clock stretching,
; and the CIAs count at 1 MHz, so the game's 300 Hz tick is unchanged).  CIA 2's two timers, one frame long each
; (PAL: 312 lines of 63 cycles, 19656), started by c128_rapido on the raster lines RAPIDO_SI (252, after the last
; display line, 250) and RAPIDO_NO (46, before the first fetch line, 51 with $D011 = $3B), raise an NMI at each:
; plat_nmi sets 2 MHz on timer A, 1 MHz on timer B (an NMI: not held back by the game's SEI); the RESTORE key's
; NMI changes nothing.  112 of the 312 lines at 2 MHz.  Off around the KERNAL's disk calls (its serial code times
; itself), on again after them.
```

[`src/c64/plataforma/interrupcion.s`](../../../src/c64/plataforma/interrupcion.s#L185-L208), líneas 185–208:

```asm
; the C128: CIA 2's timers switch the 8502's clock (plataforma/c128.s, c128_rapido): A below the display -> 2 MHz,
; B above it -> 1 MHz; the RESTORE key's NMI (no CIA 2 flag) changes nothing.  The I/O made visible meanwhile (the
; game may be reading or writing the RAM under it, MEMCFG = MEM_RAM, or block 1): A, the flags and MEMCFG kept.
.proc plat_nmi
        pha
        lda     MEMCFG
        pha
        lda     #MEM_IO
        sta     MEMCFG
        lda     CIA2_ICR                ; the flags (and acknowledged)
        lsr     a
        bcc     :+
        lda     #1
        sta     $D030
        bne     fin                     ; (always)
:       lsr     a
        bcc     fin
        lda     #0
        sta     $D030
fin:    pla
        sta     MEMCFG
        pla
        rti
.endproc
```

## Las cabezas en alta resolución

El bitmap multicolor reduce a la mitad la resolución horizontal, y las caras de los personajes pierden sus rasgos de
un píxel.  En el C128 cada cabeza (la de Guillermo, la de Adso, la cara de cada monje y sus reflejos en el espejo) recibe
sus trazos negros de un **sprite por hardware en alta resolución** del VIC-II, a la resolución completa del PC, puesto
encima de la cabeza multicolor, que conserva los rellenos.  El sprite y el bitmap tienen que cambiar en el mismo cuadro
que se enseña, y una baldosa que está delante de una cabeza tiene que tapar también los píxeles de su sprite:

[`src/c64/juego_final/cabezas128.s`](../../../src/c64/juego_final/cabezas128.s#L25-L42), líneas 25–42:

```asm
; Heads h = 0-5: the sprite records 0-5 (Guillermo, Adso, the monks, the reflections), hardware sprite h: slot
; G_CAB_SLOTS + 64 h (lines 0-9 = 30 bytes, the rest zero), pointer $C3F8 + h, black, hires, in front of the
; bitmap; X = 24 + 4 x, Y = y + 10 for the record's x (CPC bytes) and y (lines).  A record is a head when its graphic
; (+7) is one of Guillermo's or Adso's 12 animation frames, a monk's face (+0Bh bit 7 clear, the face's 30 bytes in
; G_CARAS), or a mirror buffer whose frame this file noted (cab_espejo, from iso_mirror_draw_callback).
;
; The black (G_CABEZAS_NEGRO: 26 heads x 10 lines x 3 bytes, unflipped as on the tape) is mirrored when the head is
; drawn, by a parity this file keeps exactly as the game flips its graphics in place: Guillermo's and Adso's frames
; (personajes_flip2: cab_gira_pers), each face block (personajes_flip_monk, spr_unflip_monk_faces: cab_gira_cara);
; a reflection is its frame mirrored once more (cab_espejo).
;
; Occlusion and the raster window as H7: the head's own rectangle only; right after its merge (cab_despues) the
; rectangle's bytes under its 10 lines kept as a snapshot in the unused half of the rectangle's allocation; at the
; rectangle's end (cab_fin_rect, after the tiles in front) every pair that changed (or that a tile drawn meanwhile
; covers: cab_marca, cab_marca_op from la_baldosa) hides the sprite's two pixels: pend[h] = black AND NOT changed.  At
; step 5 (cab_paso5) one raster window for every head rebuilt or gone: the beam is waited for (haz_espera) until it
; cannot reach their rows; then the first 3 cell rows of each head's rectangle are blitted, pend[h] copied into the
; slot and the VIC-II's registers set, so that the bitmap's head and its black change in the same displayed frame.
```

En las salas a oscuras de la biblioteca el juego compone solo el rectángulo de la luz de la lámpara, con los
personajes mezclados en él; las cabezas que se mezclan ahí también se registran, así que sus trazos en alta resolución
siguen a la luz:

[`src/c64/juego_final/cabezas128.s`](../../../src/c64/juego_final/cabezas128.s#L46-L52), líneas 46–52:

```asm
; The dark rooms (the library with the lamp; with the lamp in the labyrinth the heads were not shown in
; hires): there the game composes one rectangle a frame, the light's (its record's graphic 0000:
; la_tramo's la_luz), with Guillermo, Adso and any monk in it merged before the light's mask, and never their own
; rectangles; so a head merged into the light's rectangle is registered too (cab_q, cab_despues: up to NLUZ of them,
; each one's state kept), compared at the rectangle's end like the own one (cab_fin_rect: luz_fin), and its window
; blits its 3 cell rows of the light's rectangle, not of its own one, stale there (cab_paso5: filas, mide, todas); a
; head shown through the light and not merged into it in a pass (out of the light) goes off in that pass's window.
```

## El Ave María

En completas la versión de PC tocaba un Ave María digitalizado.  El C128 toca las mismas muestras (8062 por segundo,
de los datos de la versión de PC) a través del registro de volumen del SID, con el juego parado mientras suena, como en
el PC:

[`src/c64/plataforma/c128.s`](../../../src/c64/plataforma/c128.s#L525-L531), líneas 525–531:

```asm
; c128_ave: the game frozen while it sounds, as on the PC (13.45 s): interrupts off, CIA 2's NMIs off and 1 MHz (the
; screen stays), the three voices held at a constant level (test bit, pulse, gate, sustain 15: the 8580 needs that
; offset for the volume register to be heard; the 6581 has its own), each 4-bit sample of ave_muestra (block 1) into
; the volume register at the pace of CIA 1's timer B (AVE_CICLOS, polled); then the SID at rest (psg_inicio), CIA 1's
; tick back, 2 MHz in the border again.  The menu's option 4 off: the loader made its call 3 NOPs and the sample was
; never loaded.  A, X, Y clobbered.
.proc c128_ave
```

La opción 4 del menú de inicio lo quita: el cargador sustituye su llamada por tres `NOP` y las muestras ni siquiera se
cargan.

## La carga del final

Con el 100 % el juego carga el programa del final («FINAL») con el KERNAL.  El juego había sobrescrito el código y los
vectores de interrupción del KERNAL en la RAM (`$FF05-$FF44`, `$FFFA-$FFFF`) de los dos bloques; con una 1541, la carga
lenta admite interrupciones entre byte y byte, que saltaban al código del juego.  Por eso `plat_final` los vuelve a
copiar primero de la ROM a la RAM de los dos bloques, como hace el propio reinicio del KERNAL, y el final se carga con
una 1541 o con una 1571:

[`src/c64/plataforma/c128.s`](../../../src/c64/plataforma/c128.s#L475-L491), líneas 475–491:

```asm
        ldy     #$40                    ; the KERNAL's interrupt and reset code ($FF05-$FF44) and the 6502's vectors
kram:   sty     MMU_CR                  ; ($FFFA-$FFFF) back in the RAM of block 1, then block 0, as its RESET does
        ldx     #$3F                    ; ($E0CD: read in the ROM, written to the RAM under it).  An interrupt while a
:       lda     $FF05,x                 ; RAM block is in view goes through them ("Mapping the Commodore 128"); with
        sta     $FF05,x                 ; the game's there, the slow LOAD from a 1541 ended in the game's code it was
        dex                             ; overwriting.  (Run while the 4 KiB of common RAM at the bottom hold this.)
        bpl     :-
        ldx     #$05
:       lda     $FFFA,x
        sta     $FFFA,x
        dex
        bpl     :-
        tya
        sec
        sbc     #$40
        tay
        bcs     kram
```

## Todas las rutinas de las cabezas

| Original | Rutina | Línea |
|---|---|---|
| — | [`cab_inicio`](../../../src/c64/juego_final/cabezas128.s#L156) | 156 |
| — | [`cab_apaga`](../../../src/c64/juego_final/cabezas128.s#L209) | 209 |
| — | [`cab_gira_pers`](../../../src/c64/juego_final/cabezas128.s#L233) | 233 |
| — | [`cab_espejo`](../../../src/c64/juego_final/cabezas128.s#L328) | 328 |
| — | [`registro`](../../../src/c64/juego_final/cabezas128.s#L361) | 361 |
| — | [`registro_y`](../../../src/c64/juego_final/cabezas128.s#L378) | 378 |
| — | [`es_luz`](../../../src/c64/juego_final/cabezas128.s#L395) | 395 |
| — | [`marco`](../../../src/c64/juego_final/cabezas128.s#L408) | 408 |
| — | [`paridad_marco`](../../../src/c64/juego_final/cabezas128.s#L425) | 425 |
| — | [`cab_q`](../../../src/c64/juego_final/cabezas128.s#L435) | 435 |
| — | [`cab_despues`](../../../src/c64/juego_final/cabezas128.s#L458) | 458 |
| — | [`luz_guarda`](../../../src/c64/juego_final/cabezas128.s#L586) | 586 |
| — | [`construye`](../../../src/c64/juego_final/cabezas128.s#L628) | 628 |
| — | [`lee3`](../../../src/c64/juego_final/cabezas128.s#L708) | 708 |
| — | [`marca_ini`](../../../src/c64/juego_final/cabezas128.s#L741) | 741 |
| — | [`recorre`](../../../src/c64/juego_final/cabezas128.s#L783) | 783 |
| — | [`cab_fin_rect`](../../../src/c64/juego_final/cabezas128.s#L903) | 903 |
| — | [`luz_fin`](../../../src/c64/juego_final/cabezas128.s#L922) | 922 |
| — | [`cab_marca`](../../../src/c64/juego_final/cabezas128.s#L992) | 992 |
| — | [`fila`](../../../src/c64/juego_final/cabezas128.s#L1032) | 1032 |
| — | [`snap`](../../../src/c64/juego_final/cabezas128.s#L1053) | 1053 |
| — | [`mide`](../../../src/c64/juego_final/cabezas128.s#L1145) | 1145 |
| — | [`ventana`](../../../src/c64/juego_final/cabezas128.s#L1191) | 1191 |
| — | [`todas`](../../../src/c64/juego_final/cabezas128.s#L1216) | 1216 |
| — | [`filas`](../../../src/c64/juego_final/cabezas128.s#L1324) | 1324 |
| — | [`luz_filas`](../../../src/c64/juego_final/cabezas128.s#L1347) | 1347 |
