; abadia64ks on tape: what the stages share (c64/cinta/NOTAS.md).  Every number here is also in cinta.py.

T_ABRE   = $033C                        ; the turbo core's entries (turbo.s)
T_BYTE   = $033F
T_CIERRA = $0342
T_CARGA  = $0345
T_VARS   = $02A8                        ; its variables, $02A8-$02AF
T_PAG2   = $02B0                        ; its part run once a block, $02B0-$02FF
t_dir    = T_VARS + 4                   ; the block's address
t_cuenta = T_VARS + 6                   ; the bytes left in the block

OPCIONES = $02A7                        ; the menu's choices: bit 0 English, bit 1 footsteps off, bit 2 text sound off
OPC_INGLES = $01
OPC_SIN_PASOS = $02
OPC_SIN_TEXTO = $04

UMBRAL  = 528                           ; cycles: a short wave (352) is below, a long one (704) above; the
                                        ; margin covers the game loader's longest work between two bytes plus a
                                        ; bad line (cinta.py; c64/cinta/NOTAS.md)
PILOTO  = $40
SINCRO  = $5A

ETAPA   = $C000                         ; where the stages (the menu, the ending's) run

FINAL_OPCIONES = $C3FF                  ; the options as the game leaves them for "FINAL" (plataforma/disco.s)

; the blocks' ids, in their order on the tape (cinta.py)
ID_MENU      = 1                        ; the menu (to ETAPA; not compressed)
ID_PRES      = 2                        ; the presentation with both languages' picture, parchment border,
                                        ; glyphs and text (Exomizer, decrunched by the menu to $0801)
ID_JUEGO     = 3                        ; the game's stream (Spanish) up to the mark (cargador.s)
ID_JUEGO2    = 4                        ; its rest, after the mark (the loader blackens the side cells between)
ID_TEXTOS_EN = 5                        ; the English game's bytes that differ (read only when English is chosen)
                                        ; then the KERNAL's file "FINAL" (arranque.s, ETAPA_ID = ID_ETAPA_FIN)
ID_ETAPA_FIN = 6                        ; the ending's stage (to ETAPA; not compressed)
ID_FINAL     = 7                        ; the ending's program with both languages' text (Exomizer, to $0801)
