; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_48FC at 48FC (64K)   PC: -   CPC 6128: -   called 25468 times by 4510
; '*' = executed in the exploration sessions; the listing runs to the next known entry
48FC * ld a,h
48FD * and 007h
48FF * ld c,a
4900 * ld a,h
4901 * and 0f8h
4903 * ld h,a
4904 * ld a,l
4905 * and 003h
4907 * ld b,a
4908 * ld a,l
4909 * and 0fch
490B * ld l,a
490C * ld a,d
490D * add a,c
490E * add a,007h
4910 * and 0f8h
4912 * ld d,a
4913 * ld a,e
4914 * add a,b
4915 * add a,003h
4917 * and 0fch
4919 * ld e,a
491A * ret
