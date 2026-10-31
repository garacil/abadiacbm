; abadia64ks on tape (c64/cinta/NOTAS.md): both languages' data inside the program, made by
; c64/cinta/construye.sh (the files copied to c64/presentacion/generado_cinta under these names).
        .export _cinta_pp_es, _cinta_pp_en
        .export _cinta_text2_es, _cinta_text2_en
        .segment "RODATA"
_cinta_pp_es: .incbin "pp_es.bin"
_cinta_pp_en: .incbin "pp_en.bin"
_cinta_text2_es: .incbin "text2_es.bin"
_cinta_text2_en: .incbin "text2_en.bin"
