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

; abadia64ks on tape (c64/cinta/NOTAS.md): both languages' data inside the program, made by
; c64/cinta/construye.sh (the files copied to c64/presentacion/generado_cinta under these names).
        .export _cinta_koa_es, _cinta_koa_en
        .export _cinta_pp_es, _cinta_pp_en
        .export _cinta_text1_es, _cinta_text1_en
        .segment "RODATA"
_cinta_koa_es: .incbin "koa_es.bin"
_cinta_koa_en: .incbin "koa_en.bin"
_cinta_pp_es: .incbin "pp_es.bin"
_cinta_pp_en: .incbin "pp_en.bin"
_cinta_text1_es: .incbin "text1_es.bin"
_cinta_text1_en: .incbin "text1_en.bin"
