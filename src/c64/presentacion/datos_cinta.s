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
