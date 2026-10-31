#!/bin/bash
# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
#
# Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

# The presentation and ending on the C64 (c64/presentacion/NOTAS.md): everything into generado/, deterministically.
#   1. datos.py: text1.bin (the introduction text + the credits), text2.bin (the tape's ending text), pp.bin (the
#      parchment data + the glyphs 0 6 @ B), musica_inicio.c / musica_final.c (the tape's two tunes); checked;
#   2. the game's loader (cargador.s) at its address, a binary of its own (cargador.bin, .lbl, .map);
#   3. "abadia": abadia.c, io.c, manuscrito.c with the original build line (src/abadiac64.bat: cl65 --register-vars -Cl
#      -Ois -t c64 ... -C c64.cfg) plus what this build adds: presentacion.c, sid.s, c64/pergamino/musica.s, carga.s
#      (which includes cargador.bin), musica_inicio.c;
#   4. "final": io.c, manuscrito.c, final.c, presentacion.c (-DFINAL), sid.s, musica.s, musica_final.c;
#   5. the sizes the code reads (manuscrito.c's 0x5d3 and 0xac1, final.c's TEXT2) checked against the files.
# Used by c64/presentacion/pruebas/disco_prueba/construye.sh (the disk).
set -euo pipefail
D=$(dirname "$(realpath "$0")"); P=$(dirname "$(dirname "$D")")
B=$P/../tools/terceros/cc65/bin
G=$D/generado
mkdir -p "$G"
cd "$D"

# 1. the data
python3 -I datos.py "$G" > "$G/datos.txt" || { cat "$G/datos.txt"; exit 1; }

# 2. the loader
"$B/ca65" -o "$G/cargador.o" cargador.s
"$B/ld65" -C cargador.cfg -o "$G/cargador.bin" -Ln "$G/cargador.lbl" -m "$G/cargador.map" "$G/cargador.o"
DESTINO=$(awk '$3 == ".inicio" { print "$" substr($2, 3) }' "$G/cargador.lbl")

# 3. and 4. the two programs (the original flags)
OPC=(--register-vars -Cl -Ois -t c64 -C c64.cfg -I "$P/c64/pergamino" --asm-include-dir "$P/c64/pergamino")
"$B/cl65" "${OPC[@]}" --asm-define "DESTINO=$DESTINO" --bin-include-dir "$G" -o "$G/abadia.prg" -m "$G/abadia.map" \
    -Ln "$G/abadia.lbl" io.c manuscrito.c abadia.c presentacion.c sid.s "$P/c64/pergamino/musica.s" carga.s \
    "$G/musica_inicio.c"
"$B/cl65" "${OPC[@]}" -DFINAL -o "$G/final.prg" -m "$G/final.map" -Ln "$G/final.lbl" io.c manuscrito.c final.c \
    presentacion.c sid.s "$P/c64/pergamino/musica.s" "$G/musica_final.c"
rm -f ./*.o "$G"/*.o "$P/c64/pergamino/musica.o" "$G"/musica_*.o

# 5. the sizes in the code against the files
t1=$(stat -c %s "$G/text1.bin"); t2=$(stat -c %s "$G/text2.bin"); g=$(( $(stat -c %s "$G/pp.bin") - 0x356 ))
grep -q "malloc(sizeof(char) \* $(printf '0x%x' "$t1"))" manuscrito.c || { echo "manuscrito.c: text1.bin is $t1 bytes"; exit 1; }
grep -q "perlet = malloc(sizeof(char) \* $(printf '0x%x' "$g"))" manuscrito.c || { echo "manuscrito.c: pp.bin's glyphs are $g bytes"; exit 1; }
grep -q "#define TEXT2 $(printf '0x%x' "$t2")" final.c || { echo "final.c: text2.bin is $t2 bytes"; exit 1; }

if [ -n "${CINTA:-}" ]; then
    # the tape (c64/cinta/NOTAS.md): the programs with both languages' data inside (datos_cinta.s,
    # datos_final_cinta.s) and the loader reading the tape (-D CINTA), in generado_cinta/
    GC=$D/generado_cinta; E=$P/c64/ingles/generado
    mkdir -p "$GC"
    cp "$D/original/graphics/abadia.koa" "$GC/koa_es.bin"; cp "$E/abbey.koa" "$GC/koa_en.bin"
    for f in pp text1 text2; do cp "$G/$f.bin" "$GC/${f}_es.bin"; cp "$E/pergamino/$f.bin" "$GC/${f}_en.bin"; done
    "$B/ca65" -D CINTA -I "$P/c64/cinta" -o "$GC/cargador.o" cargador.s
    "$B/ld65" -C cargador.cfg -o "$GC/cargador.bin" -Ln "$GC/cargador.lbl" -m "$GC/cargador.map" "$GC/cargador.o"
    DESTINO_C=$(awk '$3 == ".inicio" { print "$" substr($2, 3) }' "$GC/cargador.lbl")
    "$B/cl65" "${OPC[@]}" -DCINTA --asm-define "DESTINO=$DESTINO_C" --bin-include-dir "$GC" -o "$GC/abadia.prg" \
        -m "$GC/abadia.map" -Ln "$GC/abadia.lbl" io.c manuscrito.c abadia.c presentacion.c sid.s \
        "$P/c64/pergamino/musica.s" carga.s "$G/musica_inicio.c" datos_cinta.s
    "$B/cl65" "${OPC[@]}" -DCINTA -DFINAL --bin-include-dir "$GC" -o "$GC/final.prg" -m "$GC/final.map" \
        -Ln "$GC/final.lbl" io.c manuscrito.c final.c presentacion.c sid.s "$P/c64/pergamino/musica.s" \
        "$G/musica_final.c" datos_final_cinta.s
    rm -f ./*.o "$GC"/*.o "$P/c64/pergamino/musica.o" "$G"/musica_*.o
    echo "tape: loader $(stat -c %s "$GC/cargador.bin") bytes at $DESTINO_C; abadia $(stat -c %s "$GC/abadia.prg"); final $(stat -c %s "$GC/final.prg")"
fi
if [ -n "${DISCO:-}" ]; then
    # the C64's disk with the tape's menu (c64/disco64/NOTAS.md): the programs as on the tape (both languages'
    # data inside: -DCINTA in the C), the game's loader reading the files JUEGO and TEXTOS with the KERNAL (-D DISCO),
    # in generado_disco64/
    GD=$D/generado_disco64; E=$P/c64/ingles/generado
    mkdir -p "$GD"
    cp "$D/original/graphics/abadia.koa" "$GD/koa_es.bin"; cp "$E/abbey.koa" "$GD/koa_en.bin"
    for f in pp text1 text2; do cp "$G/$f.bin" "$GD/${f}_es.bin"; cp "$E/pergamino/$f.bin" "$GD/${f}_en.bin"; done
    "$B/ca65" -D DISCO -I "$P/c64/cinta" -o "$GD/cargador.o" cargador.s
    "$B/ld65" -C cargador.cfg -o "$GD/cargador.bin" -Ln "$GD/cargador.lbl" -m "$GD/cargador.map" "$GD/cargador.o"
    DESTINO_D=$(awk '$3 == ".inicio" { print "$" substr($2, 3) }' "$GD/cargador.lbl")
    "$B/cl65" "${OPC[@]}" -DCINTA --asm-define "DESTINO=$DESTINO_D" --bin-include-dir "$GD" -o "$GD/abadia.prg" \
        -m "$GD/abadia.map" -Ln "$GD/abadia.lbl" io.c manuscrito.c abadia.c presentacion.c sid.s \
        "$P/c64/pergamino/musica.s" carga.s "$G/musica_inicio.c" datos_cinta.s
    "$B/cl65" "${OPC[@]}" -DCINTA -DFINAL --bin-include-dir "$GD" -o "$GD/final.prg" -m "$GD/final.map" \
        -Ln "$GD/final.lbl" io.c manuscrito.c final.c presentacion.c sid.s "$P/c64/pergamino/musica.s" \
        "$G/musica_final.c" datos_final_cinta.s
    rm -f ./*.o "$GD"/*.o "$P/c64/pergamino/musica.o" "$G"/musica_*.o
    echo "disk (C64): loader $(stat -c %s "$GD/cargador.bin") bytes at $DESTINO_D; abadia $(stat -c %s "$GD/abadia.prg"); final $(stat -c %s "$GD/final.prg")"
fi
if [ -n "${C128:-}" ]; then
    # the C128's disk (abadia128ks, c64/disco128/NOTAS.md): the programs for the C128 (cc65's c128 target, c128.cfg),
    # both languages' data inside as on the tape (-DCINTA in the C: the data, not the tape; the language from the
    # menu's OPCIONES, $1BFF), the game's loader carga128.s with its last stage (c64/disco128/generado/etapa128.bin,
    # made before by c64/disco128/construye.sh), in generado_c128/
    G8=$D/generado_c128; E=$P/c64/ingles/generado; DG=$P/c64/disco128/generado
    mkdir -p "$G8"
    cp "$D/original/graphics/abadia.koa" "$G8/koa_es.bin"; cp "$E/abbey.koa" "$G8/koa_en.bin"
    for f in pp text1 text2; do cp "$G/$f.bin" "$G8/${f}_es.bin"; cp "$E/pergamino/$f.bin" "$G8/${f}_en.bin"; done
    O8=(--register-vars -Cl -Ois -t c128 -C c128.cfg -I "$P/c64/pergamino" --asm-include-dir "$P/c64/pergamino"
        --asm-include-dir "$P/c64/disco128")
    "$B/cl65" "${O8[@]}" -DCINTA --bin-include-dir "$G8" --bin-include-dir "$DG" -o "$G8/abadia.prg" -m "$G8/abadia.map" \
        -Ln "$G8/abadia.lbl" io.c manuscrito.c abadia.c presentacion.c sid.s "$P/c64/pergamino/musica.s" carga128.s \
        "$G/musica_inicio.c" datos_cinta.s
    "$B/cl65" "${O8[@]}" -DCINTA -DFINAL --bin-include-dir "$G8" -o "$G8/final.prg" -m "$G8/final.map" \
        -Ln "$G8/final.lbl" io.c manuscrito.c final.c presentacion.c sid.s "$P/c64/pergamino/musica.s" \
        "$G/musica_final.c" datos_final_cinta.s
    rm -f ./*.o "$G8"/*.o "$P/c64/pergamino/musica.o" "$G"/musica_*.o
    echo "C128: abadia $(stat -c %s "$G8/abadia.prg"); final $(stat -c %s "$G8/final.prg")"
fi
if [ -n "${P500:-}" ]; then
    # the P500's disk (abadia128ks for the CBM-II 510, c64/discop500/NOTAS.md): cc65's cbm510 target (p500.cfg: the
    # program below the parchment's bitmap), both languages' data inside (-DCINTA), the start menu (menu500.c), the
    # game's loader carga500.s with the last stage inside (c64/discop500/generado/etapa500.bin, made before by
    # c64/discop500/construye.sh), the ending's options read from bank 1 (final500.s), in generado_p500/
    GP=$D/generado_p500; E=$P/c64/ingles/generado; DG=$P/c64/discop500/generado
    mkdir -p "$GP"
    cp "$D/original/graphics/abadia.koa" "$GP/koa_es.bin"; cp "$E/abbey.koa" "$GP/koa_en.bin"
    for f in pp text1 text2; do cp "$G/$f.bin" "$GP/${f}_es.bin"; cp "$E/pergamino/$f.bin" "$GP/${f}_en.bin"; done
    O5=(--register-vars -Cl -Ois -t cbm510 -C p500.cfg -I "$P/c64/pergamino" --asm-include-dir "$P/c64/pergamino"
        --asm-include-dir "$P/c64/discop500")
    "$B/cl65" "${O5[@]}" -DCINTA --bin-include-dir "$GP" --bin-include-dir "$DG" -o "$GP/abadia.prg" -m "$GP/abadia.map" \
        -Ln "$GP/abadia.lbl" io.c manuscrito.c abadia.c presentacion.c menu500.c sid.s "$P/c64/pergamino/musica.s" \
        carga500.s "$G/musica_inicio.c" datos_cinta.s
    "$B/cl65" "${O5[@]}" -DCINTA -DFINAL --bin-include-dir "$GP" -o "$GP/final.prg" -m "$GP/final.map" \
        -Ln "$GP/final.lbl" io.c manuscrito.c final.c presentacion.c sid.s "$P/c64/pergamino/musica.s" \
        "$G/musica_final.c" datos_final_cinta.s final500.s
    rm -f ./*.o "$GP"/*.o "$P/c64/pergamino/musica.o" "$G"/musica_*.o
    echo "P500: abadia $(stat -c %s "$GP/abadia.prg"); final $(stat -c %s "$GP/final.prg")"
fi
echo "loader: $(stat -c %s "$G/cargador.bin") bytes at $DESTINO; abadia: $(stat -c %s "$G/abadia.prg") bytes; final: $(stat -c %s "$G/final.prg") bytes; text1.bin $t1, text2.bin $t2, pp.bin $(stat -c %s "$G/pp.bin")"
