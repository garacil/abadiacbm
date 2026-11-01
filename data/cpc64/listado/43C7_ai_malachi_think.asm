; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; ai_malachi_think at 43C7 (64K)   PC: 406D   CPC 6128: 575E   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
43C7 * push de
43C8 * jr $-20
43CA * push hl
43CB * push de
43CC * ex de,hl
43CD * call f_441E
43D0 * pop de
43D1 * pop hl
43D2 * inc ix
43D4 * inc e
43D5 * ld bc,00204h
43D8 * call f_4404
43DB * ld bc,0ffefh
43DE * add ix,bc
43E0 * ld bc,00308h
43E3 * dec e
43E4 * dec d
43E5 * call f_4404
43E8 * ld bc,0000fh
43EB * add ix,bc
43ED * inc d
43EE * dec e
43EF * ld bc,00001h
43F2 * call f_4404
43F5 * ld bc,00011h
43F8 * add ix,bc
43FA * inc d
43FB * inc e
43FC * ld bc,00102h
43FF * call f_4404
4402 * jr $-78
