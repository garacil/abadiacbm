; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_update at 2472 (64K)   PC: 2349   CPC 6128: 291D   called 163900 times by 0384 03A5 04B7 04D8 0502 21C0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2472 * call chr_load_params
2475 * ld ix,02968h
2479 * call spr_save_old_rect
247C * ld iy,02b87h
2480 * ld c,000h
2482 * push ix
2484 * call chr_mark_hbuf
2487 * pop ix
2489 * ld a,(03eedh)
248C * and a
248D * ld a,000h
248F * ld (03eedh),a
2492 * call chr_think_or_step
2495 * ld c,(iy+00eh)
2498 * jr $-84
