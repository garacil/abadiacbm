; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_op_call at 1DC2 (64K)   PC: 2C18   CPC 6128: 21B4   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1DC2 * ld de,017f1h
1DC5 * ld (01dfch),de
1DC9 * push hl
1DCA * ld a,(01c60h)
1DCD * ld c,a
1DCE * ld a,(01c66h)
1DD1 * ld b,a
1DD2 * push bc
1DD3 * ld a,(01d06h)
1DD6 * ld c,a
1DD7 * ld a,(01e3eh)
1DDA * ld b,a
1DDB * push bc
1DDC * ld bc,(01bech)
1DE0 * push bc
1DE1 * ld bc,(01be9h)
1DE5 * push bc
1DE6 * ld a,(01bebh)
1DE9 * push af
1DEA * ld de,01dfeh
1DED * push de
1DEE * call iso_fetch_word
1DF1 * ld a,(01bebh)
1DF4 * push hl
1DF5 * ex de,hl
1DF6 * ld e,(hl)
1DF7 * inc hl
1DF8 * ld d,(hl)
1DF9 * inc hl
1DFA * ex (sp),hl
1DFB * jp iso_enter_block
